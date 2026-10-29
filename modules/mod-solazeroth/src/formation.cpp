// Apprentissage à distance (demande de l'utilisateur, V2) : l'addon SolAzerothFormation remplace
// les PNJ bonus. On y achète, sans se déplacer :
//   S  sorts et rangs de sorts de sa classe (entraîneurs de classe, prix d'origine)
//   M  rangs de métier (apprenti, compagnon...) et métiers secondaires (entraîneurs de métier)
//   R  recettes des entraîneurs de métier (pas celles des marchands)
//   C  maîtrises d'armes et d'armures (section 3.7)
//   O  outils de base de métier (prix du marchand)
//   I  intendant (intendant.cpp) ; E  Éclats de raid (malchance.cpp)
// Les règles sont celles des entraîneurs du jeu (niveau, rang précédent, compétence de métier).
// L'addon demande « .solform liste » et achète avec « .solform acheter <catégorie> <id> ».
// Grimoire universel (section 3.9, V3b) : les sorts des autres classes (catégorie X), envoyés classe par classe à la
// demande (« .solform classe <id> » : « XDEBUT|classe », paquets « X|… », « XFIN »), au prix d'entraîneur
// × SolAzeroth.Formation.MultiplicateurAutresClasses, au niveau requis d'origine.
// Nouveau grimoire (addon SolAzerothGrimoire) : « .solform grimoire » renvoie les sorts connus des autres classes,
// « GDEBUT », paquets « G|classe:sort;… », « GFIN » (le client ne sait pas à quelle classe appartient un sort).
// Sorts absents des entraîneurs, vendus aussi (demande de l'utilisateur du 30/10/2026) : sorts de départ (appris à la
// création : Posture de combat, Boule de feu…) et sorts des quêtes de classe (Posture défensive, Forme d'ours, premiers
// totems…). Un sort qui ne se lance qu'en posture, en forme ou camouflé exige d'en connaître une (« X|…:forme »), et
// un sort qui demande un totem du chaman (objet) le donne à l'achat s'il manque.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringFormat.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include <algorithm>
#include <array>
#include <set>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLFORM";
    uint32 const PO = 10000;

    uint32 multiplicateurAutresClasses = 10;

    struct Entree
    {
        char categorie = 'S';
        uint32 sort = 0;
        uint32 cout = 0;
        uint32 competence = 0;       // métier requis (recettes) ou métier enseigné (rangs)
        uint32 rangCompetence = 0;   // valeur de métier requise
        std::array<uint32, 3> sortsRequis = { };
        uint8 niveau = 0;
        uint32 exigence = 0;         // sort exigé par l'entraîneur (spécialisations de métier)
        std::vector<uint32> formes;  // posture, forme ou camouflage exigés (l'un d'eux suffit)
    };

    // Totems du chaman (objets de quête) : catégorie de totem -> objet.
    std::unordered_map<uint32, uint32> const TOTEMS = { { 2, 5175 }, { 4, 5176 }, { 5, 5177 }, { 3, 5178 } };

    std::array<std::vector<Entree>, MAX_CLASSES> sortsDeClasse;
    std::vector<Entree> metiers;     // catégories M et R

    // Prix relevés au calibrage final (29/10/2026) : une maîtrise change le build (plaques sur un lanceur de sorts) et
    // coûtait 0,5 à 3 h de revenu. Armes et cuir 2 → 10 po, ambidextrie 10 → 30, mailles 20 → 60, plaques 50 → 150,
    // bouclier 5 → 20 po et niveau 1 → 10.
    struct Maitrise { uint32 sort; uint8 niveau; uint32 cout; uint32 avec; };
    std::vector<Maitrise> const MAITRISES =
    {
        { 9077, 1, 10 * PO, 0 },  { 8737, 40, 60 * PO, 0 }, { 750, 40, 150 * PO, 0 }, { 9116, 10, 20 * PO, 107 },
        { 1180, 1, 10 * PO, 0 },  { 15590, 1, 10 * PO, 0 }, { 201, 1, 10 * PO, 0 },   { 196, 1, 10 * PO, 0 },
        { 198, 1, 10 * PO, 0 },   { 202, 1, 10 * PO, 0 },   { 197, 1, 10 * PO, 0 },   { 199, 1, 10 * PO, 0 },
        { 200, 1, 10 * PO, 0 },   { 227, 1, 10 * PO, 0 },   { 264, 1, 10 * PO, 0 },   { 266, 1, 10 * PO, 0 },
        { 5011, 1, 10 * PO, 0 },  { 2567, 1, 10 * PO, 0 },  { 5009, 1, 10 * PO, 0 },  { 674, 10, 30 * PO, 0 },
    };

    // Sorts jamais vendus aux autres classes. Connexion (démoniste) : PV → mana, donc soin sans fin pour un soigneur
    // (calibrage final, 29/10/2026).
    std::set<uint32> const EXCLUS_AUTRES_CLASSES = { 1454, 1455, 1456, 11687, 11688, 11689, 27222, 57946 };

    // Pioche, couteau à dépecer, marteau, clé plate, bâtonnet runique, trousse de joaillier,
    // coffret de calligraphie, canne à pêche, silex et amadou.
    std::vector<uint32> const OUTILS = { 2901, 7005, 5956, 6219, 6218, 20815, 39505, 6256, 4471 };

    enum Etat : uint8 { DISPONIBLE = 0, INDISPONIBLE = 1, CONNU = 2 };

    // Reprend Trainer::GetDefaultSpellState du core, sans PNJ. Pour un sort d'une autre classe, on ne vérifie ni la
    // classe ni la race.
    Etat EtatSort(Player* player, Entree const& e, bool autreClasse = false)
    {
        if (player->HasSpell(e.sort))
            return CONNU;
        if (autreClasse && SolAzeroth::EstDestin(player))
            return INDISPONIBLE;
        if (e.categorie == 'S' && !autreClasse && !player->IsSpellFitByClassAndRace(e.sort))
            return INDISPONIBLE;
        if (e.exigence && !player->HasSpell(e.exigence))
            return INDISPONIBLE;

        SpellInfo const* info = sSpellMgr->GetSpellInfo(e.sort);
        if (!info)
            return INDISPONIBLE;

        bool apprend = false, connaitTout = true;
        for (SpellEffectInfo const& effet : info->GetEffects())
        {
            if (!effet.IsEffect(SPELL_EFFECT_LEARN_SPELL))
                continue;
            apprend = true;
            if (!player->HasSpell(effet.TriggerSpell))
                connaitTout = false;
        }
        if (apprend && connaitTout)
            return CONNU;

        if (e.categorie == 'R' && e.competence && player->GetBaseSkillValue(e.competence) < e.rangCompetence)
            return INDISPONIBLE;
        if (e.categorie == 'M' && e.rangCompetence && player->GetBaseSkillValue(e.competence) < e.rangCompetence)
            return INDISPONIBLE;
        for (uint32 requis : e.sortsRequis)
            if (requis && !player->HasSpell(requis))
                return INDISPONIBLE;
        if (player->GetLevel() < e.niveau)
            return INDISPONIBLE;
        if (!e.formes.empty() && std::none_of(e.formes.begin(), e.formes.end(), [&](uint32 f) { return player->HasSpell(f); }))
            return INDISPONIBLE;

        for (SpellEffectInfo const& effet : info->GetEffects())
        {
            if (!effet.IsEffect(SPELL_EFFECT_LEARN_SPELL))
                continue;
            if (uint32 precedent = sSpellMgr->GetPrevSpellInChain(effet.TriggerSpell))
                if (!player->HasSpell(precedent))
                    return INDISPONIBLE;
            SpellInfo const* appris = sSpellMgr->GetSpellInfo(effet.TriggerSpell);
            if (appris && appris->IsPrimaryProfessionFirstRank() && !player->GetFreePrimaryProfessionPoints())
                return INDISPONIBLE;
        }
        if (!apprend)
            if (uint32 precedent = sSpellMgr->GetPrevSpellInChain(e.sort))
                if (!player->HasSpell(precedent))
                    return INDISPONIBLE;
        for (auto const& paire : sSpellMgr->GetSpellsRequiredForSpellBounds(e.sort))
            if (!player->HasSpell(paire.second))
                return INDISPONIBLE;
        return DISPONIBLE;
    }

    void EnvoyerAddon(Player* player, std::string const& message)
    {
        SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
    }

    // Envoie des éléments « a:b:c » par paquets de moins de 230 caractères : « S|elt;elt;... ».
    class Envoi
    {
    public:
        Envoi(Player* player, char categorie) : _player(player), _categorie(categorie) { }
        ~Envoi() { Vider(); }

        void Ajouter(std::string const& element)
        {
            if (_tampon.size() + element.size() + 1 > 230)
                Vider();
            _tampon += (_tampon.empty() ? "" : ";") + element;
        }

    private:
        void Vider()
        {
            if (!_tampon.empty())
                EnvoyerAddon(_player, std::string(1, _categorie) + "|" + _tampon);
            _tampon.clear();
        }

        Player* _player;
        char _categorie;
        std::string _tampon;
    };

    void EnvoyerCatalogue(Player* player)
    {
        EnvoyerAddon(player, "DEBUT");
        {
            Envoi envoi(player, 'S');
            for (Entree const& e : sortsDeClasse[player->getClass()])
                envoi.Ajouter(Acore::StringFormat("{}:{}:{}:{}", e.sort, e.niveau, e.cout, uint32(EtatSort(player, e))));
        }
        {
            Envoi rangs(player, 'M'), recettes(player, 'R');
            for (Entree const& e : metiers)
            {
                if (e.exigence && !player->HasSpell(e.exigence))
                    continue;
                std::string element = Acore::StringFormat("{}:{}:{}:{}:{}:{}", e.sort, e.niveau, e.cout,
                    uint32(EtatSort(player, e)), e.competence, e.rangCompetence);
                (e.categorie == 'M' ? rangs : recettes).Ajouter(element);
            }
        }
        {
            Envoi envoi(player, 'C');
            for (Maitrise const& m : MAITRISES)
            {
                Etat etat = player->HasSpell(m.sort) ? CONNU : player->GetLevel() < m.niveau ? INDISPONIBLE : DISPONIBLE;
                envoi.Ajouter(Acore::StringFormat("{}:{}:{}:{}", m.sort, m.niveau, m.cout, uint32(etat)));
            }
        }
        {
            Envoi envoi(player, 'O');
            for (uint32 outil : OUTILS)
                if (ItemTemplate const* modele = sObjectMgr->GetItemTemplate(outil))
                    envoi.Ajouter(Acore::StringFormat("{}:0:{}:{}", outil, modele->BuyPrice, player->HasItemCount(outil, 1, true) ? uint32(CONNU) : uint32(DISPONIBLE)));
        }
        {
            Envoi envoi(player, 'I');
            SolAzeroth::ListerIntendant(player, [&](std::string const& element) { envoi.Ajouter(element); });
        }
        {
            Envoi envoi(player, 'E');
            SolAzeroth::ListerEclats(player, [&](std::string const& element) { envoi.Ajouter(element); });
        }
        EnvoyerAddon(player, Acore::StringFormat("N|{}", SolAzeroth::Marques(player)));
        EnvoyerAddon(player, "FIN");
    }

    // Sorts d'une autre classe : « XDEBUT|classe », puis « X|sort:niveau:prix:état;… », puis « XFIN ».
    void EnvoyerAutreClasse(Player* player, uint8 classe)
    {
        if (classe == 0 || classe >= MAX_CLASSES || classe == player->getClass())
            return;
        EnvoyerAddon(player, Acore::StringFormat("XDEBUT|{}", classe));
        {
            Envoi envoi(player, 'X');
            for (Entree const& e : sortsDeClasse[classe])
                if (!EXCLUS_AUTRES_CLASSES.count(e.sort))
                    envoi.Ajouter(Acore::StringFormat("{}:{}:{}:{}:{}", e.sort, e.niveau, e.cout * multiplicateurAutresClasses,
                        uint32(EtatSort(player, e, true)), e.formes.empty() ? 0 : e.formes.front()));
        }
        EnvoyerAddon(player, "XFIN");
    }

    // Sorts connus des autres classes, pour le nouveau grimoire. Un sort d'entraîneur peut être un sort
    // d'apprentissage : on regarde aussi les sorts qu'il apprend.
    void EnvoyerGrimoire(Player* player)
    {
        EnvoyerAddon(player, "GDEBUT");
        {
            Envoi envoi(player, 'G');
            std::set<uint32> vus;
            for (uint8 classe = 1; classe < MAX_CLASSES; ++classe)
            {
                if (classe == player->getClass())
                    continue;
                for (Entree const& e : sortsDeClasse[classe])
                {
                    std::vector<uint32> sorts = { e.sort };
                    if (SpellInfo const* info = sSpellMgr->GetSpellInfo(e.sort))
                        for (SpellEffectInfo const& effet : info->GetEffects())
                            if (effet.IsEffect(SPELL_EFFECT_LEARN_SPELL) && effet.TriggerSpell)
                                sorts.push_back(effet.TriggerSpell);
                    for (uint32 sort : sorts)
                        if (player->HasSpell(sort) && vus.insert(sort).second)
                            envoi.Ajouter(Acore::StringFormat("{}:{}", classe, sort));
                }
            }
        }
        EnvoyerAddon(player, "GFIN");
    }

    bool Payer(Player* player, uint32 cout)
    {
        if (!player->HasEnoughMoney(cout))
        {
            ChatHandler(player->GetSession()).SendSysMessage("|cffff0000Pas assez d'or.|r");
            return false;
        }
        player->ModifyMoney(-int32(cout));
        return true;
    }

    // Le sort lui-même, ou ceux qu'il apprend si c'est un sort d'apprentissage.
    std::vector<uint32> SortsAppris(uint32 sort)
    {
        std::vector<uint32> sorts;
        if (SpellInfo const* info = sSpellMgr->GetSpellInfo(sort))
            for (SpellEffectInfo const& effet : info->GetEffects())
                if (effet.IsEffect(SPELL_EFFECT_LEARN_SPELL) && effet.TriggerSpell)
                    sorts.push_back(effet.TriggerSpell);
        if (sorts.empty())
            sorts.push_back(sort);
        return sorts;
    }

    // Comme l'entraîneur : apprendre directement, ou lancer le sort d'apprentissage.
    // Un sort à totem (Totem de peau de pierre…) donne aussi le totem du chaman qui manque.
    void Enseigner(Player* player, uint32 sort)
    {
        SpellInfo const* info = sSpellMgr->GetSpellInfo(sort);
        if (info && info->HasEffect(SPELL_EFFECT_LEARN_SPELL))
            player->CastSpell(player, sort, true);
        else
            player->learnSpell(sort, false);

        for (uint32 appris : SortsAppris(sort))
            if (SpellInfo const* a = sSpellMgr->GetSpellInfo(appris))
                for (uint32 categorie : a->TotemCategory)
                {
                    auto totem = TOTEMS.find(categorie);
                    if (totem == TOTEMS.end() || player->HasItemTotemCategory(categorie))
                        continue;
                    if (player->AddItem(totem->second, 1))
                        ChatHandler(player->GetSession()).SendSysMessage("Ce sort demande un totem : il est dans tes sacs.");
                    else
                        ChatHandler(player->GetSession()).SendSysMessage("|cffff0000Sacs pleins : ce sort demande un totem. Libère une place et rachète-le dans l'onglet Outils.|r");
                }
    }
}

// Réglage 3 de la source « solazeroth-defis » : défi Destin choisi (lua_scripts/defis.lua).
bool SolAzeroth::EstDestin(Player* player)
{
    return player->GetPlayerSetting("solazeroth-defis", 3).value == 1;
}

class solazeroth_formation_monde : public WorldScript
{
public:
    solazeroth_formation_monde() : WorldScript("solazeroth_formation_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        multiplicateurAutresClasses = sConfigMgr->GetOption<uint32>("SolAzeroth.Formation.MultiplicateurAutresClasses", 10);
    }

    void OnStartup() override
    {
        QueryResult resultat = WorldDatabase.Query(
            "SELECT t.Type, t.Requirement, s.SpellId, s.MoneyCost, s.ReqSkillLine, s.ReqSkillRank, "
            "s.ReqAbility1, s.ReqAbility2, s.ReqAbility3, s.ReqLevel "
            "FROM trainer t JOIN trainer_spell s ON s.TrainerId = t.Id WHERE t.Type IN (0, 2) ORDER BY s.MoneyCost");
        if (!resultat)
            return;

        std::array<std::unordered_map<uint32, bool>, MAX_CLASSES> vusClasse;
        std::unordered_map<uint32, bool> vusMetier;
        do
        {
            Field* f = resultat->Fetch();
            Entree e;
            uint32 type = f[0].Get<uint32>();
            uint32 exigence = f[1].Get<uint32>();
            e.sort = f[2].Get<uint32>();
            e.cout = f[3].Get<uint32>();
            e.competence = f[4].Get<uint32>();
            e.rangCompetence = f[5].Get<uint32>();
            e.sortsRequis = { f[6].Get<uint32>(), f[7].Get<uint32>(), f[8].Get<uint32>() };
            e.niveau = f[9].Get<uint8>();

            SpellInfo const* info = sSpellMgr->GetSpellInfo(e.sort);
            if (!info)
                continue;

            if (type == 0)
            {
                if (exigence == 0 || exigence >= MAX_CLASSES || vusClasse[exigence].count(e.sort))
                    continue;
                vusClasse[exigence][e.sort] = true;
                e.categorie = 'S';
                sortsDeClasse[exigence].push_back(e);
                continue;
            }

            if (vusMetier.count(e.sort))
                continue;
            vusMetier[e.sort] = true;
            e.exigence = exigence;

            // Rang de métier : le sort (ou celui qu'il apprend) donne une compétence de métier.
            SpellInfo const* appris = info;
            for (SpellEffectInfo const& effet : info->GetEffects())
                if (effet.IsEffect(SPELL_EFFECT_LEARN_SPELL))
                    if (SpellInfo const* cible = sSpellMgr->GetSpellInfo(effet.TriggerSpell))
                        appris = cible;
            e.categorie = 'R';
            for (SpellEffectInfo const& effet : appris->GetEffects())
            {
                if (effet.IsEffect(SPELL_EFFECT_SKILL) && IsProfessionSkill(effet.MiscValue))
                {
                    e.categorie = 'M';
                    if (!e.competence)
                        e.competence = effet.MiscValue;
                }
            }
            metiers.push_back(e);
        } while (resultat->NextRow());

        // Sorts de familier obtenus par quête dans le jeu d'origine, absents des entraîneurs : on les vend aussi
        // (demande de l'utilisateur), au niveau de la quête et au prix d'un sort d'entraîneur de ce niveau.
        struct SortDeQuete { uint8 classe; uint32 sort; uint8 niveau; };
        std::vector<SortDeQuete> const SORTS_DE_QUETE =
        {
            { CLASS_HUNTER, 1515, 10 },   // Dressage
            { CLASS_HUNTER, 883, 10 },    // Appel du familier
            { CLASS_HUNTER, 2641, 10 },   // Renvoyer le familier
            { CLASS_HUNTER, 982, 10 },    // Ressusciter le familier
            { CLASS_HUNTER, 6991, 10 },   // Nourrir le familier
            { CLASS_WARLOCK, 697, 10 },   // Invocation d'un marcheur du Vide
            { CLASS_WARLOCK, 712, 20 },   // Invocation d'une succube
            { CLASS_WARLOCK, 691, 30 },   // Invocation d'un chasseur corrompu
        };
        // Sorts déjà vendus par classe, y compris ceux qu'apprend un sort d'apprentissage.
        std::array<std::set<uint32>, MAX_CLASSES> vendus;
        for (uint8 classe = 1; classe < MAX_CLASSES; ++classe)
            for (Entree const& e : sortsDeClasse[classe])
            {
                vendus[classe].insert(e.sort);
                for (uint32 appris : SortsAppris(e.sort))
                    vendus[classe].insert(appris);
            }
        auto Vendre = [&](uint8 classe, uint32 sort, uint8 niveau)
        {
            if (classe == 0 || classe >= MAX_CLASSES || vendus[classe].count(sort) || !sSpellMgr->GetSpellInfo(sort))
                return;
            vendus[classe].insert(sort);
            Entree e;
            e.categorie = 'S';
            e.sort = sort;
            e.niveau = std::max<uint8>(1, niveau);
            e.cout = e.niveau * 60;
            sortsDeClasse[classe].push_back(e);
        };
        auto ClasseUnique = [](uint32 masque) -> uint8
        {
            for (uint8 classe = 1; classe < MAX_CLASSES; ++classe)
                if (masque == (1u << (classe - 1)))
                    return classe;
            return 0;
        };

        for (SortDeQuete const& q : SORTS_DE_QUETE)
            Vendre(q.classe, q.sort, q.niveau);

        // Sorts de départ : appris avec la compétence de classe, à la création du personnage (pas les passifs ni
        // les talents).
        for (uint32 i = 0; i < sSkillLineAbilityStore.GetNumRows(); ++i)
        {
            SkillLineAbilityEntry const* capacite = sSkillLineAbilityStore.LookupEntry(i);
            if (!capacite || capacite->AcquireMethod != SKILL_LINE_ABILITY_LEARNED_ON_SKILL_LEARN)
                continue;
            SkillLineEntry const* ligne = sSkillLineStore.LookupEntry(capacite->SkillLine);
            SpellInfo const* info = sSpellMgr->GetSpellInfo(capacite->Spell);
            if (!ligne || ligne->categoryId != SKILL_CATEGORY_CLASS || !info || info->IsPassive() || GetTalentSpellPos(capacite->Spell))
                continue;
            Vendre(ClasseUnique(capacite->ClassMask), capacite->Spell, 1);
        }

        // Sorts des quêtes de classe : ceux qu'apprend la récompense, au niveau minimal de la quête. On laisse de côté
        // l'équitation (apprise avec certaines montures de classe) : elle s'achète à part.
        if (QueryResult r = WorldDatabase.Query("SELECT a.AllowableClasses, q.MinLevel, q.RewardSpell FROM quest_template q "
            "JOIN quest_template_addon a ON a.ID = q.ID WHERE a.AllowableClasses <> 0 AND q.RewardSpell > 0 ORDER BY q.MinLevel"))
        {
            do
            {
                Field* f = r->Fetch();
                uint8 classe = ClasseUnique(f[0].Get<uint32>());
                SpellInfo const* recompense = sSpellMgr->GetSpellInfo(f[2].Get<uint32>());
                if (!classe || !recompense)
                    continue;
                for (SpellEffectInfo const& effet : recompense->GetEffects())
                {
                    if (!effet.IsEffect(SPELL_EFFECT_LEARN_SPELL))
                        continue;
                    SpellInfo const* appris = sSpellMgr->GetSpellInfo(effet.TriggerSpell);
                    if (!appris || appris->HasEffect(SPELL_EFFECT_SKILL) || appris->HasEffect(SPELL_EFFECT_SKILL_STEP)
                        || appris->IsPassive() || GetTalentSpellPos(effet.TriggerSpell))
                        continue;
                    Vendre(classe, effet.TriggerSpell, f[1].Get<uint8>());
                }
            } while (r->NextRow());
        }

        // Postures, formes et camouflages vendus : forme -> sorts qui la donnent ; camouflage à part.
        std::unordered_map<uint32, std::vector<uint32>> sortsDeForme;
        std::vector<uint32> camouflages;
        for (uint8 classe = 1; classe < MAX_CLASSES; ++classe)
            for (Entree const& e : sortsDeClasse[classe])
                for (uint32 appris : SortsAppris(e.sort))
                    if (SpellInfo const* info = sSpellMgr->GetSpellInfo(appris))
                        for (SpellEffectInfo const& effet : info->GetEffects())
                        {
                            if (effet.IsAura(SPELL_AURA_MOD_SHAPESHIFT))
                                sortsDeForme[effet.MiscValue].push_back(appris);
                            else if (effet.IsAura(SPELL_AURA_MOD_STEALTH))
                                camouflages.push_back(appris);
                        }
        // Sort qui ne se lance qu'en posture ou en forme (hors forme normale), ou camouflé : il en exige une.
        size_t exigeants = 0;
        for (uint8 classe = 1; classe < MAX_CLASSES; ++classe)
            for (Entree& e : sortsDeClasse[classe])
                for (uint32 appris : SortsAppris(e.sort))
                {
                    SpellInfo const* info = sSpellMgr->GetSpellInfo(appris);
                    if (!info)
                        continue;
                    if (info->HasAttribute(SPELL_ATTR0_ONLY_STEALTHED))
                        e.formes = camouflages;
                    else if (info->Stances && !info->HasAttribute(SPELL_ATTR2_ALLOW_WHILE_NOT_SHAPESHIFTED))
                        for (uint32 forme = 1; forme <= 32; ++forme)
                            if (info->Stances & (1u << (forme - 1)))
                                for (uint32 sort : sortsDeForme[forme])
                                    e.formes.push_back(sort);
                    if (!e.formes.empty())
                    {
                        ++exigeants;
                        break;
                    }
                }
        LOG_INFO("module", "Sol'Azeroth apprentissage : {} sorts demandent une posture, une forme ou le camouflage", exigeants);

        size_t classe = 0, rangs = 0;
        for (auto const& sorts : sortsDeClasse)
            classe += sorts.size();
        for (Entree const& e : metiers)
            rangs += e.categorie == 'M';
        LOG_INFO("module", "Sol'Azeroth apprentissage : {} sorts de classe, {} rangs de métier, {} recettes",
            classe, rangs, metiers.size() - rangs);
    }
};

class solazeroth_formation_commandes : public CommandScript
{
public:
    solazeroth_formation_commandes() : CommandScript("solazeroth_formation_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "liste",   HandleListe,   SEC_PLAYER, Console::No },
            { "classe",  HandleClasse,  SEC_PLAYER, Console::No },
            { "grimoire", HandleGrimoire, SEC_PLAYER, Console::No },
            { "acheter", HandleAcheter, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solform", sousCommandes },
        };
        return commandes;
    }

    static bool HandleListe(ChatHandler* handler)
    {
        EnvoyerCatalogue(handler->GetSession()->GetPlayer());
        return true;
    }

    static bool HandleGrimoire(ChatHandler* handler)
    {
        EnvoyerGrimoire(handler->GetSession()->GetPlayer());
        return true;
    }

    static bool HandleClasse(ChatHandler* handler, uint8 classe)
    {
        EnvoyerAutreClasse(handler->GetSession()->GetPlayer(), classe);
        return true;
    }

    static bool HandleAcheter(ChatHandler* handler, std::string categorie, uint32 id)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (categorie.empty())
            return true;

        // Sort d'une autre classe : on ne renvoie que la liste de cette classe.
        if (categorie[0] == 'X')
        {
            if (SolAzeroth::EstDestin(player))
            {
                handler->SendSysMessage("|cffff0000Ligue Destin : tu joues la classe que le destin t'a donnée, sans sorts d'autres classes.|r");
                return true;
            }
            for (uint8 classe = 1; classe < MAX_CLASSES; ++classe)
            {
                if (classe == player->getClass())
                    continue;
                for (Entree const& e : sortsDeClasse[classe])
                {
                    if (e.sort != id)
                        continue;
                    if (EXCLUS_AUTRES_CLASSES.count(e.sort))
                        handler->SendSysMessage("|cffff0000Ce sort ne s'apprend pas hors de sa classe.|r");
                    else if (EtatSort(player, e, true) != DISPONIBLE)
                        handler->SendSysMessage("|cffff0000Pas encore disponible.|r");
                    else if (Payer(player, e.cout * multiplicateurAutresClasses))
                        Enseigner(player, e.sort);
                    EnvoyerAutreClasse(player, classe);
                    return true;
                }
            }
            return true;
        }

        switch (categorie[0])
        {
            case 'S':
            case 'M':
            case 'R':
            {
                std::vector<Entree> const& liste = categorie[0] == 'S' ? sortsDeClasse[player->getClass()] : metiers;
                for (Entree const& e : liste)
                {
                    if (e.sort != id || e.categorie != categorie[0])
                        continue;
                    if (EtatSort(player, e) != DISPONIBLE)
                    {
                        handler->SendSysMessage("|cffff0000Pas encore disponible.|r");
                        break;
                    }
                    if (Payer(player, e.cout))
                        Enseigner(player, e.sort);
                    break;
                }
                break;
            }
            case 'C':
                for (Maitrise const& m : MAITRISES)
                {
                    if (m.sort != id || player->HasSpell(m.sort))
                        continue;
                    if (player->GetLevel() < m.niveau)
                        handler->SendSysMessage(Acore::StringFormat("|cffff0000Niveau {} requis.|r", m.niveau));
                    else if (Payer(player, m.cout))
                    {
                        player->learnSpell(m.sort, false);
                        if (m.avec)
                            player->learnSpell(m.avec, false);
                        player->UpdateSkillsToMaxSkillsForLevel();
                    }
                    break;
                }
                break;
            case 'O':
                if (std::find(OUTILS.begin(), OUTILS.end(), id) == OUTILS.end())
                    break;
                if (ItemTemplate const* modele = sObjectMgr->GetItemTemplate(id))
                {
                    if (!player->HasEnoughMoney(modele->BuyPrice))
                        handler->SendSysMessage("|cffff0000Pas assez d'or.|r");
                    else if (player->AddItem(id, 1))
                        player->ModifyMoney(-int32(modele->BuyPrice));
                    else
                        handler->SendSysMessage("|cffff0000Sacs pleins.|r");
                }
                break;
            case 'I':
                SolAzeroth::AcheterIntendant(player, id);
                break;
            case 'E':
                SolAzeroth::AcheterEclats(player, id);
                break;
            default:
                break;
        }
        EnvoyerCatalogue(player);
        return true;
    }
};

// Une maîtrise achetée dont la compétence a disparu (effacée par le serveur avant la migration 017) :
// on réapprend le sort pour remettre la compétence, sans faire payer à nouveau.
class solazeroth_formation_reparation : public PlayerScript
{
public:
    solazeroth_formation_reparation() : PlayerScript("solazeroth_formation_reparation", { PLAYERHOOK_ON_LOGIN }) { }

    void OnPlayerLogin(Player* player) override
    {
        bool repare = false;
        for (Maitrise const& m : MAITRISES)
        {
            if (!player->HasSpell(m.sort))
                continue;
            SkillLineAbilityMapBounds bornes = sSpellMgr->GetSkillLineAbilityMapBounds(m.sort);
            for (auto it = bornes.first; it != bornes.second; ++it)
            {
                if (player->HasSkill(it->second->SkillLine))
                    continue;
                player->removeSpell(m.sort, SPEC_MASK_ALL, false);
                player->learnSpell(m.sort, false);
                repare = true;
                break;
            }
        }
        if (repare)
        {
            player->UpdateSkillsToMaxSkillsForLevel();
            ChatHandler(player->GetSession()).SendSysMessage("Maîtrises d'armes et d'armures réparées.");
        }
    }
};

void AddSC_solazeroth_formation()
{
    new solazeroth_formation_monde();
    new solazeroth_formation_commandes();
    new solazeroth_formation_reparation();
}
