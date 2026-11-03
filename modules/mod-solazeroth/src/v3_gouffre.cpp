// v3, F5f (31/10/2026) : accès au Gouffre de Ragefeu à 60 % de Durotar (document v3, F5 ; document de Durotar, D26 et
// moment scripté n°1).
// - Ruga Brise-cendre (910001), devant la faille du Rocher du crâne : en plus de ses quêtes, une option « Descendre dans
//   la faille ». Avec D26 rendue et 60 % de Durotar, elle envoie le joueur à l'entrée du Gouffre ; sinon elle lui dit
//   ce qui manque, avec son pourcentage.
// - Toute autre entrée dans le Gouffre (l'entrée d'origine, à Orgrimmar) est refusée sous ces conditions.
// - La sortie du Gouffre ramène auprès de Ruga (migration 076, areatrigger_teleport 2226).
// Les maîtres du jeu passent toujours.
// Lot T0 des Tarides (03/11/2026, migration 135) : rendu générique, sans rien changer au Gouffre.
// - Seuils de donjon : table solazeroth_v3_donjons_seuils, une ligne par donjon (carte) : zone dont on lit le
//   pourcentage (pas forcément celle du PNJ : Ebru est en zone 718 et lira la zone 17), seuil, quête à rendre, PNJ et son
//   texte, arrivée, et les phrases. Dans les phrases de refus, « {pourcent} » et « {seuil} » sont remplacés. Le PNJ
//   prend le script npc_solazeroth_v3_seuil. .teleportdonjon lit les mêmes conditions (SolAzeroth::RefusDonjon).
// - Entrées scellées : table solazeroth_v3_entrees_scellees (zone de déclenchement, carte, message). La zone de
//   déclenchement (areatrigger_scripts, at_solazeroth_v3_scelle) refuse et repousse le joueur de quelques mètres ; toute
//   autre téléportation vers la carte est refusée. Le Kraal (244, carte 47) et les Souilles (442, carte 129) des
//   Tarides restent fermés jusqu'à bien plus tard.
// Lot T1 des Tarides (03/11/2026, migration 136) : la garde posée devant chaque entrée scellée (colonne garde, guid
// d'apparition) dit sa réplique (colonne replique) quand un joueur approche à moins de PORTEE_REPLIQUE m, une fois
// toutes les ATTENTE_REPLIQUE s au plus (npc_solazeroth_v3_garde_scellee, mis par la migration sur ces apparitions).
// Lot T5 des Tarides (03/11/2026, migration 146, point 4 du brouillon des Tarides) : Ebru (5768) prend une ligne de
// seuil (Cavernes des Lamentations, 60 % des Tarides et T30). L'escorte du Disciple de Naralex (3678) passe du SmartAI
// à npc_solazeroth_v3_disciple, adaptée au solo :
// - mêmes étapes, répliques, sorts et positions que le SmartAI d'origine (chemin 3678 de waypoints) ; il ne part que
//   si les quatre seigneurs sont tombés (données 0 à 3 de l'instance), sinon il dit combien il en reste ;
// - le disciple ne peut pas mourir (insensible aux PNJ et aux joueurs) ; les monstres appelés attaquent le joueur ;
// - jamais plus de 2 monstres appelés à la fois : 2 Ravageurs au point 5, une Vipère et un Aspic au point 12, puis au
//   rituel 2 Mocassins, 3 vagues de 2 Ectoplasmes et Mutanus le Dévoreur, ENTRE_VAGUES après la chute de chaque vague ;
// - si le joueur meurt, part ou s'éloigne de plus de PORTEE_ESCORTE m, les monstres appelés disparaissent et le
//   disciple revient au dernier point de reprise atteint (5, 12 ou 20), où on lui reparle : il reprend là.
// Mutanus garde son SmartAI (sorts, réveil de Naralex à sa mort) ; Naralex aussi (envol du disciple, SetData 2 2).

#include "SolAzeroth.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "InstanceScript.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "SmartScriptMgr.h"
#include "StringFormat.h"
#include "TemporarySummon.h"
#include <unordered_map>

namespace
{
    uint32 const DESCENDRE = 1;
    float const RECUL = 8.0f, RECUL_HAUT = 3.0f;   // vitesses du petit recul (horizontale, verticale)

    struct Seuil
    {
        uint32 carte = 0, zone = 0, seuil = 0, quete = 0, pnj = 0, texte = 0;
        float x = 0.0f, y = 0.0f, z = 0.0f, o = 0.0f;
        std::string option, refusQuete, refusPourcent, refusEntree;
    };
    std::unordered_map<uint32, Seuil> seuils;          // carte -> seuil
    std::unordered_map<uint32, uint32> carteDuPnj;     // PNJ -> carte

    struct Scellee
    {
        uint32 carte = 0;
        std::string message;
    };
    std::unordered_map<uint32, Scellee> scellees;              // zone de déclenchement -> entrée
    std::unordered_map<uint32, std::string> cartesScellees;    // carte -> message
    std::unordered_map<uint32, std::string> repliquesGardes;   // apparition de la garde -> réplique
    float const PORTEE_REPLIQUE = 15.0f;
    uint32 const ATTENTE_REPLIQUE = 60000;

    std::string Pourcent(uint32 centiemes)
    {
        std::string texte = Acore::StringFormat("{:.1f}", centiemes / 100.0f);
        if (texte.size() > 2 && texte.substr(texte.size() - 2) == ".0")
            texte.resize(texte.size() - 2);
        for (char& c : texte)
            if (c == '.')
                c = ',';
        return texte + " %";
    }

    void Remplacer(std::string& texte, std::string const& marque, std::string const& valeur)
    {
        for (size_t i = texte.find(marque); i != std::string::npos; i = texte.find(marque, i + valeur.size()))
            texte.replace(i, marque.size(), valeur);
    }

    // Ce qui empêche de descendre, ou une chaîne vide.
    std::string Refus(Player* player, Seuil const& s)
    {
        if (player->IsGameMaster())
            return {};
        if (s.quete && !player->GetQuestRewardStatus(s.quete))
            return s.refusQuete;
        uint32 pourcent = SolAzeroth::PourcentZone(player, s.zone);
        if (pourcent < s.seuil)
        {
            std::string texte = s.refusPourcent;
            Remplacer(texte, "{pourcent}", Pourcent(pourcent));
            Remplacer(texte, "{seuil}", Pourcent(s.seuil));
            return texte;
        }
        return {};
    }
}

std::string SolAzeroth::RefusDonjon(Player* player, unsigned int carte)
{
    if (!player->IsGameMaster())
        if (auto c = cartesScellees.find(carte); c != cartesScellees.end())
            return c->second;
    auto s = seuils.find(carte);
    if (s == seuils.end())
        return {};
    std::string refus = Refus(player, s->second);
    return refus.empty() ? refus : s->second.refusEntree + refus;
}

class npc_solazeroth_v3_seuil : public CreatureScript
{
public:
    npc_solazeroth_v3_seuil() : CreatureScript("npc_solazeroth_v3_seuil") { }

    static Seuil const* SeuilDe(Creature* creature)
    {
        auto c = carteDuPnj.find(creature->GetEntry());
        return c == carteDuPnj.end() ? nullptr : &seuils[c->second];
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        Seuil const* s = SeuilDe(creature);
        if (!s)
            return false;
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, s->option, GOSSIP_SENDER_MAIN, DESCENDRE);
        SendGossipMenuFor(player, s->texte, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        Seuil const* s = SeuilDe(creature);
        if (action != DESCENDRE || !s)
            return true;
        if (std::string refus = Refus(player, *s); !refus.empty())
        {
            creature->Whisper(refus, LANG_UNIVERSAL, player);
            return true;
        }
        player->TeleportTo(s->carte, s->x, s->y, s->z, s->o);
        return true;
    }
};

class solazeroth_v3_gouffre_joueur : public PlayerScript
{
public:
    solazeroth_v3_gouffre_joueur() : PlayerScript("solazeroth_v3_gouffre_joueur", { PLAYERHOOK_ON_BEFORE_TELEPORT }) { }

    bool OnPlayerBeforeTeleport(Player* player, uint32 carte, float /*x*/, float /*y*/, float /*z*/, float /*o*/,
        uint32 /*options*/, Unit* /*cible*/) override
    {
        if (player->GetMapId() == carte)
            return true;
        std::string refus = SolAzeroth::RefusDonjon(player, carte);
        if (refus.empty())
            return true;
        ChatHandler(player->GetSession()).SendSysMessage(refus);
        return false;
    }
};

// Zone de déclenchement d'une entrée scellée : refus, et le joueur est repoussé loin de son centre. Le moteur ne
// passe pas ici pour un maître du jeu.
class at_solazeroth_v3_scelle : public AreaTriggerScript
{
public:
    at_solazeroth_v3_scelle() : AreaTriggerScript("at_solazeroth_v3_scelle") { }

    bool OnTrigger(Player* player, AreaTrigger const* trigger) override
    {
        auto s = scellees.find(trigger->entry);
        if (s == scellees.end() || player->IsGameMaster())
            return false;
        ChatHandler(player->GetSession()).SendSysMessage(s->second.message);
        player->KnockbackFrom(trigger->x, trigger->y, RECUL, RECUL_HAUT);
        return true;
    }
};

// Garde d'une entrée scellée : sa réplique quand un joueur approche.
class npc_solazeroth_v3_garde_scellee : public CreatureScript
{
public:
    npc_solazeroth_v3_garde_scellee() : CreatureScript("npc_solazeroth_v3_garde_scellee") { }

    struct Garde : public ScriptedAI
    {
        explicit Garde(Creature* creature) : ScriptedAI(creature) { }

        uint32 attente = 0;

        void UpdateAI(uint32 diff) override
        {
            attente = attente > diff ? attente - diff : 0;
            ScriptedAI::UpdateAI(diff);
        }

        void MoveInLineOfSight(Unit* qui) override
        {
            ScriptedAI::MoveInLineOfSight(qui);
            if (attente || me->IsInCombat() || !qui || !qui->IsPlayer() || !me->IsWithinDist(qui, PORTEE_REPLIQUE))
                return;
            auto r = repliquesGardes.find(me->GetSpawnId());
            if (r == repliquesGardes.end())
                return;
            me->Say(r->second, LANG_UNIVERSAL, qui);
            attente = ATTENTE_REPLIQUE;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new Garde(creature);
    }
};

// Lot T5 des Tarides : escorte du Disciple de Naralex, en solo.
namespace
{
    uint32 const NARALEX = 3679, MUTANUS = 3654;
    uint32 const RAVAGEUR = 3636, VIPERE = 5755, ASPIC = 5048, MOCASSIN = 5762, ECTOPLASME = 5763;
    uint32 const SORT_BENEDICTION = 5232, SORT_PURIFICATION = 6270, SORT_EVEIL = 6271;
    uint32 const CHEMIN = 3678, ENVOL = 3679;
    uint32 const COMMENCER = 1;
    uint32 const TEXTE_DISCIPLE = 698;             // gossip_menu 201 d'origine
    float const PORTEE_ESCORTE = 80.0f;
    uint32 const ENTRE_VAGUES = 10000, CONTROLE = 1000, CORPS = 60000, CORPS_MUTANUS = 300000;
    uint32 const ENVOL_PREMIER = 100;             // identifiants des points de l'envol
    Position const RAVAGEURS[] = { { -73.57f, 214.39f, -93.66f, 2.34f }, { -70.85f, 211.6f, -93.49f, 2.34f } };
    Position const GROUPE_VIPERE[] = { { -57.49f, 280.59f, -92.84f, 5.22f }, { -61.81f, 271.145f, -92.84f, 0.36f } };
    Position const MOCASSINS[] = { { 143.57f, 218.98f, -102.9f, 2.37f }, { 132.35f, 268.0f, -102.5f, 4.144f } };
    Position const ECTOPLASMES[] = { { 149.14f, 252.73f, -102.62f, 3.5f }, { 150.11f, 225.36f, -102.9f, 2.68f },
        { 107.55f, 276.57f, -102.4f, 4.92f }, { 143.57f, 218.98f, -102.9f, 2.37f },
        { 137.94f, 262.89f, -102.85f, 3.99f }, { 107.55f, 276.57f, -102.4f, 4.92f } };
    Position const POSITION_MUTANUS = { 151.27f, 252.26f, -102.82f, 3.38f };
    std::unordered_map<uint32, uint32> reprises;   // instance -> dernier point de reprise atteint (0, 5, 12 ou 20)

    enum Etape : uint8 { ATTENTE, MARCHE, PAUSE, RITUEL, FINI };
}

class npc_solazeroth_v3_disciple : public CreatureScript
{
public:
    npc_solazeroth_v3_disciple() : CreatureScript("npc_solazeroth_v3_disciple") { }

    struct Disciple : public ScriptedAI
    {
        explicit Disciple(Creature* creature) : ScriptedAI(creature), invoques(creature) { }

        SummonList invoques;
        ObjectGuid joueur;
        uint8 etape = ATTENTE, sous = 0, vivants = 0;
        uint32 point = 0, attente = 0, controle = CONTROLE;

        void Reset() override
        {
            me->SetImmuneToPC(true);
            me->SetImmuneToNPC(true);
            me->SetReactState(REACT_PASSIVE);
        }

        // Le disciple n'entre jamais en combat.
        void AttackStart(Unit* /*cible*/) override { }
        void MoveInLineOfSight(Unit* /*qui*/) override { }

        WaypointNode const* Noeud(uint32 chemin, uint32 id) const
        {
            if (WaypointPath const* p = sSmartWaypointMgr->GetPath(chemin))
                for (WaypointNode const& n : p->Nodes)
                    if (n.Id == id)
                        return &n;
            return nullptr;
        }

        Player* Joueur() const { return joueur ? ObjectAccessor::GetPlayer(*me, joueur) : nullptr; }

        void ParlerNaralex(uint8 groupe)
        {
            if (Creature* naralex = me->FindNearestCreature(NARALEX, 200.0f))
                if (naralex->AI())
                    naralex->AI()->Talk(groupe);
        }

        void Commencer(Player* player)
        {
            joueur = player->GetGUID();
            me->RemoveNpcFlag(UNIT_NPC_FLAG_GOSSIP);
            me->setActive(true);
            me->SetWalk(false);
            uint32 reprise = reprises[me->GetInstanceId()];
            if (reprise)
                Arriver(reprise);
            else
                Aller(1);
        }

        void Aller(uint32 id)
        {
            WaypointNode const* n = Noeud(CHEMIN, id);
            if (!n)
                return;
            etape = MARCHE;
            me->GetMotionMaster()->MovePoint(id, n->X, n->Y, n->Z);
        }

        void Pause(uint32 duree)
        {
            etape = PAUSE;
            attente = duree;
        }

        void Reprise(uint32 id)
        {
            reprises[me->GetInstanceId()] = id;
            if (WaypointNode const* n = Noeud(CHEMIN, id))
                me->SetHomePosition(n->X, n->Y, n->Z, me->GetOrientation());
        }

        void Invoquer(uint32 entree, Position const& pos, uint32 corps = CORPS)
        {
            Player* player = Joueur();
            TempSummon* s = me->SummonCreature(entree, pos, TEMPSUMMON_CORPSE_TIMED_DESPAWN, corps);
            if (!s)
                return;
            ++vivants;
            s->SetReactState(REACT_AGGRESSIVE);
            if (player && s->AI())
                s->AI()->AttackStart(player);
        }

        void JustSummoned(Creature* s) override { invoques.Summon(s); }

        // Arrivée à un point du chemin (ou reprise à ce point).
        void Arriver(uint32 id)
        {
            point = id;
            sous = 0;
            switch (id)
            {
                case 1:
                    Talk(1);
                    Pause(8000);
                    break;
                case 5:
                    Reprise(5);
                    Talk(2);
                    for (Position const& p : RAVAGEURS)
                        Invoquer(RAVAGEUR, p);
                    Pause(8000);
                    break;
                case 12:
                    Reprise(12);
                    Talk(4);
                    DoCastSelf(SORT_PURIFICATION, true);
                    Pause(10000);
                    break;
                case 20:
                    Reprise(20);
                    Talk(6);
                    Pause(7000);
                    break;
                case 25:
                    etape = RITUEL;
                    Talk(7);
                    attente = 5000;
                    break;
                default:
                    Aller(id + 1);
                    break;
            }
        }

        // Fin d'une pause (délai écoulé et monstres appelés tombés).
        void Suite()
        {
            switch (point)
            {
                case 1: Aller(2); break;
                case 5: Talk(3); Aller(6); break;
                case 12:
                    if (sous == 0)
                    {
                        sous = 1;
                        Invoquer(VIPERE, GROUPE_VIPERE[0]);
                        Invoquer(ASPIC, GROUPE_VIPERE[1]);
                        attente = 22500;
                    }
                    else
                    {
                        me->InterruptNonMeleeSpells(false);
                        Talk(5);
                        Aller(13);
                    }
                    break;
                case 20: Aller(21); break;
                case 25: Rituel(); break;
                default: break;
            }
        }

        void Rituel()
        {
            switch (sous++)
            {
                case 0:
                    Talk(8);
                    DoCastSelf(SORT_EVEIL, true);
                    ParlerNaralex(0);
                    attente = 3000;
                    break;
                case 1:
                    for (Position const& p : MOCASSINS)
                        Invoquer(MOCASSIN, p);
                    break;
                case 2:
                case 3:
                case 4:
                {
                    if (sous == 3)
                        ParlerNaralex(1);
                    uint8 vague = sous - 3;
                    Invoquer(ECTOPLASME, ECTOPLASMES[vague * 2]);
                    Invoquer(ECTOPLASME, ECTOPLASMES[vague * 2 + 1]);
                    break;
                }
                case 5:
                    ParlerNaralex(2);
                    Invoquer(MUTANUS, POSITION_MUTANUS, CORPS_MUTANUS);
                    break;
                default:
                    break;
            }
        }

        void SummonedCreatureDies(Creature* s, Unit* /*tueur*/) override
        {
            if (vivants)
                --vivants;
            if (s->GetEntry() == MUTANUS)
            {
                etape = FINI;
                reprises.erase(me->GetInstanceId());
                me->InterruptNonMeleeSpells(false);
                return;
            }
            if (!vivants && etape == RITUEL)
                attente = ENTRE_VAGUES;
        }

        // Le joueur est mort, parti ou trop loin : retour au dernier point de reprise.
        void Echouer()
        {
            invoques.DespawnAll();
            vivants = 0;
            sous = 0;
            attente = 0;
            joueur.Clear();
            me->InterruptNonMeleeSpells(false);
            me->GetMotionMaster()->Clear();
            uint32 reprise = reprises[me->GetInstanceId()];
            WaypointNode const* n = reprise ? Noeud(CHEMIN, reprise) : nullptr;
            Position retour = n ? Position(n->X, n->Y, n->Z, me->GetOrientation()) : me->GetHomePosition();
            me->NearTeleportTo(retour);
            me->SetHomePosition(retour);
            me->SetNpcFlag(UNIT_NPC_FLAG_GOSSIP);
            me->setActive(false);
            etape = ATTENTE;
            me->Say("Le cauchemar m'a repoussé. Reviens me parler : je reprendrai d'ici.", LANG_UNIVERSAL);
        }

        void MovementInform(uint32 type, uint32 id) override
        {
            if (type != POINT_MOTION_TYPE)
                return;
            if (id >= ENVOL_PREMIER)
            {
                if (WaypointNode const* n = Noeud(ENVOL, id - ENVOL_PREMIER + 2))   // le point suivant de l'envol
                    me->GetMotionMaster()->MovePoint(id + 1, n->X, n->Y, n->Z);
                return;
            }
            if (etape == MARCHE)
                Arriver(id);
        }

        // Naralex réveillé (son SmartAI, à la mort de Mutanus) : le disciple s'envole avec lui.
        void SetData(uint32 type, uint32 valeur) override
        {
            if (type != 2 || valeur != 2)
                return;
            etape = FINI;
            me->SetCanFly(true);
            me->SetDisableGravity(true);
            if (WaypointNode const* n = Noeud(ENVOL, 1))
                me->GetMotionMaster()->MovePoint(ENVOL_PREMIER, n->X, n->Y, n->Z);
        }

        void UpdateAI(uint32 diff) override
        {
            if (etape == ATTENTE || etape == FINI)
                return;
            if (controle <= diff)
            {
                controle = CONTROLE;
                Player* player = Joueur();
                if (!player || !player->IsAlive() || player->GetMap() != me->GetMap() || !me->IsWithinDist(player, PORTEE_ESCORTE))
                {
                    Echouer();
                    return;
                }
            }
            else
                controle -= diff;
            if (etape != PAUSE && etape != RITUEL)
                return;
            if (attente > diff)
            {
                attente -= diff;
                return;
            }
            attente = 0;
            if (!vivants)
                Suite();
        }
    };

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        Disciple* ai = CAST_AI(Disciple, creature->AI());
        if (!ai || ai->etape != ATTENTE)
            return true;
        creature->CastSpell(player, SORT_BENEDICTION, true);
        uint32 restants = 4;
        if (InstanceScript* instance = creature->GetInstanceScript())
            for (uint32 i = 0; i < 4; ++i)
                if (instance->GetData(i) == DONE)
                    --restants;
        if (restants && !player->IsGameMaster())
        {
            creature->Whisper(Acore::StringFormat("Les traîtres tiennent encore le cauchemar : {} sur 4 respirent. "
                "Abats-les, puis reviens.", restants), LANG_UNIVERSAL, player);
            SendGossipMenuFor(player, TEXTE_DISCIPLE, creature->GetGUID());
            return true;
        }
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Que le réveil commence !", GOSSIP_SENDER_MAIN, COMMENCER);
        SendGossipMenuFor(player, TEXTE_DISCIPLE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        Disciple* ai = CAST_AI(Disciple, creature->AI());
        if (action == COMMENCER && ai && ai->etape == ATTENTE)
            ai->Commencer(player);
        return true;
    }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new Disciple(creature);
    }
};

class solazeroth_v3_seuils_monde : public WorldScript
{
public:
    solazeroth_v3_seuils_monde() : WorldScript("solazeroth_v3_seuils_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        seuils.clear();
        carteDuPnj.clear();
        scellees.clear();
        cartesScellees.clear();
        repliquesGardes.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT carte, zone, seuil, quete, pnj, texte, x, y, z, o, choix, "
            "refus_quete, refus_pourcent, refus_entree FROM solazeroth_v3_donjons_seuils"))
        {
            do
            {
                Field* f = r->Fetch();
                Seuil s;
                s.carte = f[0].Get<uint32>();
                s.zone = f[1].Get<uint32>();
                s.seuil = f[2].Get<uint32>();
                s.quete = f[3].Get<uint32>();
                s.pnj = f[4].Get<uint32>();
                s.texte = f[5].Get<uint32>();
                s.x = f[6].Get<float>();
                s.y = f[7].Get<float>();
                s.z = f[8].Get<float>();
                s.o = f[9].Get<float>();
                s.option = f[10].Get<std::string>();
                s.refusQuete = f[11].Get<std::string>();
                s.refusPourcent = f[12].Get<std::string>();
                s.refusEntree = f[13].Get<std::string>();
                if (s.pnj)
                    carteDuPnj[s.pnj] = s.carte;
                seuils[s.carte] = std::move(s);
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT declencheur, carte, message, garde, replique FROM "
            "solazeroth_v3_entrees_scellees"))
        {
            do
            {
                Field* f = r->Fetch();
                if (f[3].Get<uint32>() && !f[4].Get<std::string>().empty())
                    repliquesGardes[f[3].Get<uint32>()] = f[4].Get<std::string>();
                Scellee s{ f[1].Get<uint32>(), f[2].Get<std::string>() };
                cartesScellees[s.carte] = s.message;
                scellees[f[0].Get<uint32>()] = std::move(s);
            } while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} seuil(s) de donjon, {} entrée(s) scellée(s)", seuils.size(),
            scellees.size());
    }
};

void AddSC_solazeroth_v3_gouffre()
{
    new npc_solazeroth_v3_seuil();
    new solazeroth_v3_gouffre_joueur();
    new at_solazeroth_v3_scelle();
    new npc_solazeroth_v3_garde_scellee();
    new npc_solazeroth_v3_disciple();
    new solazeroth_v3_seuils_monde();
}
