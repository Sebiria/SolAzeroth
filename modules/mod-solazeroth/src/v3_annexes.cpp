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
//   composant du secteur ; une famille complète donne son bonus. La relique trouvée disparaît (7 jours) ; elle revient
//   quand passe à moins de 150 m un personnage qui ne l'a pas trouvée (serveur solo, MontrerReliques).
// - solazeroth_v3_vagues : l'épreuve de Zun'jala (A27), 10 vagues, 20 s de pause, record et 1 Insigne par vague tenue,
//   une fois par jour. Les vagues 5 et 10 valident les quêtes 910227 et 910327.
// Techniques sans SmartAI : T14 carapace des Anciens makrura (dégâts subis ÷ 2, sauf dans les 6 s qui suivent un
// étourdissement) ; T15 sang gangrené des bêtes corrompues (flaque de feu 6 s à leur mort) ; T17 orage de Féplouf
// pendant le défi A29 (une zone marquée toutes les 8 s, la foudre y tombe 2,5 s après). Leurs dégâts sont en part de
// la vie du joueur : à calibrer en jeu. Raptors des œufs (A22) et trolls des monceaux (A24) pendant leur contrat.
// Commande : .annexes carte (30 Insignes et 2 po) dévoile dans la fenêtre des objectifs la place des reliques ; lot 6b
// (02/11/2026, choix de l'utilisateur) : seulement après 8 reliques trouvées.
//
// Lot T4 des Tarides (03/11/2026, brouillon des Tarides §4.1.6) : plus rien de Durotar n'est écrit en dur. Migration
// 143 (outils\annexes_durotar.py generales), les lignes de Durotar ; migration 144, celles des Tarides.
// - solazeroth_v3_epreuves (et solazeroth_v3_vagues, colonnes epreuve et puissance) : une épreuve par gardien (le PNJ
//   au script npc_solazeroth_v3_zunjala), ses quêtes, ses crédits de mi-parcours et de fin, son nombre de vagues ; la
//   puissance de chaque monstre de vague est fixée à l'invocation (ImposerPuissance, courbe comprise). Record et
//   Marque du jour par épreuve (acore_characters.solazeroth_v3_epreuves_joueur).
// - solazeroth_v3_renforts : les objets du monde qui font accourir des monstres pendant leurs quêtes (œufs, monceaux,
//   seaux, valves, nids, antres), à leur puissance.
// - solazeroth_v3_reliques_familles : le bonus de chaque famille (objet par classe, or, composant).
// - solazeroth_v3_reliques_cartes : la carte des reliques de chaque zone, son prix et son seuil ; achetée par zone
//   (acore_characters.solazeroth_v3_reliques_cartes_joueur).
// - solazeroth_v3_techniques : techniques sans SmartAI, par créature et par genre (1 carapace, 2 flaque à la mort,
//   3 zone marquée, 4 frères d'armes, 5 renvoi de dégâts, 6 rage par mort voisine, 7 mur répété, 8 sable grouillant).

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
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringConvert.h"
#include "StringFormat.h"
#include "TemporarySummon.h"
#include "Timer.h"
#include "Tokenize.h"
#include <algorithm>
#include <cmath>
#include <set>
#include <unordered_map>
#include <vector>

namespace
{
    uint32 const ECLAT = 910120, POTION = 100029, DECLENCHEUR = 15214;
    uint32 const TICK = 500;

    std::vector<uint32> Liste(std::string const& texte)
    {
        std::vector<uint32> liste;
        for (std::string_view morceau : Acore::Tokenize(texte, ',', false))
            if (Optional<uint32> e = Acore::StringTo<uint32>(morceau))
                liste.push_back(*e);
        return liste;
    }

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
        uint32 objet = 0, composant = 0, zone = 0;
        uint8 famille = 0;
    };
    std::unordered_map<uint32, Relique> reliques;   // objet du monde -> relique
    // Relique trouvée : elle disparaît (01/11/2026). Le jeu ne cache pas un objet du monde pour un seul joueur ; le
    // serveur étant solo, elle disparaît pour tous, puis revient quand passe un personnage qui ne l'a pas trouvée.
    std::vector<std::pair<uint32, ObjectGuid::LowType>> placesReliques;   // (carte, guid de l'apparition)
    Seconds const RELIQUE_ABSENTE = Days(7);

    // Lot T4 : bonus de famille et carte des reliques, par zone.
    struct Famille
    {
        uint32 objet = 0, cuivre = 0, composant = 0, nombre = 0;
    };
    std::unordered_map<uint8, Famille> familles;
    struct Carte
    {
        uint32 marques = 0, cuivre = 0, seuil = 0;
    };
    std::unordered_map<uint32, Carte> cartes;   // zone -> carte

    // Lot T4 : épreuves de vagues.
    struct Vague
    {
        std::vector<std::pair<uint32, uint32>> monstres;   // (créature, nombre)
        uint8 puissance = 0;
    };
    struct DefEpreuve
    {
        uint32 pnj = 0, quete = 0, quete2 = 0, creditMi = 0, creditFin = 0;
        uint8 vagueMi = 0;
        std::string nom, consigne;
        std::vector<Vague> vagues;
    };
    std::unordered_map<uint32, DefEpreuve> epreuves;   // épreuve -> définition
    std::unordered_map<uint32, uint32> epreuveDuPnj;    // PNJ -> épreuve

    // Lot T4 : renforts des objets du monde.
    struct Renfort
    {
        uint32 creature = 0;
        uint8 nombre = 0, puissance = 0;
        std::vector<uint32> quetes;
    };
    std::unordered_map<uint32, Renfort> renforts;   // objet du monde -> renfort

    // Lot T4 : techniques sans SmartAI.
    enum GenreTechnique : uint8
    {
        CARAPACE = 1, FLAQUE = 2, ZONE_MARQUEE = 3, FRERES = 4, RENVOI = 5, RAGE_VOISINE = 6, MUR = 7, SABLE = 8
    };
    struct Technique
    {
        uint32 creature = 0, quete = 0, a = 0, b = 0, c = 0, sort = 0, creature2 = 0;
    };
    std::unordered_map<uint8, std::unordered_map<uint32, Technique>> techniques;   // genre -> créature -> technique

    Technique const* TechniqueDe(uint32 entree, uint8 genre)
    {
        auto g = techniques.find(genre);
        if (g == techniques.end())
            return nullptr;
        auto t = g->second.find(entree);
        return t == g->second.end() ? nullptr : &t->second;
    }

    // Flaques du sang gangrené (T15), communes à tous.
    struct Flaque
    {
        uint32 carte;
        Position place;
        ObjectGuid declencheur;
        uint32 fin;
        float part;
    };
    std::vector<Flaque> flaques;
    std::unordered_map<ObjectGuid, uint32> etourdis;   // carapace -> dernier étourdissement (T14)
    std::unordered_map<ObjectGuid, uint32> nidsVides;  // objet du monde -> dernier appel (une fois par minute)
    std::unordered_map<ObjectGuid, std::pair<uint8, uint32>> rages;   // rage voisine -> (cumul, dernier gain)
    std::unordered_map<ObjectGuid, uint32> murs;       // mur répété -> temps passé en combat

    struct Chrono
    {
        uint32 debut = 0, fin = 0;
    };

    struct Epreuve
    {
        bool active = false;
        uint32 id = 0;
        uint8 vague = 0;           // vague en cours (1 à 10)
        uint32 pause = 0, debut = 0, carte = 0;
        Position centre;
        std::vector<ObjectGuid> monstres;
    };

    struct Record
    {
        uint8 vague = 0;
        uint32 temps = 0, jour = 0;
    };

    struct Joueur : DataMap::Base
    {
        std::unordered_map<uint32, std::pair<uint8, uint32>> medailles;   // quête -> (médaille, meilleur temps)
        std::unordered_map<uint32, uint32> payes;                         // défi répétable -> jour du plein tarif
        std::unordered_map<uint32, Chrono> chronos;
        std::set<uint32> cartes;                                          // zones dont la carte est achetée
        std::unordered_map<uint32, Record> records;                       // épreuve -> record
        uint32 attente = 0, orage = 0, envoiChrono = 0, reliques = 0, sable = 0;
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

    void SauverRecord(Player* player, uint32 epreuve, Record const& r)
    {
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_epreuves_joueur (guid, epreuve, vague, temps, jour) "
            "VALUES ({}, {}, {}, {}, {})", player->GetGUID().GetCounter(), epreuve, r.vague, r.temps, r.jour);
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

    std::string Prix(uint32 cuivre)
    {
        uint32 po = cuivre / GOLD, pa = (cuivre % GOLD) / SILVER;
        return po && pa ? Acore::StringFormat("{} po {} pa", po, pa) : po ? Acore::StringFormat("{} po", po)
            : Acore::StringFormat("{} pa", pa);
    }

    // ------------------------------------------------------------------ chrono, médailles, sans potion

    // Passif Défi tenu (v3_passifs.cpp) : 5 s de plus à chaque épreuve contre la montre.
    uint32 DefiTenu(Player* player) { return SolAzeroth::PassifActif(player, SolAzeroth::DEFI_TENU) ? 5000 : 0; }

    // Passif Chasseur de primes : + 20 % de Marques. Les annexes donnaient des Insignes de Durotar ; depuis le
    // 01/11/2026 (demande de l'utilisateur : une seule monnaie), des Marques du voyageur (colonne insignes gardée).
    uint32 GainMarques(Player* player, uint32 nombre)
    {
        return SolAzeroth::PassifActif(player, SolAzeroth::CHASSEUR_DE_PRIMES) ? uint32(nombre * 1.2f + 0.5f) : nombre;
    }

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
                medaille = Medaille(a, temps - std::min(temps, DefiTenu(player)));
            }
            j->chronos.erase(quete);
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", "CHRONO;-");
        }
        // Lot 4a (02/11/2026, C4 du consensus, choix de l'utilisateur) : un défi répétable paie plein tarif une fois par
        // jour. Ensuite, le chrono et le record seulement, et 1 Marque ; l'or de la quête est repris.
        bool reduit = quest->IsRepeatable() && j->payes[quete] == Aujourdhui();
        if (quest->IsRepeatable() && !reduit)
        {
            j->payes[quete] = Aujourdhui();
            CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_annexes_jour (guid, quete, jour) VALUES ({}, {}, {})",
                player->GetGUID().GetCounter(), quete, Aujourdhui());
            SolAzeroth::ProgresSemaine(player, SolAzeroth::SEMAINE_DEFIS);
        }
        float facteur = medaille == 3 ? 2.0f : medaille == 2 ? 1.5f : 1.0f;
        std::string texte;
        if (reduit)
        {
            if (quest->GetRewOrReqMoney() > 0)
                player->ModifyMoney(-std::min<int32>(int32(player->GetMoney()), quest->GetRewOrReqMoney()));
            SolAzeroth::DonnerMarques(player, 1, a.cle);
            texte = Acore::StringFormat("{} : déjà payé aujourd'hui, 1 Marque seulement (plein tarif demain).", a.cle);
        }
        else
        {
            SolAzeroth::DonnerMarques(player, GainMarques(player, uint32(a.insignes * facteur)), a.cle);
            if (a.eclats)
                SolAzeroth::AjouterACollection(player, ECLAT, uint32(a.eclats * facteur));
            for (auto const& [objet, nombre] : a.composants)
                SolAzeroth::AjouterACollection(player, objet, uint32(nombre * facteur + 0.5f));
            if (facteur > 1.0f && quest->GetRewOrReqMoney() > 0)
                player->ModifyMoney(int32(quest->GetRewOrReqMoney() * (facteur - 1.0f)));
            texte = Acore::StringFormat("{} : {} éclats rangés dans la Collection.", a.cle, uint32(a.eclats * facteur));
        }
        if (!a.depart.empty())
        {
            static char const* const NOMS[] = { "sans médaille", "bronze", "argent", "or" };
            texte += Acore::StringFormat(" Temps {} : médaille {}.", Duree(temps), NOMS[medaille]);
            auto& meilleure = j->medailles[quete];
            if (medaille == 3 && meilleure.first < 3 && a.objetOr)
                player->AddItem(SolAzeroth::VersionDe(player, a.objetOr), 1);
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
            uint32 bonus = DefiTenu(player) / IN_MILLISECONDS;
            if (!c.fin && ecoule > (a.bronze + bonus) * IN_MILLISECONDS)
            {
                player->FailQuest(it->first);
                Alerte(player, a.cle + " : temps écoulé. Abandonne la quête et reprends-la pour retenter.");
                it = j->chronos.erase(it);
                SolAzeroth::EnvoyerAddon(player, "SOLZONE", "CHRONO;-");
                continue;
            }
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", Acore::StringFormat("CHRONO;{};{};{};{};{};{}", it->first,
                ecoule / IN_MILLISECONDS, a.bronze + bonus, a.argent + bonus, a.orTemps + bonus, c.fin ? 1 : 0));
            ++it;
        }
    }

    // ------------------------------------------------------------------ flaques, zones marquées, sable

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
                    Brulure(d, player, it->part, SPELL_SCHOOL_MASK_FIRE);   // Durotar : 3 % tous les 500 ms
            ++it;
        }
    }

    // Zone marquée (T17 de Durotar, M4 des Tarides) : pendant le combat contre la créature (et la quête, si elle est
    // donnée), une zone est marquée sous le joueur toutes les a ms ; b ms après, elle frappe (c dix-millièmes de sa
    // vie, et le sort s'il y en a un). Le marqueur porte l'aura creature2.
    void ZonesMarquees(Player* player, Joueur* j)
    {
        auto g = techniques.find(ZONE_MARQUEE);
        Creature* source = nullptr;
        Technique const* t = nullptr;
        bool permise = false;
        if (g != techniques.end() && player->IsInCombat())
            for (auto const& [entree, technique] : g->second)
            {
                if (technique.quete && player->GetQuestStatus(technique.quete) != QUEST_STATUS_INCOMPLETE)
                    continue;
                permise = true;
                if (Creature* c = player->FindNearestCreature(entree, 40.0f, true); c && c->IsInCombat())
                {
                    source = c;
                    t = &technique;
                    break;
                }
            }
        if (!permise)
        {
            j->orage = j->foudreA = 0;
            return;
        }
        if (!source)
            return;
        uint32 maintenant = getMSTime();
        if (j->foudreA && maintenant >= j->foudreA)
        {
            j->foudreA = 0;
            if (player->GetExactDist(j->foudre) < 4.0f)
            {
                SpellSchoolMask ecole = SPELL_SCHOOL_MASK_FIRE;
                if (t->sort)
                {
                    source->CastSpell(player, t->sort, true);
                    if (SpellInfo const* info = sSpellMgr->GetSpellInfo(t->sort))
                        ecole = info->GetSchoolMask();
                }
                Brulure(source, player, t->c / 10000.0f, ecole);
            }
        }
        if (!j->orage || maintenant >= j->orage)
        {
            j->orage = maintenant + t->a;
            j->foudre = player->GetPosition();
            j->foudreA = maintenant + t->b;
            if (TempSummon* marque = player->SummonCreature(DECLENCHEUR, j->foudre, TEMPSUMMON_TIMED_DESPAWN, t->b + 500))
                if (t->creature2)
                    marque->AddAura(t->creature2, marque);
        }
    }

    // M22, sable grouillant (A29 des Tarides) : pendant la quête et le combat contre la créature, toutes les a ms, une
    // creature2 sort sous le joueur, à la puissance b.
    void Sable(Player* player, Joueur* j)
    {
        auto g = techniques.find(SABLE);
        if (g == techniques.end())
            return;
        for (auto const& [entree, t] : g->second)
        {
            if (!player->IsInCombat() || player->GetQuestStatus(t.quete) != QUEST_STATUS_INCOMPLETE)
                continue;
            Creature* c = player->FindNearestCreature(entree, 40.0f, true);
            if (!c || !c->IsInCombat())
                continue;
            uint32 maintenant = getMSTime();
            if (!j->sable)
                j->sable = maintenant + t.a;
            else if (maintenant >= j->sable)
            {
                j->sable = maintenant + t.a;
                SolAzeroth::ImposerPuissance(uint8(t.b));
                TempSummon* larve = player->SummonCreature(t.creature2, player->GetPosition(),
                    TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, MINUTE * IN_MILLISECONDS);
                SolAzeroth::ImposerPuissance(0);
                if (larve)
                    larve->AI()->AttackStart(player);
            }
            return;
        }
        j->sable = 0;
    }

    // ------------------------------------------------------------------ épreuves de vagues (A27)

    void FinirEpreuve(Player* player, Joueur* j, bool reussie)
    {
        Epreuve& e = j->epreuve;
        for (ObjectGuid const& g : e.monstres)
            if (Creature* c = ObjectAccessor::GetCreature(*player, g))
                c->DespawnOrUnsummon();
        uint32 id = e.id;
        uint8 total = uint8(epreuves[id].vagues.size());
        uint8 tenues = reussie ? total : (e.vague ? e.vague - 1 : 0);
        uint32 temps = getMSTimeDiff(e.debut, getMSTime());
        e = Epreuve();
        Record& r = j->records[id];
        std::string texte = Acore::StringFormat("Épreuve terminée : {} vague(s) tenue(s) en {}.", tenues, Duree(temps));
        if (tenues > r.vague || (tenues == r.vague && tenues && temps < r.temps))
        {
            r.vague = tenues;
            r.temps = temps;
            texte += " Nouveau record !";
        }
        if (tenues && r.jour != Aujourdhui())
        {
            r.jour = Aujourdhui();
            SolAzeroth::DonnerMarques(player, GainMarques(player, tenues), "épreuve du jour");
        }
        SauverRecord(player, id, r);
        Alerte(player, texte);
    }

    void LancerVague(Player* player, Joueur* j)
    {
        Epreuve& e = j->epreuve;
        DefEpreuve const& def = epreuves[e.id];
        Vague const& vague = def.vagues[e.vague - 1];
        e.monstres.clear();
        uint32 total = 0;
        for (auto const& [entree, nombre] : vague.monstres)
            total += nombre;
        uint32 n = 0;
        SolAzeroth::ImposerPuissance(vague.puissance);
        for (auto const& [entree, nombre] : vague.monstres)
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
        SolAzeroth::ImposerPuissance(0);
        Alerte(player, Acore::StringFormat("{} : vague {} sur {}.", def.nom, e.vague, def.vagues.size()));
    }

    void SuivreEpreuve(Player* player, Joueur* j)
    {
        Epreuve& e = j->epreuve;
        if (!e.active)
            return;
        if (!player->IsAlive() || player->GetMapId() != e.carte || player->GetExactDist(e.centre) > 60.0f)
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
        DefEpreuve const& def = epreuves[e.id];
        if (e.vague == def.vagueMi)
            player->KilledMonsterCredit(def.creditMi);
        if (e.vague == def.vagues.size())
        {
            player->KilledMonsterCredit(def.creditFin);
            FinirEpreuve(player, j, true);
            return;
        }
        Alerte(player, Acore::StringFormat("Vague {} tenue. La suivante dans 20 secondes.", e.vague));
        ++e.vague;
        e.pause = 20 * IN_MILLISECONDS;
    }

    uint32 ReliquesTrouvees(Player* player, uint32 zone)
    {
        uint32 trouvees = 0;
        for (auto const& [objetMonde, r] : reliques)
            if (r.zone == zone)
                trouvees += SolAzeroth::NombreEnCollection(player, r.objet) ? 1 : 0;
        return trouvees;
    }
}

// Lot 4a : défi répétable déjà payé plein tarif aujourd'hui (fenêtre des objectifs, v3_zone.cpp).
bool SolAzeroth::DefiPayeAujourdhui(Player* player, unsigned int quete)
{
    Joueur* j = JoueurDe(player);
    auto it = j->payes.find(quete);
    return it != j->payes.end() && it->second == Aujourdhui();
}

unsigned char SolAzeroth::MedailleDefi(Player* player, unsigned int quete)
{
    Joueur* j = JoueurDe(player);
    auto it = j->medailles.find(quete);
    return it == j->medailles.end() ? 0 : it->second.first;
}

std::string SolAzeroth::CarteReliques(Player* player, unsigned int zone)
{
    auto it = cartes.find(zone);
    if (it == cartes.end())
        return "";
    return Acore::StringFormat("CARTE;{};{};{};{}", JoueurDe(player)->cartes.count(zone) ? 1 : 0, it->second.marques,
        it->second.cuivre, it->second.seuil);
}

// Ramassage d'une relique : au clic, ou en se tenant à moins de 3 m (signalement du 01/11/2026 : une relique
// enfouie ou derrière un rocher ne se cliquait pas).
void RamasserRelique(Player* player, GameObject* go)
{
    auto it = reliques.find(go->GetEntry());
    if (it == reliques.end())
        return;
    Relique const& r = it->second;
    if (SolAzeroth::NombreEnCollection(player, r.objet))
    {
        Dire(player, "Tu as déjà trouvé cette relique.");
        return;
    }
    SolAzeroth::AjouterACollection(player, r.objet, 1);
    go->DespawnOrUnsummon(0ms, RELIQUE_ABSENTE);
    SolAzeroth::DonnerMarques(player, 5, "relique");
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
        // Bonus de famille (solazeroth_v3_reliques_familles) : une pièce selon la classe, de l'or, des composants.
        Famille const& f = familles[r.famille];
        if (f.objet)
            player->AddItem(SolAzeroth::VersionDe(player, f.objet), 1);
        if (f.cuivre)
            player->ModifyMoney(int32(f.cuivre));
        if (f.composant && f.nombre)
            SolAzeroth::AjouterACollection(player, f.composant, f.nombre);
        Alerte(player, "Famille de reliques complète : bonus reçu !");
    }
}

// Près du joueur : relique déjà trouvée cachée, relique pas encore trouvée remise, ramassée à moins de 3 m.
void MontrerReliques(Player* player)
{
    for (auto const& [carte, spawn] : placesReliques)
    {
        if (carte != player->GetMapId())
            continue;
        auto const& apparitions = player->GetMap()->GetGameObjectBySpawnIdStore();
        auto trouve = apparitions.find(spawn);
        GameObject* go = trouve != apparitions.end() ? trouve->second : nullptr;
        if (!go || !player->IsWithinDist(go, 150.0f))
            continue;
        auto it = reliques.find(go->GetEntry());
        if (it == reliques.end())
            continue;
        // Posée au sol (signalement du 01/11/2026 : une relique flottait) : la hauteur des tables est approchée, celle
        // du terrain se lit ici, la grille étant chargée autour du joueur ; la correction est gardée en base. Vers le bas
        // seulement : chercher au-dessus faisait grimper les reliques posées dans un décor, 2 m à chaque passage.
        float sol = go->GetMap()->GetHeight(go->GetPhaseMask(), go->GetPositionX(), go->GetPositionY(),
            go->GetPositionZ() + 0.5f, true, 50.0f);
        if (sol > INVALID_HEIGHT && go->GetPositionZ() - sol > 0.05f)
        {
            go->GetMap()->GameObjectRelocation(go, go->GetPositionX(), go->GetPositionY(), sol, go->GetOrientation());
            go->DestroyForVisiblePlayers();
            go->UpdateObjectVisibility();
            WorldDatabase.Execute("UPDATE gameobject SET position_z = {} WHERE guid = {}", sol, spawn);
        }
        bool trouvee = SolAzeroth::NombreEnCollection(player, it->second.objet) > 0;
        if (trouvee && go->isSpawned())
            go->DespawnOrUnsummon(0ms, RELIQUE_ABSENTE);
        else if (!trouvee && !go->isSpawned())
            go->Respawn();
        else if (!trouvee && player->IsWithinDist(go, 3.0f))
            RamasserRelique(player, go);
    }
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
        if (QueryResult r = CharacterDatabase.Query("SELECT quete, jour FROM solazeroth_v3_annexes_jour WHERE guid = {}",
            guid))
        {
            do
                j->payes[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        }
        if (QueryResult r = CharacterDatabase.Query("SELECT zone FROM solazeroth_v3_reliques_cartes_joueur WHERE guid = {}",
            guid))
        {
            do
                j->cartes.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
        if (QueryResult r = CharacterDatabase.Query("SELECT epreuve, vague, temps, jour FROM solazeroth_v3_epreuves_joueur "
            "WHERE guid = {}", guid))
        {
            do
                j->records[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint8>(), (*r)[2].Get<uint32>(), (*r)[3].Get<uint32>() };
            while (r->NextRow());
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
        if (Technique const* t = TechniqueDe(entree, FLAQUE))
            if (TempSummon* d = creature->SummonCreature(DECLENCHEUR, creature->GetPosition(), TEMPSUMMON_TIMED_DESPAWN, t->b))
            {
                d->CastSpell(d, t->sort, true);
                flaques.push_back({ creature->GetMapId(), creature->GetPosition(), d->GetGUID(), getMSTime() + t->b,
                    t->a / 10000.0f });
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

    // Défis sans potion : boire pendant le combat contre la cible fait échouer la quête.
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
        if ((j->reliques += TICK) >= 5 * IN_MILLISECONDS)
        {
            j->reliques = 0;
            MontrerReliques(player);
        }
        ZonesMarquees(player, j);
        Sable(player, j);
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
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_epreuves_joueur WHERE guid = {}", guid.GetCounter());
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_reliques_cartes_joueur WHERE guid = {}", guid.GetCounter());
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_annexes_jour WHERE guid = {}", guid.GetCounter());
    }
};

// Techniques sur les dégâts : T14 carapace (dégâts × a % hors des b ms qui suivent un étourdissement) ; M12 frères
// d'armes (dégâts − b % à moins de a m de creature2) ; M13 renvoi (a % des coups de mêlée reçus renvoyés) ; M8 rage
// voisine (+ b % de dégâts de mêlée par monstre de sa faction mort à moins de a m, c fois au plus, 60 s) ; M16 mur
// répété (toutes les a ms de combat, le sort pendant b ms).
class solazeroth_v3_annexes_carapace : public UnitScript
{
public:
    solazeroth_v3_annexes_carapace() : UnitScript("solazeroth_v3_annexes_carapace", true, { UNITHOOK_ON_DAMAGE,
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_ON_UNIT_DEATH, UNITHOOK_ON_UNIT_UPDATE }) { }

    void OnDamage(Unit* /*attacker*/, Unit* victim, uint32& damage) override
    {
        if (!victim || !victim->IsCreature())
            return;
        if (Technique const* t = TechniqueDe(victim->GetEntry(), CARAPACE))
        {
            uint32 maintenant = getMSTime();
            if (victim->HasUnitState(UNIT_STATE_STUNNED))
            {
                etourdis[victim->GetGUID()] = maintenant;
                return;
            }
            auto it = etourdis.find(victim->GetGUID());
            if (it == etourdis.end() || getMSTimeDiff(it->second, maintenant) > t->b)
                damage = damage * t->a / 100;
        }
        if (Technique const* t = TechniqueDe(victim->GetEntry(), FRERES))
            if (victim->ToCreature()->FindNearestCreature(t->creature2, float(t->a), true))
                damage = damage * (100 - t->b) / 100;
    }

    void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) override
    {
        if (!target || !attacker)
            return;
        if (target->IsCreature() && damage)
            if (Technique const* t = TechniqueDe(target->GetEntry(), RENVOI))
                if (uint32 renvoi = damage * t->a / 100; renvoi && attacker->IsAlive())
                    Unit::DealDamage(target, attacker, renvoi, nullptr, DIRECT_DAMAGE, SPELL_SCHOOL_MASK_NATURE, nullptr,
                        false);
        if (attacker->IsCreature())
            if (Technique const* t = TechniqueDe(attacker->GetEntry(), RAGE_VOISINE))
            {
                auto it = rages.find(attacker->GetGUID());
                if (it != rages.end() && getMSTimeDiff(it->second.second, getMSTime()) < MINUTE * IN_MILLISECONDS)
                    damage = damage * (100 + t->b * it->second.first) / 100;
            }
    }

    void OnUnitDeath(Unit* unit, Unit* killer) override
    {
        if (!unit || !unit->IsCreature())
            return;
        etourdis.erase(unit->GetGUID());
        rages.erase(unit->GetGUID());
        murs.erase(unit->GetGUID());
        auto g = techniques.find(RAGE_VOISINE);
        if (g == techniques.end())
            return;
        for (auto const& [entree, t] : g->second)
        {
            Creature* chef = unit->FindNearestCreature(entree, float(t.a), true);
            if (!chef || chef == unit || chef->GetFaction() != unit->GetFaction())
                continue;
            auto& r = rages[chef->GetGUID()];
            if (getMSTimeDiff(r.second, getMSTime()) >= MINUTE * IN_MILLISECONDS)
                r.first = 0;
            r.first = uint8(std::min<uint32>(t.c, r.first + 1));
            r.second = getMSTime();
            if (Player* player = killer ? killer->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr)
                Alerte(player, Acore::StringFormat("{} gagne en rage : + {} % de dégâts.",
                    chef->GetNameForLocaleIdx(player->GetSession()->GetSessionDbLocaleIndex()), t.b * r.first));
        }
    }

    void OnUnitUpdate(Unit* unit, uint32 diff) override
    {
        if (!unit->IsCreature())
            return;
        Technique const* t = TechniqueDe(unit->GetEntry(), MUR);
        if (!t)
            return;
        if (!unit->IsInCombat() || !unit->IsAlive())
        {
            murs.erase(unit->GetGUID());
            return;
        }
        uint32& temps = murs[unit->GetGUID()];
        temps += diff;
        if (temps < t->a)
            return;
        temps = 0;
        if (Aura* mur = unit->AddAura(t->sort, unit))
        {
            mur->SetMaxDuration(int32(t->b));
            mur->SetDuration(int32(t->b));
        }
    }
};

// Reliques (A31-A46).

class go_solazeroth_v3_relique : public GameObjectScript
{
public:
    go_solazeroth_v3_relique() : GameObjectScript("go_solazeroth_v3_relique") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        RamasserRelique(player, go);
        return true;
    }
};

// Renforts des objets du monde (solazeroth_v3_renforts), seulement pendant leurs quêtes : raptors des œufs et trolls
// des monceaux de Durotar ; manouvriers des seaux et des valves, faucheurs des nids, grouillants des antres aux Tarides.
// Les deux premiers noms de script restent, pour les objets de Durotar.
class go_solazeroth_v3_appel : public GameObjectScript
{
public:
    explicit go_solazeroth_v3_appel(char const* nom) : GameObjectScript(nom) { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        auto r = renforts.find(go->GetEntry());
        if (r == renforts.end())
            return false;
        Renfort const& renfort = r->second;
        bool enCours = std::any_of(renfort.quetes.begin(), renfort.quetes.end(),
            [player](uint32 q) { return player->GetQuestStatus(q) == QUEST_STATUS_INCOMPLETE; });
        if (!enCours)
            return false;
        uint32 maintenant = getMSTime();
        auto it = nidsVides.find(go->GetGUID());
        if (it != nidsVides.end() && getMSTimeDiff(it->second, maintenant) < MINUTE * IN_MILLISECONDS)
            return false;
        nidsVides[go->GetGUID()] = maintenant;
        SolAzeroth::ImposerPuissance(renfort.puissance);
        for (uint8 i = 0; i < renfort.nombre; ++i)
        {
            Position p = go->GetPosition();
            p.RelocateOffset({ 6.0f * std::cos(i * 3.0f), 6.0f * std::sin(i * 3.0f), 0.0f, 0.0f });
            p.m_positionZ = go->GetMap()->GetHeight(p.GetPositionX(), p.GetPositionY(), go->GetPositionZ() + 5.0f);
            if (TempSummon* c = go->SummonCreature(renfort.creature, p, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, 30000))
                c->AI()->AttackStart(player);
        }
        SolAzeroth::ImposerPuissance(0);
        return false;
    }
};

// Gardiens des épreuves de vagues : Zun'jala (A27 de Durotar), Regthar Seuil-de-mort (A27 des Tarides).
class npc_solazeroth_v3_zunjala : public CreatureScript
{
public:
    npc_solazeroth_v3_zunjala() : CreatureScript("npc_solazeroth_v3_zunjala") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        player->PrepareQuestMenu(creature->GetGUID());
        Joueur* j = JoueurDe(player);
        auto e = epreuveDuPnj.find(creature->GetEntry());
        if (e != epreuveDuPnj.end())
        {
            DefEpreuve const& def = epreuves[e->second];
            Record const& r = j->records[e->second];
            bool permise = player->GetQuestStatus(def.quete) == QUEST_STATUS_INCOMPLETE ||
                player->GetQuestStatus(def.quete2) == QUEST_STATUS_INCOMPLETE || player->GetQuestRewardStatus(def.quete);
            if (permise && !j->epreuve.active)
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, r.vague ? Acore::StringFormat(
                    "Commencer l'épreuve (record : vague {} en {}).", r.vague, Duree(r.temps)) :
                    std::string("Commencer l'épreuve."), GOSSIP_SENDER_MAIN, 1);
        }
        SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        Joueur* j = JoueurDe(player);
        auto id = epreuveDuPnj.find(creature->GetEntry());
        if (action != 1 || j->epreuve.active || id == epreuveDuPnj.end() || epreuves[id->second].vagues.empty())
            return true;
        Epreuve& e = j->epreuve;
        e.active = true;
        e.id = id->second;
        e.vague = 1;
        e.debut = getMSTime();
        e.carte = creature->GetMapId();
        e.centre = creature->GetPosition();
        e.pause = 5 * IN_MILLISECONDS;
        Alerte(player, "L'épreuve commence dans 5 secondes. " + epreuves[id->second].consigne);
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

    // .annexes carte : dévoile dans la fenêtre des objectifs la place des reliques de la zone où l'on est
    // (solazeroth_v3_reliques_cartes : Durotar 30 Marques et 2 po).
    static bool HandleCarte(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Joueur* j = JoueurDe(player);
        uint32 zone = player->GetZoneId();
        auto it = cartes.find(zone);
        if (it == cartes.end())
        {
            handler->SendErrorMessage("Cette zone n'a pas de carte des reliques.");
            return false;
        }
        Carte const& c = it->second;
        if (j->cartes.count(zone))
        {
            handler->SendSysMessage("Tu as déjà la carte des reliques.");
            return true;
        }
        uint32 trouvees = ReliquesTrouvees(player, zone);
        if (trouvees < c.seuil)
        {
            handler->SendErrorMessage("La carte des reliques se vend à qui en a déjà trouvé {} ({} / {}).",
                c.seuil, trouvees, c.seuil);
            return false;
        }
        if (SolAzeroth::Marques(player) < c.marques || player->GetMoney() < c.cuivre)
        {
            handler->SendErrorMessage("La carte des reliques coûte {} Marques du voyageur et {}.", c.marques, Prix(c.cuivre));
            return false;
        }
        SolAzeroth::RetirerMarques(player, c.marques);
        player->ModifyMoney(-int32(c.cuivre));
        j->cartes.insert(zone);
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_reliques_cartes_joueur (guid, zone) VALUES ({}, {})",
            player->GetGUID().GetCounter(), zone);
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
        familles.clear();
        cartes.clear();
        epreuves.clear();
        epreuveDuPnj.clear();
        renforts.clear();
        techniques.clear();
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
                a.depart = Liste(f[7].Get<std::string>());
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
        if (QueryResult r = WorldDatabase.Query("SELECT objet_monde, objet, famille, composant, zone FROM solazeroth_v3_reliques"))
        {
            do
                reliques[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint32>(), (*r)[3].Get<uint32>(), (*r)[4].Get<uint32>(),
                    (*r)[2].Get<uint8>() };
            while (r->NextRow());
        }
        placesReliques.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT g.map, g.guid FROM gameobject g JOIN solazeroth_v3_reliques r "
            "ON r.objet_monde = g.id"))
        {
            do
                placesReliques.emplace_back((*r)[0].Get<uint32>(), (*r)[1].Get<ObjectGuid::LowType>());
            while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT famille, objet, cuivre, composant, nombre FROM "
            "solazeroth_v3_reliques_familles"))
        {
            do
                familles[(*r)[0].Get<uint8>()] = { (*r)[1].Get<uint32>(), (*r)[2].Get<uint32>(), (*r)[3].Get<uint32>(),
                    (*r)[4].Get<uint32>() };
            while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT zone, marques, cuivre, seuil FROM solazeroth_v3_reliques_cartes"))
        {
            do
                cartes[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint32>(), (*r)[2].Get<uint32>(), (*r)[3].Get<uint32>() };
            while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT epreuve, pnj, quete, quete2, credit_mi, vague_mi, credit_fin, nom, "
            "consigne FROM solazeroth_v3_epreuves"))
        {
            do
            {
                Field* f = r->Fetch();
                DefEpreuve& e = epreuves[f[0].Get<uint32>()];
                e.pnj = f[1].Get<uint32>();
                e.quete = f[2].Get<uint32>();
                e.quete2 = f[3].Get<uint32>();
                e.creditMi = f[4].Get<uint32>();
                e.vagueMi = f[5].Get<uint8>();
                e.creditFin = f[6].Get<uint32>();
                e.nom = f[7].Get<std::string>();
                e.consigne = f[8].Get<std::string>();
                epreuveDuPnj[e.pnj] = f[0].Get<uint32>();
            } while (r->NextRow());
        }
        uint32 nombreVagues = 0;
        if (QueryResult r = WorldDatabase.Query("SELECT epreuve, vague, creature, nombre, puissance FROM solazeroth_v3_vagues "
            "ORDER BY epreuve, vague"))
        {
            do
            {
                auto e = epreuves.find((*r)[0].Get<uint32>());
                if (e == epreuves.end())
                    continue;
                uint8 v = (*r)[1].Get<uint8>();
                if (e->second.vagues.size() < v)
                {
                    e->second.vagues.resize(v);
                    ++nombreVagues;
                }
                e->second.vagues[v - 1].monstres.emplace_back((*r)[2].Get<uint32>(), (*r)[3].Get<uint8>());
                e->second.vagues[v - 1].puissance = (*r)[4].Get<uint8>();
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT objet_monde, creature, nombre, quetes, puissance FROM "
            "solazeroth_v3_renforts"))
        {
            do
                renforts[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint32>(), (*r)[2].Get<uint8>(), (*r)[4].Get<uint8>(),
                    Liste((*r)[3].Get<std::string>()) };
            while (r->NextRow());
        }
        uint32 nombreTechniques = 0;
        if (QueryResult r = WorldDatabase.Query("SELECT creature, genre, quete, a, b, c, sort, creature2 FROM "
            "solazeroth_v3_techniques"))
        {
            do
            {
                Field* f = r->Fetch();
                techniques[f[1].Get<uint8>()][f[0].Get<uint32>()] = { f[0].Get<uint32>(), f[2].Get<uint32>(),
                    f[3].Get<uint32>(), f[4].Get<uint32>(), f[5].Get<uint32>(), f[6].Get<uint32>(), f[7].Get<uint32>() };
                ++nombreTechniques;
            } while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} annexes à quête, {} reliques, {} épreuves ({} vagues), {} renforts, "
            "{} techniques", annexes.size(), reliques.size(), epreuves.size(), nombreVagues, renforts.size(),
            nombreTechniques);
    }
};

void AddSC_solazeroth_v3_annexes()
{
    new solazeroth_v3_annexes_joueur();
    new solazeroth_v3_annexes_carapace();
    new go_solazeroth_v3_relique();
    new go_solazeroth_v3_appel("go_solazeroth_v3_oeufs");
    new go_solazeroth_v3_appel("go_solazeroth_v3_monceau");
    new go_solazeroth_v3_appel("go_solazeroth_v3_renfort");
    new npc_solazeroth_v3_zunjala();
    new solazeroth_v3_annexes_commandes();
    new solazeroth_v3_annexes_monde();
}
