// v3, F5e (31/10/2026, demande de l'utilisateur : « finis totalement de programmer les objectifs de zone ») : scripts
// des annexes de Durotar A11 à A46 (document de Durotar, §4.1.2 à 4.1.6). Les données viennent de la migration 084
// (outils\annexes_durotar.py) :
// - solazeroth_v3_annexes : Insignes et éclats de chaque quête d'annexe, rangés dans la Collection quand elle est
//   rendue (avec solazeroth_v3_annexes_composants) ; chrono et médailles des défis (bronze, argent, or en secondes :
//   récompenses ×1, ×1,5, ×2 et pièce d'or la première fois) ; créature contre laquelle la potion est interdite.
//   Le chrono part au premier monstre de « depart » tué ; au-delà du bronze, la quête échoue (on l'abandonne et on la
//   reprend). L'interface (SolUI_Zone.lua) reçoit « CHRONO;quête;écoulé;bronze;argent;or » chaque seconde, puis
//   « CHRONO;- ».
// - solazeroth_v3_reliques : la relique (objet du monde) range son objet dans la Collection avec 5 Insignes et 1
//   composant du secteur ; une famille complète donne son bonus.
// - solazeroth_v3_vagues : l'épreuve de Zun'jala (A27), 10 vagues, 20 s de pause, record et 1 Insigne par vague tenue,
//   une fois par jour. Les vagues 5 et 10 valident les quêtes 910227 et 910327.
// Techniques sans SmartAI : T14 carapace des Anciens makrura (dégâts subis ÷ 2, sauf dans les 6 s qui suivent un
// étourdissement) ; T15 sang gangrené des bêtes corrompues (flaque de feu 6 s à leur mort) ; T17 orage de Féplouf
// pendant le défi A29 (une zone marquée toutes les 8 s, la foudre y tombe 2,5 s après). Leurs dégâts sont en part de
// la vie du joueur : à calibrer en jeu. Raptors des œufs (A22) et trolls des monceaux (A24) pendant leur contrat.
// Commande : .annexes carte (30 Insignes et 2 po) dévoile dans la fenêtre des objectifs la place des reliques.

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Creature.h"
#include "CreatureScript.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GameObjectScript.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellInfo.h"
#include "StringConvert.h"
#include "StringFormat.h"
#include "TemporarySummon.h"
#include "Timer.h"
#include "Tokenize.h"
#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <vector>

namespace
{
    uint32 const INSIGNE = 910140, ECLAT = 910120, POTION = 100029, DECLENCHEUR = 15214;
    uint32 const ZUNJALA = 910023, VAGUE5 = 910026, VAGUE10 = 910028, EPREUVE = 910227, EPREUVE_2 = 910327;
    uint32 const FEPLOUF = 3203, ORAGE_QUETE = 910229, ANCIEN_MAKRURA = 3141;
    uint32 const OEUFS = 3240, RAPTOR = 3122, MONCEAU = 102986, TROLL = 3207;
    uint32 const BOUCLIER_FOUDRE = 20545, ECLAIR = 403, CONSECRATION = 26573;
    uint32 const PRIX_CARTE_INSIGNES = 30, PRIX_CARTE_CUIVRE = 2 * GOLD;
    uint32 const TICK = 500;

    struct Annexe
    {
        uint32 insignes = 0, eclats = 0, bronze = 0, argent = 0, orTemps = 0, potion = 0, objetOr = 0;
        std::vector<uint32> depart;
        std::vector<std::pair<uint32, uint32>> composants;
        std::string cle;
    };
    std::unordered_map<uint32, Annexe> annexes;   // quête -> annexe

    struct Relique
    {
        uint32 objet = 0, composant = 0;
        uint8 famille = 0;
    };
    std::unordered_map<uint32, Relique> reliques;   // objet du monde -> relique
    std::vector<std::vector<std::pair<uint32, uint32>>> vagues;

    // Flaques du sang gangrené (T15), communes à tous.
    struct Flaque
    {
        uint32 carte;
        Position place;
        ObjectGuid declencheur;
        uint32 fin;
    };
    std::vector<Flaque> flaques;
    std::unordered_map<ObjectGuid, uint32> etourdis;   // Ancien makrura -> dernier étourdissement (T14)
    std::unordered_map<ObjectGuid, uint32> nidsVides;  // œufs ou monceau -> dernier appel (une fois par minute)

    struct Chrono
    {
        uint32 debut = 0, fin = 0;
    };

    struct Epreuve
    {
        bool active = false;
        uint8 vague = 0;           // vague en cours (1 à 10)
        uint32 pause = 0, debut = 0;
        Position centre;
        std::vector<ObjectGuid> monstres;
    };

    struct Joueur : DataMap::Base
    {
        std::unordered_map<uint32, std::pair<uint8, uint32>> medailles;   // quête -> (médaille, meilleur temps)
        std::unordered_map<uint32, Chrono> chronos;
        bool carte = false;
        uint8 recordVague = 0;
        uint32 recordTemps = 0, jour = 0;
        uint32 attente = 0, orage = 0, envoiChrono = 0;
        Position foudre;
        uint32 foudreA = 0;
        Epreuve epreuve;
    };

    Joueur* JoueurDe(Player* player)
    {
        return player->CustomData.GetDefault<Joueur>("solazeroth_v3_annexes");
    }

    void Dire(Player* player, std::string const& texte)
    {
        ChatHandler(player->GetSession()).SendSysMessage(texte);
    }

    void Alerte(Player* player, std::string const& texte)
    {
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", "ALERTE;" + texte);
    }

    void SauverJoueur(Player* player, Joueur* j)
    {
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_annexes_joueur (guid, carte, vague, temps, jour) "
            "VALUES ({}, {}, {}, {}, {})", player->GetGUID().GetCounter(), j->carte ? 1 : 0, j->recordVague,
            j->recordTemps, j->jour);
    }

    uint32 Aujourdhui()
    {
        return uint32(time(nullptr) / DAY);
    }

    std::string Duree(uint32 ms)
    {
        uint32 s = ms / IN_MILLISECONDS;
        return Acore::StringFormat("{}:{:02}", s / 60, s % 60);
    }

    // ------------------------------------------------------------------ chrono, médailles, sans potion

    uint8 Medaille(Annexe const& a, uint32 ms)
    {
        uint32 s = ms / IN_MILLISECONDS;
        return s <= a.orTemps ? 3 : s <= a.argent ? 2 : s <= a.bronze ? 1 : 0;
    }

    void Recompenser(Player* player, uint32 quete, Quest const* quest)
    {
        Annexe const& a = annexes[quete];
        Joueur* j = JoueurDe(player);
        uint8 medaille = 0;
        uint32 temps = 0;
        if (!a.depart.empty())
        {
            auto c = j->chronos.find(quete);
            if (c != j->chronos.end())
            {
                if (!c->second.fin)
                    c->second.fin = getMSTime();
                temps = c->second.fin - c->second.debut;
                medaille = Medaille(a, temps);
            }
            j->chronos.erase(quete);
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", "CHRONO;-");
        }
        float facteur = medaille == 3 ? 2.0f : medaille == 2 ? 1.5f : 1.0f;
        if (a.insignes)
            SolAzeroth::AjouterACollection(player, INSIGNE, uint32(a.insignes * facteur));
        if (a.eclats)
            SolAzeroth::AjouterACollection(player, ECLAT, uint32(a.eclats * facteur));
        for (auto const& [objet, nombre] : a.composants)
            SolAzeroth::AjouterACollection(player, objet, uint32(nombre * facteur + 0.5f));
        if (facteur > 1.0f && quest->GetRewOrReqMoney() > 0)
            player->ModifyMoney(int32(quest->GetRewOrReqMoney() * (facteur - 1.0f)));
        std::string texte = Acore::StringFormat("{} : {} Insignes et {} éclats rangés dans la Collection.", a.cle,
            uint32(a.insignes * facteur), uint32(a.eclats * facteur));
        if (!a.depart.empty())
        {
            static char const* const NOMS[] = { "sans médaille", "bronze", "argent", "or" };
            texte += Acore::StringFormat(" Temps {} : médaille {}.", Duree(temps), NOMS[medaille]);
            auto& meilleure = j->medailles[quete];
            if (medaille == 3 && meilleure.first < 3 && a.objetOr)
                player->AddItem(a.objetOr, 1);
            if (medaille > meilleure.first || (medaille == meilleure.first && temps < meilleure.second))
            {
                meilleure = { medaille, temps };
                CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_annexes_medailles (guid, quete, medaille, temps) "
                    "VALUES ({}, {}, {}, {})", player->GetGUID().GetCounter(), quete, medaille, temps);
            }
        }
        Dire(player, texte);
    }

    void SuivreChronos(Player* player, Joueur* j)
    {
        uint32 maintenant = getMSTime();
        for (auto it = j->chronos.begin(); it != j->chronos.end();)
        {
            Annexe const& a = annexes[it->first];
            Chrono& c = it->second;
            QuestStatus statut = player->GetQuestStatus(it->first);
            if (statut != QUEST_STATUS_INCOMPLETE && statut != QUEST_STATUS_COMPLETE)
            {
                it = j->chronos.erase(it);
                SolAzeroth::EnvoyerAddon(player, "SOLZONE", "CHRONO;-");
                continue;
            }
            if (!c.fin && statut == QUEST_STATUS_COMPLETE)
                c.fin = maintenant;
            uint32 ecoule = getMSTimeDiff(c.debut, c.fin ? c.fin : maintenant);
            if (!c.fin && ecoule > a.bronze * IN_MILLISECONDS)
            {
                player->FailQuest(it->first);
                Alerte(player, a.cle + " : temps écoulé. Abandonne la quête et reprends-la pour retenter.");
                it = j->chronos.erase(it);
                SolAzeroth::EnvoyerAddon(player, "SOLZONE", "CHRONO;-");
                continue;
            }
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", Acore::StringFormat("CHRONO;{};{};{};{};{};{}", it->first,
                ecoule / IN_MILLISECONDS, a.bronze, a.argent, a.orTemps, c.fin ? 1 : 0));
            ++it;
        }
    }

    // ------------------------------------------------------------------ flaques et orage

    void Brulure(Unit* source, Player* player, float part, SpellSchoolMask ecole)
    {
        uint32 degats = uint32(player->GetMaxHealth() * part);
        if (degats && player->IsAlive())
            Unit::DealDamage(source, player, degats, nullptr, SPELL_DIRECT_DAMAGE, ecole, nullptr, false);
    }

    void Flaques(Player* player)
    {
        uint32 maintenant = getMSTime();
        for (auto it = flaques.begin(); it != flaques.end();)
        {
            if (maintenant >= it->fin)
            {
                it = flaques.erase(it);
                continue;
            }
            if (player->GetMapId() == it->carte && player->GetExactDist(it->place) < 4.0f)
                if (Creature* d = ObjectAccessor::GetCreature(*player, it->declencheur))
                    Brulure(d, player, 0.03f, SPELL_SCHOOL_MASK_FIRE);   // 6 % par seconde (tous les 500 ms : 3 %)
            ++it;
        }
    }

    void Orage(Player* player, Joueur* j)
    {
        if (player->GetQuestStatus(ORAGE_QUETE) != QUEST_STATUS_INCOMPLETE || !player->IsInCombat())
        {
            j->orage = j->foudreA = 0;
            return;
        }
        Creature* feplouf = player->FindNearestCreature(FEPLOUF, 40.0f, true);
        if (!feplouf || !feplouf->IsInCombat())
            return;
        uint32 maintenant = getMSTime();
        if (j->foudreA && maintenant >= j->foudreA)
        {
            j->foudreA = 0;
            if (player->GetExactDist(j->foudre) < 4.0f)
            {
                feplouf->CastSpell(player, ECLAIR, true);
                Brulure(feplouf, player, 0.2f, SPELL_SCHOOL_MASK_NATURE);
            }
        }
        if (!j->orage || maintenant >= j->orage)
        {
            j->orage = maintenant + 8 * IN_MILLISECONDS;
            j->foudre = player->GetPosition();
            j->foudreA = maintenant + 2500;
            if (TempSummon* marque = player->SummonCreature(DECLENCHEUR, j->foudre, TEMPSUMMON_TIMED_DESPAWN, 3000))
                marque->AddAura(BOUCLIER_FOUDRE, marque);
        }
    }

    // ------------------------------------------------------------------ épreuve de Zun'jala (A27)

    void FinirEpreuve(Player* player, Joueur* j, bool reussie)
    {
        Epreuve& e = j->epreuve;
        for (ObjectGuid const& g : e.monstres)
            if (Creature* c = ObjectAccessor::GetCreature(*player, g))
                c->DespawnOrUnsummon();
        uint8 tenues = reussie ? 10 : (e.vague ? e.vague - 1 : 0);
        uint32 temps = getMSTimeDiff(e.debut, getMSTime());
        e = Epreuve();
        std::string texte = Acore::StringFormat("Épreuve terminée : {} vague(s) tenue(s) en {}.", tenues, Duree(temps));
        if (tenues > j->recordVague || (tenues == j->recordVague && tenues && temps < j->recordTemps))
        {
            j->recordVague = tenues;
            j->recordTemps = temps;
            texte += " Nouveau record !";
        }
        if (tenues && j->jour != Aujourdhui())
        {
            j->jour = Aujourdhui();
            SolAzeroth::AjouterACollection(player, INSIGNE, tenues);
            texte += Acore::StringFormat(" {} Insigne(s) du jour.", tenues);
        }
        SauverJoueur(player, j);
        Alerte(player, texte);
    }

    void LancerVague(Player* player, Joueur* j)
    {
        Epreuve& e = j->epreuve;
        e.monstres.clear();
        uint32 total = 0;
        for (auto const& [entree, nombre] : vagues[e.vague - 1])
            total += nombre;
        uint32 n = 0;
        for (auto const& [entree, nombre] : vagues[e.vague - 1])
            for (uint32 i = 0; i < nombre; ++i, ++n)
            {
                float angle = 2.0f * float(M_PI) * n / total;
                float x = e.centre.GetPositionX() + 16.0f * std::cos(angle);
                float y = e.centre.GetPositionY() + 16.0f * std::sin(angle);
                float z = player->GetMap()->GetHeight(x, y, e.centre.GetPositionZ() + 10.0f);
                if (z < e.centre.GetPositionZ() - 20.0f)
                    z = e.centre.GetPositionZ();
                if (TempSummon* m = player->SummonCreature(entree, x, y, z, angle + float(M_PI),
                    TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, 5 * MINUTE * IN_MILLISECONDS))
                {
                    m->SetFaction(14);   // hostile à tous, quel que soit le monstre d'origine
                    m->AI()->AttackStart(player);
                    e.monstres.push_back(m->GetGUID());
                }
            }
        Alerte(player, Acore::StringFormat("Épreuve des esprits : vague {} sur 10.", e.vague));
    }

    void SuivreEpreuve(Player* player, Joueur* j)
    {
        Epreuve& e = j->epreuve;
        if (!e.active)
            return;
        if (!player->IsAlive() || player->GetMapId() != 1 || player->GetExactDist(e.centre) > 60.0f)
        {
            FinirEpreuve(player, j, false);
            return;
        }
        if (e.pause)
        {
            e.pause = e.pause > TICK ? e.pause - TICK : 0;
            if (!e.pause)
                LancerVague(player, j);
            return;
        }
        for (ObjectGuid const& g : e.monstres)
            if (Creature* c = ObjectAccessor::GetCreature(*player, g); c && c->IsAlive())
                return;
        if (e.vague == 5)
            player->KilledMonsterCredit(VAGUE5);
        if (e.vague == 10)
        {
            player->KilledMonsterCredit(VAGUE10);
            FinirEpreuve(player, j, true);
            return;
        }
        Alerte(player, Acore::StringFormat("Vague {} tenue. La suivante dans 20 secondes.", e.vague));
        ++e.vague;
        e.pause = 20 * IN_MILLISECONDS;
    }
}

unsigned char SolAzeroth::MedailleDefi(Player* player, unsigned int quete)
{
    Joueur* j = JoueurDe(player);
    auto it = j->medailles.find(quete);
    return it == j->medailles.end() ? 0 : it->second.first;
}

bool SolAzeroth::CarteReliques(Player* player)
{
    return JoueurDe(player)->carte;
}

class solazeroth_v3_annexes_joueur : public PlayerScript
{
public:
    solazeroth_v3_annexes_joueur() : PlayerScript("solazeroth_v3_annexes_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CREATURE_KILL_CREDIT,
        PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST, PLAYERHOOK_ON_QUEST_ABANDON, PLAYERHOOK_ON_SPELL_CAST,
        PLAYERHOOK_ON_PLAYER_JUST_DIED, PLAYERHOOK_ON_DELETE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Joueur* j = JoueurDe(player);
        uint32 guid = player->GetGUID().GetCounter();
        if (QueryResult r = CharacterDatabase.Query("SELECT quete, medaille, temps FROM solazeroth_v3_annexes_medailles "
            "WHERE guid = {}", guid))
        {
            do
                j->medailles[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint8>(), (*r)[2].Get<uint32>() };
            while (r->NextRow());
        }
        if (QueryResult r = CharacterDatabase.Query("SELECT carte, vague, temps, jour FROM solazeroth_v3_annexes_joueur "
            "WHERE guid = {}", guid))
        {
            j->carte = (*r)[0].Get<uint8>();
            j->recordVague = (*r)[1].Get<uint8>();
            j->recordTemps = (*r)[2].Get<uint32>();
            j->jour = (*r)[3].Get<uint32>();
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        Joueur* j = JoueurDe(player);
        if (j->epreuve.active)
            FinirEpreuve(player, j, false);
    }

    void OnPlayerJustDied(Player* player) override
    {
        Joueur* j = JoueurDe(player);
        if (j->epreuve.active)
            FinirEpreuve(player, j, false);
    }

    void OnPlayerCreatureKillCredit(Player* player, Creature* creature) override
    {
        uint32 entree = creature->GetEntry();
        // T15 : le sang gangrené des bêtes corrompues brûle 6 s là où elles tombent.
        if (entree >= 3225 && entree <= 3228)
            if (TempSummon* d = creature->SummonCreature(DECLENCHEUR, creature->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, 6000))
            {
                d->CastSpell(d, CONSECRATION, true);
                flaques.push_back({ creature->GetMapId(), creature->GetPosition(), d->GetGUID(), getMSTime() + 6000 });
            }
        Joueur* j = JoueurDe(player);
        for (auto const& [quete, a] : annexes)
        {
            if (a.depart.empty() || j->chronos.count(quete) || player->GetQuestStatus(quete) != QUEST_STATUS_INCOMPLETE)
                continue;
            if (std::find(a.depart.begin(), a.depart.end(), entree) != a.depart.end())
            {
                j->chronos[quete].debut = getMSTime();
                Alerte(player, a.cle + " : le chrono est lancé !");
            }
        }
    }

    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (annexes.count(quest->GetQuestId()))
            Recompenser(player, quest->GetQuestId(), quest);
    }

    void OnPlayerQuestAbandon(Player* player, uint32 quete) override
    {
        Joueur* j = JoueurDe(player);
        if (j->chronos.erase(quete))
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", "CHRONO;-");
    }

    // Défis sans potion (A28, A29) : boire pendant le combat contre la cible fait échouer la quête.
    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        if (spell->GetSpellInfo()->Id != POTION)
            return;
        for (auto const& [quete, a] : annexes)
        {
            if (!a.potion || player->GetQuestStatus(quete) != QUEST_STATUS_INCOMPLETE)
                continue;
            if (Creature* cible = player->FindNearestCreature(a.potion, 60.0f, true); cible && cible->IsInCombat())
            {
                player->FailQuest(quete);
                Alerte(player, a.cle + " : potion bue, défi échoué. Abandonne la quête et reprends-la pour retenter.");
            }
        }
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Joueur* j = JoueurDe(player);
        if (j->attente > diff)
        {
            j->attente -= diff;
            return;
        }
        j->attente = TICK;
        if (!player->IsInWorld())
            return;
        if (!flaques.empty())
            Flaques(player);
        Orage(player, j);
        SuivreEpreuve(player, j);
        if (!j->chronos.empty() && (j->envoiChrono += TICK) >= IN_MILLISECONDS)
        {
            j->envoiChrono = 0;
            SuivreChronos(player, j);
        }
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_annexes_medailles WHERE guid = {}", guid.GetCounter());
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_annexes_joueur WHERE guid = {}", guid.GetCounter());
    }
};

// T14 : la carapace des Anciens makrura divise les dégâts par deux, sauf dans les 6 s qui suivent un étourdissement.
class solazeroth_v3_annexes_carapace : public UnitScript
{
public:
    solazeroth_v3_annexes_carapace() : UnitScript("solazeroth_v3_annexes_carapace", true, { UNITHOOK_ON_DAMAGE }) { }

    void OnDamage(Unit* /*attacker*/, Unit* victim, uint32& damage) override
    {
        if (!victim || victim->GetEntry() != ANCIEN_MAKRURA || !victim->IsCreature())
            return;
        uint32 maintenant = getMSTime();
        if (victim->HasUnitState(UNIT_STATE_STUNNED))
        {
            etourdis[victim->GetGUID()] = maintenant;
            return;
        }
        auto it = etourdis.find(victim->GetGUID());
        if (it == etourdis.end() || getMSTimeDiff(it->second, maintenant) > 6 * IN_MILLISECONDS)
            damage /= 2;
    }
};

// Reliques (A31-A46).
class go_solazeroth_v3_relique : public GameObjectScript
{
public:
    go_solazeroth_v3_relique() : GameObjectScript("go_solazeroth_v3_relique") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        auto it = reliques.find(go->GetEntry());
        if (it == reliques.end())
            return true;
        Relique const& r = it->second;
        if (SolAzeroth::NombreEnCollection(player, r.objet))
        {
            Dire(player, "Tu as déjà trouvé cette relique.");
            return true;
        }
        SolAzeroth::AjouterACollection(player, r.objet, 1);
        SolAzeroth::AjouterACollection(player, INSIGNE, 5);
        SolAzeroth::AjouterACollection(player, r.composant, 1);
        uint32 trouvees = 0, total = 0;
        for (auto const& [objetMonde, autre] : reliques)
            if (autre.famille == r.famille)
            {
                ++total;
                trouvees += SolAzeroth::NombreEnCollection(player, autre.objet) ? 1 : 0;
            }
        ItemTemplate const* objet = sObjectMgr->GetItemTemplate(r.objet);
        Alerte(player, Acore::StringFormat("Relique trouvée : {} ({} / {} de la famille).",
            objet ? objet->Name1 : "relique", trouvees, total));
        if (trouvees == total)
        {
            // Bonus de famille : Lame ardente, bouclier ; Kul Tiras, 3 po et 2 Œil ténébreux ; Sombrelances, bottes.
            if (r.famille == 0)
                player->AddItem(910131, 1);
            else if (r.famille == 1)
            {
                player->ModifyMoney(3 * GOLD);
                SolAzeroth::AjouterACollection(player, 1210, 2);
            }
            else
                player->AddItem(910132, 1);
            Alerte(player, "Famille de reliques complète : bonus reçu !");
        }
        return true;
    }
};

// Raptors des œufs (A22) et trolls des monceaux (A24), seulement pendant leur contrat.
class go_solazeroth_v3_appel : public GameObjectScript
{
public:
    go_solazeroth_v3_appel(char const* nom, uint32 creature, uint8 nombre, uint32 q1, uint32 q2)
        : GameObjectScript(nom), _creature(creature), _nombre(nombre), _q1(q1), _q2(q2) { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (player->GetQuestStatus(_q1) != QUEST_STATUS_INCOMPLETE && player->GetQuestStatus(_q2) != QUEST_STATUS_INCOMPLETE)
            return false;
        uint32 maintenant = getMSTime();
        auto it = nidsVides.find(go->GetGUID());
        if (it != nidsVides.end() && getMSTimeDiff(it->second, maintenant) < MINUTE * IN_MILLISECONDS)
            return false;
        nidsVides[go->GetGUID()] = maintenant;
        for (uint8 i = 0; i < _nombre; ++i)
        {
            Position p = go->GetPosition();
            p.RelocateOffset({ 6.0f * std::cos(i * 3.0f), 6.0f * std::sin(i * 3.0f), 0.0f, 0.0f });
            p.m_positionZ = go->GetMap()->GetHeight(p.GetPositionX(), p.GetPositionY(), go->GetPositionZ() + 5.0f);
            if (TempSummon* c = go->SummonCreature(_creature, p, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, 30000))
                c->AI()->AttackStart(player);
        }
        return false;
    }

private:
    uint32 _creature;
    uint8 _nombre;
    uint32 _q1, _q2;
};

// Zun'jala, gardienne de l'épreuve (A27).
class npc_solazeroth_v3_zunjala : public CreatureScript
{
public:
    npc_solazeroth_v3_zunjala() : CreatureScript("npc_solazeroth_v3_zunjala") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        player->PrepareQuestMenu(creature->GetGUID());
        Joueur* j = JoueurDe(player);
        bool permise = player->GetQuestStatus(EPREUVE) == QUEST_STATUS_INCOMPLETE ||
            player->GetQuestStatus(EPREUVE_2) == QUEST_STATUS_INCOMPLETE || player->GetQuestRewardStatus(EPREUVE);
        if (permise && !j->epreuve.active)
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, j->recordVague ? Acore::StringFormat(
                "Commencer l'épreuve (record : vague {} en {}).", j->recordVague, Duree(j->recordTemps)) :
                std::string("Commencer l'épreuve."), GOSSIP_SENDER_MAIN, 1);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        Joueur* j = JoueurDe(player);
        if (action != 1 || j->epreuve.active || vagues.size() < 10)
            return true;
        Epreuve& e = j->epreuve;
        e.active = true;
        e.vague = 1;
        e.debut = getMSTime();
        e.centre = creature->GetPosition();
        e.pause = 5 * IN_MILLISECONDS;
        Alerte(player, "L'épreuve commence dans 5 secondes. Ne t'éloigne pas du rocher.");
        return true;
    }
};

using namespace Acore::ChatCommands;

class solazeroth_v3_annexes_commandes : public CommandScript
{
public:
    solazeroth_v3_annexes_commandes() : CommandScript("solazeroth_v3_annexes_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sous =
        {
            { "carte", HandleCarte, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "annexes", sous },
        };
        return commandes;
    }

    // .annexes carte : dévoile la place des reliques dans la fenêtre des objectifs (30 Insignes et 2 po).
    static bool HandleCarte(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Joueur* j = JoueurDe(player);
        if (j->carte)
        {
            handler->SendSysMessage("Tu as déjà la carte des reliques.");
            return true;
        }
        if (SolAzeroth::NombreEnCollection(player, INSIGNE) < PRIX_CARTE_INSIGNES || player->GetMoney() < PRIX_CARTE_CUIVRE)
        {
            handler->SendErrorMessage("La carte des reliques coûte {} Insignes et 2 po.", PRIX_CARTE_INSIGNES);
            return false;
        }
        SolAzeroth::RetirerDeCollection(player, INSIGNE, PRIX_CARTE_INSIGNES);
        player->ModifyMoney(-int32(PRIX_CARTE_CUIVRE));
        j->carte = true;
        SauverJoueur(player, j);
        handler->SendSysMessage("Carte des reliques achetée : leur place est dans la fenêtre des objectifs de zone.");
        return true;
    }
};

class solazeroth_v3_annexes_monde : public WorldScript
{
public:
    solazeroth_v3_annexes_monde() : WorldScript("solazeroth_v3_annexes_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        annexes.clear();
        reliques.clear();
        vagues.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT quete, cle, insignes, eclats, bronze, argent, `or`, depart, potion, "
            "objet_or FROM solazeroth_v3_annexes"))
        {
            do
            {
                Field* f = r->Fetch();
                Annexe& a = annexes[f[0].Get<uint32>()];
                a.cle = f[1].Get<std::string>();
                a.insignes = f[2].Get<uint32>();
                a.eclats = f[3].Get<uint32>();
                a.bronze = f[4].Get<uint32>();
                a.argent = f[5].Get<uint32>();
                a.orTemps = f[6].Get<uint32>();
                std::string depart = f[7].Get<std::string>();
                for (std::string_view morceau : Acore::Tokenize(depart, ',', false))
                    if (Optional<uint32> e = Acore::StringTo<uint32>(morceau))
                        a.depart.push_back(*e);
                a.potion = f[8].Get<uint32>();
                a.objetOr = f[9].Get<uint32>();
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT quete, objet, nombre FROM solazeroth_v3_annexes_composants"))
        {
            do
                annexes[(*r)[0].Get<uint32>()].composants.emplace_back((*r)[1].Get<uint32>(), (*r)[2].Get<uint32>());
            while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT objet_monde, objet, famille, composant FROM solazeroth_v3_reliques"))
        {
            do
                reliques[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint32>(), (*r)[3].Get<uint32>(), (*r)[2].Get<uint8>() };
            while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT vague, creature, nombre FROM solazeroth_v3_vagues ORDER BY vague"))
        {
            do
            {
                uint8 v = (*r)[0].Get<uint8>();
                if (vagues.size() < v)
                    vagues.resize(v);
                vagues[v - 1].emplace_back((*r)[1].Get<uint32>(), (*r)[2].Get<uint8>());
            } while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} annexes à quête, {} reliques, {} vagues d'épreuve",
            annexes.size(), reliques.size(), vagues.size());
    }
};

void AddSC_solazeroth_v3_annexes()
{
    new solazeroth_v3_annexes_joueur();
    new solazeroth_v3_annexes_carapace();
    new go_solazeroth_v3_relique();
    new go_solazeroth_v3_appel("go_solazeroth_v3_oeufs", RAPTOR, 2, 910222, 910522);
    new go_solazeroth_v3_appel("go_solazeroth_v3_monceau", TROLL, 1, 910224, 910524);
    new npc_solazeroth_v3_zunjala();
    new solazeroth_v3_annexes_commandes();
    new solazeroth_v3_annexes_monde();
}
