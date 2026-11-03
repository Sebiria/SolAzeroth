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

#include "SolAzeroth.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "StringFormat.h"
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
        if (QueryResult r = WorldDatabase.Query("SELECT declencheur, carte, message FROM solazeroth_v3_entrees_scellees"))
        {
            do
            {
                Field* f = r->Fetch();
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
    new solazeroth_v3_seuils_monde();
}
