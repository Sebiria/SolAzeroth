// Écart d'équipement (section 5, V5, décisions de l'utilisateur du 29/10/2026). Valeurs provisoires dans
// mod_solazeroth.conf (SolAzeroth.Ecart.*), à recaler par l'équipe de calibrage final.
// - Ilvl du joueur : moyenne des objets portés (chemise et tabard exclus, emplacements vides ignorés). Un objet obtenu
//   au rang de menace R (solazeroth_objets_rang) compte pour ilvl × (1 + 3 % × R), comme son enchantement de bonus.
// - Ilvl attendu face à un monstre de niveau N : moyenne des récompenses de quête vertes et bleues (armes et armures)
//   des quêtes de niveau N-5 à N, calculée au démarrage. En donjon : × (1 + 3 % × rang de menace) (proportionnel,
//   décision de l'utilisateur). Le niveau de défi extérieur ne compte pas. Boss de monde : niveau - 3.
// - Écart en % de l'ilvl attendu (et non en points : 3 points pèsent 15 % au niveau 20 mais 2 % au niveau 80).
//   Zone neutre ±5 %. En dessous : -1 % de dégâts et soins et +1 % de dégâts subis par point, plafonds -20 % / +20 %.
//   Au-dessus : +0,5 % de dégâts et soins par point, plafond +10 %.
// - Dégâts : calculés à chaque coup selon le monstre touché ou qui frappe (familier compris). Soins : selon la cible ou
//   l'adversaire du moment. L'addon SolAzerothEcart (préfixe SOLECART) affiche « Sous-équipé » ou « Bien équipé ».
// - Depuis V7, les auras « Sous-équipé » (100002) et « Bien équipé » (100003) l'affichent aussi, un cumul par point de %.

#include "SolAzeroth.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuras.h"
#include "StringFormat.h"
#include <algorithm>
#include <array>
#include <shared_mutex>
#include <unordered_map>

namespace
{
    char const* const PREFIXE = "SOLECART";
    // Auras d'affichage (V7, outils/auras_nommees.py, migration 050) : le nombre de cumuls donne le pourcentage.
    uint32 const AURA_SOUS_EQUIPE = 100002, AURA_BIEN_EQUIPE = 100003;
    uint8 const NIVEAU_MAX = 80;

    struct Reglages
    {
        bool active = true;
        float neutre = 5.0f;
        float malusParPoint = 1.0f, malusMax = 20.0f;
        float subisParPoint = 1.0f, subisMax = 20.0f;
        float bonusParPoint = 0.5f, bonusMax = 10.0f;
        float pourcentParRang = 0.03f;
    } reglages;

    std::array<float, NIVEAU_MAX + 1> attendu{};            // niveau du monstre -> ilvl attendu

    std::shared_mutex verrouRangs;
    std::unordered_map<uint32, uint8> rangs;                // objet (guid) -> rang de menace

    struct Ecart : DataMap::Base
    {
        bool calcule = false;
        float ilvl = 0.0f;
        float soins = 0.0f;                                 // effet sur les soins, selon l'adversaire du moment
        uint32 attente = 0;
        std::string affiche;
    };

    Ecart* EcartDe(Player* player)
    {
        return player->CustomData.GetDefault<Ecart>("solazeroth_ecart");
    }

    uint8 RangObjet(uint32 guid)
    {
        std::shared_lock<std::shared_mutex> garde(verrouRangs);
        auto it = rangs.find(guid);
        return it == rangs.end() ? 0 : it->second;
    }

    // Sphère instable et fissure volcanique (affixes_mecanique.cpp, niveau 80) : pas de vrais adversaires.
    bool CreatureAffixe(Creature const* creature)
    {
        return creature->GetEntry() == 900100 || creature->GetEntry() == 900101;
    }

    float IlvlJoueur(Player* player)
    {
        float somme = 0.0f;
        uint32 nombre = 0;
        for (uint8 emplacement = EQUIPMENT_SLOT_START; emplacement < EQUIPMENT_SLOT_END; ++emplacement)
        {
            if (emplacement == EQUIPMENT_SLOT_BODY || emplacement == EQUIPMENT_SLOT_TABARD)
                continue;
            Item* objet = player->GetItemByPos(INVENTORY_SLOT_BAG_0, emplacement);
            if (!objet)
                continue;
            // Objet d'héritage : son modèle dit niveau d'objet 1, il suit en fait le niveau du joueur. Compté au niveau
            // d'objet attendu à ce niveau, donc neutre (calibrage final, 29/10/2026 : il déclenchait « Sous-équipé »).
            if (objet->GetTemplate()->Quality == ITEM_QUALITY_HEIRLOOM)
                somme += attendu[std::clamp<int32>(player->GetLevel(), 1, NIVEAU_MAX)];
            else
                somme += objet->GetTemplate()->ItemLevel * (1.0f + reglages.pourcentParRang * RangObjet(objet->GetGUID().GetCounter()));
            ++nombre;
        }
        return nombre ? somme / nombre : 0.0f;
    }

    float IlvlAttendu(Creature const* creature)
    {
        int32 niveau = creature->GetLevel() - (creature->isWorldBoss() ? 3 : 0);
        float valeur = attendu[std::clamp<int32>(niveau, 1, NIVEAU_MAX)];
        Map const* map = creature->GetMap();
        if (map && map->IsDungeon())
            valeur *= 1.0f + reglages.pourcentParRang * SolAzeroth::RangInstance(map->GetInstanceId());
        return valeur;
    }

    // Écart en % de l'ilvl attendu (négatif = sous-équipé).
    float EcartFace(Player* player, Creature const* creature)
    {
        float prevu = IlvlAttendu(creature);
        return prevu > 0.0f ? (EcartDe(player)->ilvl / prevu - 1.0f) * 100.0f : 0.0f;
    }

    // Effet en % sur les dégâts et soins infligés (négatif = malus).
    float EffetInflige(float ecart)
    {
        if (ecart < -reglages.neutre)
            return -std::min(reglages.malusMax, (-ecart - reglages.neutre) * reglages.malusParPoint);
        if (ecart > reglages.neutre)
            return std::min(reglages.bonusMax, (ecart - reglages.neutre) * reglages.bonusParPoint);
        return 0.0f;
    }

    // Effet en % sur les dégâts subis (positif = plus de dégâts).
    float EffetSubis(float ecart)
    {
        return ecart < -reglages.neutre ? std::min(reglages.subisMax, (-ecart - reglages.neutre) * reglages.subisParPoint) : 0.0f;
    }

    // Monstre de référence pour l'affichage et les soins : la cible, sinon l'adversaire, sinon un monstre qui attaque.
    Creature* Reference(Player* player)
    {
        auto valable = [player](Unit* unite) -> Creature*
        {
            Creature* creature = unite ? unite->ToCreature() : nullptr;
            return creature && creature->IsAlive() && !creature->GetCharmerOrOwnerPlayerOrPlayerItself() && !CreatureAffixe(creature)
                && player->IsValidAttackTarget(creature) ? creature : nullptr;
        };
        if (Creature* c = valable(player->GetSelectedUnit()))
            return c;
        if (Creature* c = valable(player->GetVictim()))
            return c;
        for (Unit* attaquant : player->getAttackers())
            if (Creature* c = valable(attaquant))
                return c;
        return nullptr;
    }

    // Pose l'aura avec un cumul par point de % (au moins 1), ou la retire si l'effet est nul.
    void AfficherAura(Player* player, uint32 sort, float pourcent)
    {
        if (pourcent <= 0.0f)
        {
            player->RemoveAurasDueToSpell(sort);
            return;
        }
        Aura* aura = player->GetAura(sort);
        if (!aura)
            aura = player->AddAura(sort, player);
        uint8 cumuls = uint8(std::clamp<int32>(int32(pourcent + 0.5f), 1, 255));
        if (aura && aura->GetStackAmount() != cumuls)
            aura->SetStackAmount(cumuls);
    }

    void Actualiser(Player* player)
    {
        Ecart* e = EcartDe(player);
        e->ilvl = IlvlJoueur(player);
        e->calcule = true;
        Creature* creature = reglages.active ? Reference(player) : nullptr;
        std::string message = "ECART";
        e->soins = 0.0f;
        if (creature)
        {
            float ecart = EcartFace(player, creature);
            e->soins = EffetInflige(ecart);
            message = Acore::StringFormat("ECART;{:.0f};{:.0f};{:.0f};{:.0f};{:.0f}", ecart, e->soins, EffetSubis(ecart),
                e->ilvl, IlvlAttendu(creature));
        }
        if (message != e->affiche)
        {
            e->affiche = message;
            SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
            AfficherAura(player, AURA_SOUS_EQUIPE, e->soins < 0.0f ? -e->soins : 0.0f);
            AfficherAura(player, AURA_BIEN_EQUIPE, e->soins > 0.0f ? e->soins : 0.0f);
        }
    }

    Player* JoueurDe(Unit* unite)
    {
        return unite ? unite->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
    }

    Creature* Monstre(Unit* unite)
    {
        Creature* creature = unite ? unite->ToCreature() : nullptr;
        return creature && !creature->GetCharmerOrOwnerPlayerOrPlayerItself() && !CreatureAffixe(creature) ? creature : nullptr;
    }
}

unsigned char SolAzeroth::RangDObjet(unsigned int guid)
{
    return RangObjet(guid);
}

void SolAzeroth::NoterRangObjet(unsigned int guid, unsigned char rang)
{
    std::unique_lock<std::shared_mutex> garde(verrouRangs);
    rangs[guid] = rang;
}

float SolAzeroth::IlvlEquipe(Player* player)
{
    return IlvlJoueur(player);
}

float SolAzeroth::IlvlAttenduNiveau(unsigned char niveau)
{
    return attendu[std::clamp<int32>(niveau, 1, NIVEAU_MAX)];
}

class solazeroth_ecart_unites : public UnitScript
{
public:
    solazeroth_ecart_unites() : UnitScript("solazeroth_ecart_unites", true, {
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK,
        UNITHOOK_MODIFY_HEAL_RECEIVED }) { }

    template <typename T>
    static void Appliquer(Unit* cible, Unit* attaquant, T& degats)
    {
        if (!reglages.active || cible == attaquant)
            return;
        if (Player* player = JoueurDe(attaquant))
            if (Creature* creature = Monstre(cible); creature && EcartDe(player)->calcule)
                if (float effet = EffetInflige(EcartFace(player, creature)))
                    degats = T(degats * (1.0f + effet / 100.0f));
        if (Player* player = cible ? cible->ToPlayer() : nullptr)
            if (Creature* creature = Monstre(attaquant); creature && EcartDe(player)->calcule)
                if (float effet = EffetSubis(EcartFace(player, creature)))
                    degats = T(degats * (1.0f + effet / 100.0f));
    }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override { Appliquer(cible, attaquant, degats); }
    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* /*sort*/) override { Appliquer(cible, attaquant, degats); }
    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* /*sort*/) override { Appliquer(cible, attaquant, degats); }

    void ModifyHealReceived(Unit* /*cible*/, Unit* soigneur, uint32& soins, SpellInfo const* /*sort*/) override
    {
        Player* player = soigneur ? soigneur->ToPlayer() : nullptr;
        if (!reglages.active || !player)
            return;
        if (float effet = EcartDe(player)->soins)
            soins = uint32(soins * (1.0f + effet / 100.0f));
    }
};

class solazeroth_ecart_joueur : public PlayerScript
{
public:
    solazeroth_ecart_joueur() : PlayerScript("solazeroth_ecart_joueur", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Actualiser(player);
    }

    void OnPlayerUpdate(Player* player, uint32 ecoule) override
    {
        Ecart* e = EcartDe(player);
        e->attente += ecoule;
        if (e->attente < 1000)
            return;
        e->attente = 0;
        Actualiser(player);
    }
};

class solazeroth_ecart_monde : public WorldScript
{
public:
    solazeroth_ecart_monde() : WorldScript("solazeroth_ecart_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.active = sConfigMgr->GetOption<bool>("SolAzeroth.Ecart.Enable", true);
        reglages.neutre = sConfigMgr->GetOption<float>("SolAzeroth.Ecart.ZoneNeutre", 5.0f);
        reglages.malusParPoint = sConfigMgr->GetOption<float>("SolAzeroth.Ecart.MalusParPoint", 1.0f);
        reglages.malusMax = sConfigMgr->GetOption<float>("SolAzeroth.Ecart.MalusMax", 20.0f);
        reglages.subisParPoint = sConfigMgr->GetOption<float>("SolAzeroth.Ecart.SubisParPoint", 1.0f);
        reglages.subisMax = sConfigMgr->GetOption<float>("SolAzeroth.Ecart.SubisMax", 20.0f);
        reglages.bonusParPoint = sConfigMgr->GetOption<float>("SolAzeroth.Ecart.BonusParPoint", 0.5f);
        reglages.bonusMax = sConfigMgr->GetOption<float>("SolAzeroth.Ecart.BonusMax", 10.0f);
        reglages.pourcentParRang = sConfigMgr->GetOption<float>("SolAzeroth.Bonus.PourcentParRang", 0.03f);
    }

    void OnStartup() override
    {
        // Ilvl moyen des récompenses de quête vertes et bleues (armes et armures, sans chemise, tabard ni sac) par niveau de quête.
        std::array<float, NIVEAU_MAX + 1> moyenne{};
        std::array<uint32, NIVEAU_MAX + 1> nombre{};
        if (QueryResult r = WorldDatabase.Query(
            "SELECT q.QuestLevel, AVG(t.ItemLevel), COUNT(*) FROM quest_template q "
            "JOIN item_template t ON t.entry IN (q.RewardItem1, q.RewardItem2, q.RewardItem3, q.RewardItem4, "
            "q.RewardChoiceItemID1, q.RewardChoiceItemID2, q.RewardChoiceItemID3, q.RewardChoiceItemID4, q.RewardChoiceItemID5, q.RewardChoiceItemID6) "
            "WHERE t.class IN (2, 4) AND t.Quality IN (2, 3) AND t.InventoryType NOT IN (0, 4, 18, 19, 24, 28) "
            "AND q.QuestLevel BETWEEN 1 AND {} GROUP BY q.QuestLevel", NIVEAU_MAX))
        {
            do
            {
                Field* f = r->Fetch();
                uint32 niveau = f[0].Get<int32>();
                moyenne[niveau] = float(f[1].Get<double>());
                nombre[niveau] = uint32(f[2].Get<uint64>());
            } while (r->NextRow());
        }
        // Attendu au niveau N : moyenne pondérée des niveaux N-5 à N (l'équipement porté vient des quêtes précédentes).
        for (int32 niveau = 1; niveau <= NIVEAU_MAX; ++niveau)
        {
            float somme = 0.0f;
            uint32 total = 0;
            for (int32 n = std::max(1, niveau - 5); n <= niveau; ++n)
            {
                somme += moyenne[n] * nombre[n];
                total += nombre[n];
            }
            attendu[niveau] = total ? somme / total : float(niveau);
        }

        if (QueryResult r = CharacterDatabase.Query("SELECT item_guid, rang FROM solazeroth_objets_rang"))
        {
            std::unique_lock<std::shared_mutex> garde(verrouRangs);
            do
                rangs[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint8>();
            while (r->NextRow());
        }
        LOG_INFO("module", "Sol'Azeroth écart d'équipement : ilvl attendu {:.0f} au niveau 20, {:.0f} au 60, {:.0f} au 70, {:.0f} au 80 ; {} objets de rang",
            attendu[20], attendu[60], attendu[70], attendu[80], rangs.size());
    }
};

void AddSC_solazeroth_ecart()
{
    new solazeroth_ecart_unites();
    new solazeroth_ecart_joueur();
    new solazeroth_ecart_monde();
}
