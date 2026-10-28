// Intendant (section 7.7, V3) : onglet « Intendant » de l'addon d'apprentissage, sans PNJ.
// Il vend le butin bleu propre aux boss de donjon (mêmes règles que le choix de butin, butin.cpp), par paliers de
// 5 niveaux, contre des Marques du voyageur et un peu d'or. Tout objet acheté est donné au rang de menace 3,
// avec son enchantement de bonus (décision de l'utilisateur : une seule variante par objet).
// Le joueur voit les objets de son palier et des deux précédents, utilisables par sa classe.
// Prix (provisoires, mod_solazeroth.conf) : Marques = base + par_niveau × niveau requis ; or = niveau requis² × facteur.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <algorithm>
#include <cmath>
#include <set>
#include <vector>

namespace
{
    struct Reglages
    {
        float marquesBase = 40.0f;
        float marquesParNiveau = 1.5f;
        uint32 orFacteur = 25;    // pièces de cuivre × niveau requis²
        uint8 rang = 3;
        uint8 palierMin = 10;
    } reglages;

    struct Article
    {
        uint32 objet;
        uint8 niveau;
        uint32 classes;
        uint32 emplacement;   // InventoryType
        uint32 classe;
        uint32 sousClasse;
    };
    std::vector<Article> articles;

    uint32 const TAILLE_MAX_REFERENCE_DE_BOSS = 25;   // comme butin.cpp

    bool EstEquipementBleu(ItemTemplate const* modele)
    {
        return modele && modele->Quality == ITEM_QUALITY_RARE && modele->InventoryType != INVTYPE_NON_EQUIP
            && (modele->Class == ITEM_CLASS_WEAPON || modele->Class == ITEM_CLASS_ARMOR)
            && modele->RequiredLevel >= reglages.palierMin;
    }

    void Collecter(char const* table, uint32 entree, std::set<uint32>& objets, uint8 profondeur = 0)
    {
        if (profondeur > 4)
            return;
        QueryResult resultat = WorldDatabase.Query("SELECT Item, Reference FROM {} WHERE Entry = {}", table, entree);
        if (!resultat)
            return;
        do
        {
            Field* champs = resultat->Fetch();
            if (uint32 reference = champs[1].Get<uint32>())
            {
                QueryResult taille = WorldDatabase.Query("SELECT COUNT(*) FROM reference_loot_template WHERE Entry = {}", reference);
                if (taille && (*taille)[0].Get<uint64>() <= TAILLE_MAX_REFERENCE_DE_BOSS)
                    Collecter("reference_loot_template", reference, objets, profondeur + 1);
            }
            else if (EstEquipementBleu(sObjectMgr->GetItemTemplate(champs[0].Get<uint32>())))
                objets.insert(champs[0].Get<uint32>());
        } while (resultat->NextRow());
    }

    uint8 Palier(uint8 niveau) { return niveau / 5 * 5; }

    uint32 PrixMarques(Article const& a) { return uint32(std::lround(reglages.marquesBase + reglages.marquesParNiveau * a.niveau)); }
    uint32 PrixOr(Article const& a) { return reglages.orFacteur * a.niveau * a.niveau; }

    bool Visible(Player* player, Article const& a)
    {
        uint8 palierJoueur = Palier(player->GetLevel());
        return a.niveau <= player->GetLevel() && Palier(a.niveau) + 10 >= palierJoueur
            && (a.classes & player->getClassMask());
    }
}

void SolAzeroth::ListerIntendant(Player* player, std::function<void(std::string const&)> const& ajouter)
{
    for (Article const& a : articles)
        if (Visible(player, a))
            ajouter(Acore::StringFormat("{}:{}:{}:{}:{}:{}:{}", a.objet, a.niveau, PrixMarques(a), PrixOr(a),
                a.emplacement, a.classe, a.sousClasse));
}

unsigned int SolAzeroth::ObjetIntendantAuHasard(Player* player)
{
    std::vector<uint32> possibles;
    for (Article const& a : articles)
        if (Visible(player, a))
            possibles.push_back(a.objet);
    return possibles.empty() ? 0 : possibles[urand(0, possibles.size() - 1)];
}

void SolAzeroth::AcheterIntendant(Player* player, unsigned int objet)
{
    ChatHandler chat(player->GetSession());
    auto it = std::find_if(articles.begin(), articles.end(), [&](Article const& a) { return a.objet == objet; });
    if (it == articles.end() || !Visible(player, *it))
        return;

    uint32 marques = PrixMarques(*it), cuivre = PrixOr(*it);
    if (SolAzeroth::Marques(player) < marques)
    {
        chat.SendSysMessage(Acore::StringFormat("|cffff0000Il te faut {} Marques du voyageur.|r", marques));
        return;
    }
    if (!player->HasEnoughMoney(cuivre))
    {
        chat.SendSysMessage("|cffff0000Pas assez d'or.|r");
        return;
    }
    if (!SolAzeroth::RetirerMarques(player, marques))
        return;
    if (!SolAzeroth::DonnerObjetDeRang(player, objet, reglages.rang))
    {
        SolAzeroth::DonnerMarques(player, marques, "remboursement, sacs pleins");
        chat.SendSysMessage("|cffff0000Sacs pleins.|r");
        return;
    }
    player->ModifyMoney(-int32(cuivre));
    chat.SendSysMessage(Acore::StringFormat("|cff00ff00Achat effectué au rang {}.|r", reglages.rang));
}

class solazeroth_intendant_monde : public WorldScript
{
public:
    solazeroth_intendant_monde() : WorldScript("solazeroth_intendant_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.marquesBase = sConfigMgr->GetOption<float>("SolAzeroth.Intendant.MarquesBase", 40.0f);
        reglages.marquesParNiveau = sConfigMgr->GetOption<float>("SolAzeroth.Intendant.MarquesParNiveau", 1.5f);
        reglages.orFacteur = sConfigMgr->GetOption<uint32>("SolAzeroth.Intendant.OrFacteur", 25);
        reglages.rang = uint8(std::min<uint32>(10, sConfigMgr->GetOption<uint32>("SolAzeroth.Intendant.Rang", 3)));
    }

    // Les boss de donjon sont marqués au chargement de instance_encounters.
    void OnStartup() override
    {
        std::set<uint32> objets, tables;
        for (auto const& [entree, modele] : *sObjectMgr->GetCreatureTemplates())
            if (modele.HasFlagsExtra(CREATURE_FLAG_EXTRA_DUNGEON_BOSS) && modele.lootid && tables.insert(modele.lootid).second)
                Collecter("creature_loot_template", modele.lootid, objets);

        for (uint32 objet : objets)
            if (ItemTemplate const* modele = sObjectMgr->GetItemTemplate(objet))
                articles.push_back({ objet, uint8(modele->RequiredLevel), modele->AllowableClass ? uint32(modele->AllowableClass) : 0xFFFFFFFF,
                    modele->InventoryType, modele->Class, modele->SubClass });
        std::sort(articles.begin(), articles.end(), [](Article const& a, Article const& b) { return a.niveau < b.niveau; });
        LOG_INFO("module", "Sol'Azeroth intendant : {} objets bleus de boss de donjon", articles.size());
    }
};

void AddSC_solazeroth_intendant()
{
    new solazeroth_intendant_monde();
}
