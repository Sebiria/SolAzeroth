// v3, F5e (31/10/2026) : pourcentage de la zone (document v3, F5 ; document de Durotar, §4).
// Les parts sont dans acore_world.solazeroth_v3_zone_parts (migration 074, générée par outils\zone_durotar.py), en
// centièmes de % :
// - genre 1, quête d'histoire rendue ;
// - genre 2, sous-zone explorée (les zones découvertes du jeu, PLAYER_EXPLORED_ZONES) ;
// - genre 3, lieu à nettoyer : tous les monstres de sa troupe tués dans la zone, au nombre voulu
//   (solazeroth_v3_lieux_monstres). Les monstres tués pour une quête comptent aussi.
//   Lot T0 des Tarides (03/11/2026, migration 135) : deux colonnes par ligne. « sous_zones » : liste de sous-zones
//   (GetAreaId() du monstre), vide pour toute la zone (Durotar) ; une même entrée vit dans plusieurs lieux aux Tarides.
//   « invocations » : 0, les créatures invoquées (vagues, renforts) ne comptent pas ; 1, elles comptent (Durotar,
//   comme avant).
// Chef renforcé (A01, A02, A05, A06, A10 ; solazeroth_v3_lieux_chefs, créatures de la migration 075) : quand la
// troupe est tombée et que le joueur est à moins de PROCHE m de la place du chef, le chef d'origine disparaît et sa
// copie renforcée apparaît, annoncée dans la discussion avec sa distance (essai du 31/10/2026 : bloqué à 45/46 au fort de
// Tiragarde sans savoir que le chef attendait en haut). C'est sa mort qui clôt le lieu ; la troupe repart alors à zéro, pour que le chef revienne
// au prochain nettoyage (défis à venir).
// Le chef renforcé n'apparaît pas tant qu'une quête du journal, pas encore remplie, vise le chef d'origine (le tuer ou
// prendre un objet de quête sur lui : histoire, défis comme « Le Convent en cinq minutes »). Sinon la puissance annoncée
// de la quête serait fausse dès que la troupe est tombée, ses monstres comptant aussi pour les quêtes (remarque de
// l'utilisateur du 01/11/2026). Un chef renforcé déjà apparu, hors combat, s'efface alors et le chef d'origine revient.
// Lot T0 : aux quêtes trouvées ainsi s'ajoutent celles de solazeroth_v3_lieux_chefs_quetes (lieu, quête), pour une quête
// qui vise le chef sans le tuer ni prendre d'objet sur lui.
// Lot T3 des Tarides (03/11/2026, décision 2 du brouillon) : un lieu paie à sa première fermeture (mort du chef renforcé,
// ou troupe complète pour un lieu sans chef renforcé) ce que donne solazeroth_v3_lieux_recompenses (Marques, cuivre,
// éclats, composants « objet:nombre,… » rangés dans la Collection). Payé une fois par personnage
// (acore_characters.solazeroth_v3_lieux_payes). Seuls les lieux des Tarides ont une ligne (migration 140) : Durotar
// ne paie rien, comme avant.
// - genre 4 (31/10/2026), annexe à quête (primes, contrats, défis : migration 084, v3_annexes.cpp) : la quête rendue ;
// - genre 5, relique : son objet dans la Collection.
// Interface (SolUI_Zone.lua, préfixe SOLZONE), quand ça change et qu'on est dans une zone qui a des parts :
// « POURCENT;total;histoire;exploration;annexes », « EXPLO;faites;total », « LIEU;lieu;nom;tués;requis;part;nettoyé;quête »
// pour chaque lieu (le chef renforcé compte dans « requis » ; « quête » : titre de la quête du journal qui retient le chef
// renforcé, vide sinon), « ANNEXE;quête;état;médaille;payé aujourd'hui » (état : 0 à prendre,
// 1 en cours, 2 à rendre, 3 rendue), « RELIQUE;objet;trouvée », « CARTE;0|1 » (carte des reliques achetée),
// « SECRETS;vaincus;total;noms » (lot 6b, rares secrets), puis « FINZONE ». Les annexes du pourcentage regroupent
// les genres 3 à 5. Hors de ces zones : « POURCENT;-1 ».

#include "SolAzeroth.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringConvert.h"
#include "StringFormat.h"
#include "Tokenize.h"
#include <algorithm>
#include <functional>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace
{
    uint8 const QUETE = 1, EXPLORATION = 2, LIEU = 3, ANNEXE = 4, RELIQUE = 5;
    uint32 const RELECTURE = 2000;
    float const PROCHE = 120.0f;
    uint32 const DUREE_CHEF = 10 * MINUTE * IN_MILLISECONDS;   // le chef disparaît 10 min après la fin du combat

    struct Part
    {
        uint8 genre;
        uint32 cle, part;
        std::string nom;
    };

    std::unordered_map<uint32, std::vector<Part>> parts;                                // zone -> parts
    struct Compte
    {
        uint32 lieu, nombre;
        std::vector<uint32> sousZones;   // vide : toute la zone du lieu
        bool invocations;                // les créatures invoquées comptent
    };
    std::unordered_map<uint32, std::vector<std::pair<uint32, uint32>>> monstresDuLieu;  // lieu -> (créature, nombre)
    std::unordered_map<uint32, std::vector<Compte>> lieuxDuMonstre;                      // créature -> lieux
    std::unordered_map<uint32, uint32> zoneDuLieu;

    struct Chef
    {
        uint32 origine = 0, renforce = 0, carte = 0;
        ObjectGuid::LowType apparition = 0;   // apparition du chef d'origine
        Position place;
        std::vector<uint32> quetes;           // quêtes qui visent le chef d'origine
    };
    std::unordered_map<uint32, Chef> chefs;              // lieu -> chef renforcé
    std::unordered_map<uint32, uint32> lieuDuRenforce;   // copie renforcée -> lieu

    // Lot T3 : récompense d'un lieu, à sa première fermeture.
    uint32 const ECLAT = 910120;
    struct Recompense
    {
        uint32 marques = 0, cuivre = 0, eclats = 0;
        std::vector<std::pair<uint32, uint32>> composants;
    };
    std::unordered_map<uint32, Recompense> recompenses;   // lieu -> récompense
    std::unordered_map<uint32, std::string> nomDuLieu;

    struct Progres : DataMap::Base
    {
        std::unordered_map<uint64, uint32> tues;   // (lieu << 32 | créature) -> nombre ; chef renforcé : 1 = lieu clos
        std::unordered_map<uint32, ObjectGuid> invoques;   // lieu -> chef renforcé apparu
        std::unordered_set<uint32> prevenus;               // lieux dont le chef attend la fin d'une quête (annoncé)
        std::unordered_set<uint32> payes;                  // lieux déjà payés (lot T3)
        uint32 attente = 0;
        size_t empreinte = 0;
    };

    Progres* ProgresDe(Player* player)
    {
        return player->CustomData.GetDefault<Progres>("solazeroth_v3_zone");
    }

    uint64 Cle(uint32 lieu, uint32 creature)
    {
        return (uint64(lieu) << 32) | creature;
    }

    bool Explore(Player* player, uint32 zone)
    {
        AreaTableEntry const* aire = sAreaTableStore.LookupEntry(zone);
        if (!aire || aire->exploreFlag / 32 >= PLAYER_EXPLORED_ZONES_SIZE)
            return false;
        return player->GetUInt32Value(PLAYER_EXPLORED_ZONES_1 + aire->exploreFlag / 32) & (1u << (aire->exploreFlag % 32));
    }

    // Monstres de la troupe tués (au plus le nombre voulu de chacun) et nombre voulu.
    std::pair<uint32, uint32> Troupe(Progres* p, uint32 lieu)
    {
        uint32 tues = 0, requis = 0;
        for (auto const& [creature, nombre] : monstresDuLieu[lieu])
        {
            tues += std::min(nombre, p->tues[Cle(lieu, creature)]);
            requis += nombre;
        }
        return { tues, requis };
    }

    bool Acquis(Player* player, Progres* p, Part const& part)
    {
        if (part.genre == QUETE)
            return player->GetQuestRewardStatus(part.cle);
        if (part.genre == EXPLORATION)
            return Explore(player, part.cle);
        if (part.genre == ANNEXE)
            return player->GetQuestRewardStatus(part.cle);
        if (part.genre == RELIQUE)
            return SolAzeroth::NombreEnCollection(player, part.cle) > 0;
        if (auto c = chefs.find(part.cle); c != chefs.end())
            return p->tues[Cle(part.cle, c->second.renforce)] != 0;
        auto [tues, requis] = Troupe(p, part.cle);
        return requis && tues >= requis;
    }

    // Lot T3 : paiement d'un lieu à sa première fermeture.
    void Payer(Player* player, Progres* p, uint32 lieu)
    {
        auto r = recompenses.find(lieu);
        if (r == recompenses.end() || !p->payes.insert(lieu).second)
            return;
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_lieux_payes (guid, lieu) VALUES ({}, {})",
            player->GetGUID().GetCounter(), lieu);
        Recompense const& rec = r->second;
        std::string const& nom = nomDuLieu[lieu];
        SolAzeroth::DonnerMarques(player, rec.marques, nom);
        if (rec.cuivre)
            player->ModifyMoney(int32(rec.cuivre));
        if (rec.eclats)
            SolAzeroth::AjouterACollection(player, ECLAT, rec.eclats);
        for (auto const& [objet, nombre] : rec.composants)
            SolAzeroth::AjouterACollection(player, objet, nombre);
        ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat(
            "|cfff6c27a{} : lieu nettoyé.|r {} po {} pa, {} éclats et {} composant(s) rangés dans la Collection.", nom,
            rec.cuivre / GOLD, rec.cuivre % GOLD / SILVER, rec.eclats, rec.composants.size()));
    }

    // Quête du journal, pas encore remplie, qui vise le chef d'origine (0 : aucune).
    uint32 QueteSurLeChef(Player* player, Chef const& chef)
    {
        for (uint32 quete : chef.quetes)
            if (player->GetQuestStatus(quete) == QUEST_STATUS_INCOMPLETE)
                return quete;
        return 0;
    }

    std::string TitreQuete(uint32 quete)
    {
        Quest const* q = sObjectMgr->GetQuestTemplate(quete);
        if (!q)
            return "";
        std::string titre = q->GetTitle();
        if (QuestLocale const* l = sObjectMgr->GetQuestLocale(quete))
            ObjectMgr::GetLocaleString(l->Title, LOCALE_frFR, titre);
        return titre;
    }

    // Troupe tombée et joueur près de la place : le chef d'origine s'efface devant sa copie renforcée.
    void FaireApparaitre(Player* player, Progres* p, uint32 lieu, std::string const& nomLieu, Chef const& chef)
    {
        auto [tues, requis] = Troupe(p, lieu);
        if (tues < requis || player->GetMapId() != chef.carte || player->GetDistance(chef.place) > PROCHE)
            return;
        Creature* renforce = ObjectAccessor::GetCreature(*player, p->invoques[lieu]);
        if (uint32 quete = QueteSurLeChef(player, chef))
        {
            if (renforce && renforce->IsAlive() && !renforce->IsInCombat())
            {
                renforce->DespawnOrUnsummon();
                p->invoques.erase(lieu);
                auto [debut, fin] = player->GetMap()->GetCreatureBySpawnIdStore().equal_range(chef.apparition);
                for (auto it = debut; it != fin; ++it)
                    if (!it->second->IsAlive())
                        it->second->Respawn(true);
            }
            if (p->prevenus.insert(lieu).second)
                ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat(
                    "|cfff6c27a{} :|r le chef renforcé attendra que « {} » soit remplie.", nomLieu, TitreQuete(quete)));
            return;
        }
        p->prevenus.erase(lieu);
        if (!renforce)
        {
            renforce = player->SummonCreature(chef.renforce, chef.place, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, DUREE_CHEF);
            if (!renforce)
                return;
            p->invoques[lieu] = renforce->GetGUID();
            float hauteur = renforce->GetPositionZ() - player->GetPositionZ();
            // Alerte de raid au milieu de l'écran, avec son bruit (SolUI_Zone.lua), plutôt que dans la discussion.
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", Acore::StringFormat(
                "ALERTE;{} : le chef est apparu, {} à {:.0f} m{}", nomLieu,
                renforce->GetNameForLocaleIdx(player->GetSession()->GetSessionDbLocaleIndex()),
                player->GetExactDist(renforce), hauteur > 5.0f ? ", plus haut" : hauteur < -5.0f ? ", plus bas" : ""));
        }
        if (renforce->IsAlive())
            if (Creature* origine = renforce->FindNearestCreature(chef.origine, PROCHE, true); origine && !origine->IsInCombat())
                origine->DespawnOrUnsummon();
    }

    void Envoyer(Player* player, Progres* p)
    {
        auto it = parts.find(player->GetZoneId());
        if (it == parts.end())
        {
            if (p->empreinte != 1)
                SolAzeroth::EnvoyerAddon(player, "SOLZONE", "POURCENT;-1");
            p->empreinte = 1;
            return;
        }
        uint32 sommes[6] = {};
        uint32 explorees = 0, sousZones = 0;
        std::vector<std::string> lieux;
        for (Part const& part : it->second)
        {
            bool acquis = Acquis(player, p, part);
            if (part.genre == EXPLORATION)
            {
                ++sousZones;
                explorees += acquis;
            }
            else if (part.genre == LIEU)
            {
                auto [tues, requis] = Troupe(p, part.cle);
                std::string attente;
                if (auto c = chefs.find(part.cle); c != chefs.end())
                {
                    FaireApparaitre(player, p, part.cle, part.nom, c->second);
                    if (uint32 quete = acquis ? 0 : QueteSurLeChef(player, c->second))
                        attente = TitreQuete(quete);
                    ++requis;
                }
                lieux.push_back(Acore::StringFormat("LIEU;{};{};{};{};{};{};{}", part.cle, part.nom, tues, requis, part.part,
                    acquis ? 1 : 0, attente));
            }
            else if (part.genre == ANNEXE)
            {
                QuestStatus statut = player->GetQuestStatus(part.cle);
                uint8 etat = acquis ? 3 : statut == QUEST_STATUS_COMPLETE ? 2 : statut == QUEST_STATUS_INCOMPLETE ? 1 : 0;
                lieux.push_back(Acore::StringFormat("ANNEXE;{};{};{};{}", part.cle, etat,
                    SolAzeroth::MedailleDefi(player, part.cle), SolAzeroth::DefiPayeAujourdhui(player, part.cle) ? 1 : 0));
            }
            else if (part.genre == RELIQUE)
                lieux.push_back(Acore::StringFormat("RELIQUE;{};{}", part.cle, acquis ? 1 : 0));
            if (acquis)
                sommes[part.genre] += part.part;
        }
        lieux.push_back(Acore::StringFormat("CARTE;{}", SolAzeroth::CarteReliques(player) ? 1 : 0));
        if (std::string secrets = SolAzeroth::RaresSecrets(player, it->first); !secrets.empty())
            lieux.push_back(secrets);   // lot 6b : rares secrets (v3_rares_secrets.cpp)
        uint32 annexes = sommes[LIEU] + sommes[ANNEXE] + sommes[RELIQUE];
        std::string pourcent = Acore::StringFormat("POURCENT;{};{};{};{}", sommes[QUETE] + sommes[EXPLORATION] + annexes,
            sommes[QUETE], sommes[EXPLORATION], annexes);
        std::string explo = Acore::StringFormat("EXPLO;{};{}", explorees, sousZones);
        std::string tout = pourcent + explo;
        for (std::string const& l : lieux)
            tout += l;
        size_t empreinte = std::hash<std::string>{}(tout) | 2;
        if (empreinte == p->empreinte)
            return;
        p->empreinte = empreinte;
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", pourcent);
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", explo);
        for (std::string const& l : lieux)
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", l);
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", "FINZONE");
    }
}

unsigned int SolAzeroth::PourcentZone(Player* player, unsigned int zone)
{
    auto it = parts.find(zone);
    if (it == parts.end())
        return 0;
    Progres* p = ProgresDe(player);
    uint32 somme = 0;
    for (Part const& part : it->second)
        if (Acquis(player, p, part))
            somme += part.part;
    return somme;
}

void SolAzeroth::ObjectifsAcquis(Player* player, std::function<void(unsigned int, unsigned char, unsigned int)> const& f)
{
    Progres* p = ProgresDe(player);
    for (auto const& [zone, liste] : parts)
        for (Part const& part : liste)
            if (Acquis(player, p, part))
                f(zone, part.genre, part.cle);
}

// v3, lot 3b (02/11/2026) : chef renforcé du lieu tombé (le lieu est clos). Le kit en dépend (v3_kit.cpp).
bool SolAzeroth::LieuClos(Player* player, unsigned int lieu)
{
    auto c = chefs.find(lieu);
    return c != chefs.end() && ProgresDe(player)->tues[Cle(lieu, c->second.renforce)] != 0;
}

bool SolAzeroth::MonstreDeLieu(unsigned int entree)
{
    return lieuxDuMonstre.count(entree) > 0;
}

// Lot T0 des Tarides : copie renforcée d'un chef de lieu (solazeroth_v3_lieux_chefs), pour les éclats et les passifs.
bool SolAzeroth::ChefRenforce(unsigned int entree)
{
    return lieuDuRenforce.count(entree) > 0;
}

std::vector<unsigned int> SolAzeroth::ZonesAvecParts()
{
    std::vector<unsigned int> zones;
    for (auto const& [zone, liste] : parts)
        zones.push_back(zone);
    return zones;
}

class solazeroth_v3_zone_joueur : public PlayerScript
{
public:
    solazeroth_v3_zone_joueur() : PlayerScript("solazeroth_v3_zone_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CREATURE_KILL_CREDIT, PLAYERHOOK_ON_DELETE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Progres* p = ProgresDe(player);
        if (QueryResult r = CharacterDatabase.Query("SELECT lieu, creature, nombre FROM solazeroth_v3_lieux WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            do
                p->tues[Cle((*r)[0].Get<uint32>(), (*r)[1].Get<uint32>())] = (*r)[2].Get<uint32>();
            while (r->NextRow());
        }
        if (QueryResult r = CharacterDatabase.Query("SELECT lieu FROM solazeroth_v3_lieux_payes WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            do
                p->payes.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
    }

    void OnPlayerCreatureKillCredit(Player* player, Creature* creature) override
    {
        if (auto c = lieuDuRenforce.find(creature->GetEntry()); c != lieuDuRenforce.end())
        {
            // Chef renforcé tué : lieu clos, la troupe repart à zéro.
            uint32 lieu = c->second;
            Progres* p = ProgresDe(player);
            for (auto const& [membre, nombre] : monstresDuLieu[lieu])
                p->tues[Cle(lieu, membre)] = 0;
            p->tues[Cle(lieu, creature->GetEntry())] = 1;
            p->invoques.erase(lieu);
            p->attente = 0;
            CharacterDatabase.Execute("DELETE FROM solazeroth_v3_lieux WHERE guid = {} AND lieu = {}",
                player->GetGUID().GetCounter(), lieu);
            CharacterDatabase.Execute("INSERT INTO solazeroth_v3_lieux (guid, lieu, creature, nombre) VALUES ({}, {}, {}, 1)",
                player->GetGUID().GetCounter(), lieu, creature->GetEntry());
            Payer(player, p, lieu);
            return;
        }
        auto it = lieuxDuMonstre.find(creature->GetEntry());
        if (it == lieuxDuMonstre.end())
            return;
        Progres* p = ProgresDe(player);
        for (Compte const& compte : it->second)
        {
            uint32 const lieu = compte.lieu, nombre = compte.nombre;
            uint32& tues = p->tues[Cle(lieu, creature->GetEntry())];
            if (zoneDuLieu[lieu] != creature->GetZoneId() || tues >= nombre)
                continue;
            if (!compte.invocations && creature->IsSummon())
                continue;
            if (!compte.sousZones.empty() && std::find(compte.sousZones.begin(), compte.sousZones.end(),
                creature->GetAreaId()) == compte.sousZones.end())
                continue;
            ++tues;
            CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_lieux (guid, lieu, creature, nombre) VALUES ({}, {}, {}, {})",
                player->GetGUID().GetCounter(), lieu, creature->GetEntry(), tues);
            p->attente = 0;
            // Lieu sans chef renforcé : il se ferme quand la troupe est complète.
            if (!chefs.count(lieu))
                if (auto [faits, requis] = Troupe(p, lieu); requis && faits >= requis)
                    Payer(player, p, lieu);
        }
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Progres* p = ProgresDe(player);
        if (p->attente > diff)
        {
            p->attente -= diff;
            return;
        }
        p->attente = RELECTURE;
        if (player->IsInWorld())
            Envoyer(player, p);
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_lieux WHERE guid = {}", guid.GetCounter());
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_lieux_payes WHERE guid = {}", guid.GetCounter());
    }
};

class solazeroth_v3_zone_monde : public WorldScript
{
public:
    solazeroth_v3_zone_monde() : WorldScript("solazeroth_v3_zone_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        parts.clear();
        monstresDuLieu.clear();
        lieuxDuMonstre.clear();
        zoneDuLieu.clear();
        chefs.clear();
        lieuDuRenforce.clear();
        recompenses.clear();
        nomDuLieu.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT zone, genre, cle, part, nom FROM solazeroth_v3_zone_parts"))
        {
            do
            {
                Field* f = r->Fetch();
                Part part{ f[1].Get<uint8>(), f[2].Get<uint32>(), f[3].Get<uint32>(), f[4].Get<std::string>() };
                if (part.genre == LIEU)
                {
                    zoneDuLieu[part.cle] = f[0].Get<uint32>();
                    nomDuLieu[part.cle] = part.nom;
                }
                parts[f[0].Get<uint32>()].push_back(std::move(part));
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query(
            "SELECT lieu, creature, nombre, sous_zones, invocations FROM solazeroth_v3_lieux_monstres"))
        {
            do
            {
                Field* f = r->Fetch();
                monstresDuLieu[f[0].Get<uint32>()].emplace_back(f[1].Get<uint32>(), f[2].Get<uint32>());
                Compte compte{ f[0].Get<uint32>(), f[2].Get<uint32>(), {}, f[4].Get<uint8>() != 0 };
                std::string const aires = f[3].Get<std::string>();
                for (std::string_view aire : Acore::Tokenize(aires, ',', false))
                    if (Optional<uint32> n = Acore::StringTo<uint32>(aire))
                        compte.sousZones.push_back(*n);
                lieuxDuMonstre[f[1].Get<uint32>()].push_back(std::move(compte));
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT lieu, origine, renforce FROM solazeroth_v3_lieux_chefs"))
        {
            do
            {
                Field* f = r->Fetch();
                Chef& chef = chefs[f[0].Get<uint32>()];
                chef.origine = f[1].Get<uint32>();
                chef.renforce = f[2].Get<uint32>();
                lieuDuRenforce[chef.renforce] = f[0].Get<uint32>();
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT lieu, marques, cuivre, eclats, composants FROM solazeroth_v3_lieux_recompenses"))
        {
            do
            {
                Field* f = r->Fetch();
                Recompense& rec = recompenses[f[0].Get<uint32>()];
                rec.marques = f[1].Get<uint32>();
                rec.cuivre = f[2].Get<uint32>();
                rec.eclats = f[3].Get<uint32>();
                std::string const liste = f[4].Get<std::string>();
                for (std::string_view morceau : Acore::Tokenize(liste, ',', false))
                {
                    std::vector<std::string_view> paire = Acore::Tokenize(morceau, ':', false);
                    if (paire.size() != 2)
                        continue;
                    Optional<uint32> objet = Acore::StringTo<uint32>(paire[0]), nombre = Acore::StringTo<uint32>(paire[1]);
                    if (objet && nombre)
                        rec.composants.emplace_back(*objet, *nombre);
                }
            } while (r->NextRow());
        }
        // Quêtes qui visent le chef d'origine : le tuer, ou un objet de quête qu'il laisse.
        if (QueryResult r = WorldDatabase.Query(
            "SELECT c.entry, q.ID FROM creature_template c JOIN quest_template q ON c.entry IN (q.RequiredNpcOrGo1, "
            "q.RequiredNpcOrGo2, q.RequiredNpcOrGo3, q.RequiredNpcOrGo4) "
            "WHERE c.entry IN (SELECT origine FROM solazeroth_v3_lieux_chefs) "
            "UNION SELECT c.entry, q.ID FROM creature_template c "
            "JOIN creature_loot_template l ON l.Entry = c.lootid AND c.lootid > 0 AND l.Item > 0 "
            "JOIN item_template i ON i.entry = l.Item AND (l.QuestRequired = 1 OR i.class = 12) "
            "JOIN quest_template q ON l.Item IN (q.RequiredItemId1, q.RequiredItemId2, q.RequiredItemId3, "
            "q.RequiredItemId4, q.RequiredItemId5, q.RequiredItemId6) "
            "WHERE c.entry IN (SELECT origine FROM solazeroth_v3_lieux_chefs)"))
        {
            do
            {
                Field* f = r->Fetch();
                for (auto& [numero, chef] : chefs)
                    if (chef.origine == f[0].Get<uint32>())
                        chef.quetes.push_back(f[1].Get<uint32>());
            } while (r->NextRow());
        }
        // Quêtes écrites à la main (lot T0) : celles que la recherche ci-dessus ne trouve pas.
        if (QueryResult r = WorldDatabase.Query("SELECT lieu, quete FROM solazeroth_v3_lieux_chefs_quetes"))
        {
            do
            {
                Field* f = r->Fetch();
                if (auto c = chefs.find(f[0].Get<uint32>()); c != chefs.end())
                {
                    std::vector<uint32>& quetes = c->second.quetes;
                    if (std::find(quetes.begin(), quetes.end(), f[1].Get<uint32>()) == quetes.end())
                        quetes.push_back(f[1].Get<uint32>());
                }
            } while (r->NextRow());
        }
        // Place du chef : celle de l'apparition d'origine.
        for (auto const& [guid, lieu] : sObjectMgr->GetAllCreatureData())
            for (auto& [numero, chef] : chefs)
                if (lieu.id == chef.origine)
                {
                    chef.apparition = guid;
                    chef.carte = lieu.mapid;
                    chef.place.Relocate(lieu.posX, lieu.posY, lieu.posZ, lieu.orientation);
                }
        LOG_INFO("module", ">> Sol'Azeroth v3 : pourcentage de {} zone(s), {} lieux à nettoyer, {} chefs renforcés, {} lieux payés",
            parts.size(), zoneDuLieu.size(), chefs.size(), recompenses.size());
    }
};

void AddSC_solazeroth_v3_zone()
{
    new solazeroth_v3_zone_joueur();
    new solazeroth_v3_zone_monde();
}
