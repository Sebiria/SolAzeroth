// Chaîne d'histoire « Le fil du Fléau » (section 4.7, V6 ; décisions de l'utilisateur du 28/10/2026 : fil du Fléau de
// 1 à 80, chapitres conditionnés par le niveau et le niveau d'objet, pas de raccourci jusqu'au Roi-liche).
// - Le chroniqueur de la Croisade (900120, Hurlevent et Orgrimmar) donne les 17 chapitres (quêtes 900200 à 900216,
//   migrations 045 et 059 ; le chapitre 4, « Les cultes de la mort », est la quête 900216) l'un après l'autre. Il ne propose le suivant que si le personnage a le niveau et le niveau d'objet
//   moyen du chapitre (table solazeroth_histoire ; ilvl 0 = 90 % de l'ilvl attendu à ce niveau, ecart.cpp).
// - Certains chapitres demandent d'avoir vécu une quête d'origine (Portail du Courroux, gambit de Tirion…). Le serveur
//   crédite alors un « témoin » (solazeroth_histoire_temoins) : à la fin de la quête d'origine, à l'acceptation du
//   chapitre si elle est déjà faite, et à chaque visite au chroniqueur.
// - Le bonus d'XP de compte par chapitre est dans lua_scripts/compte_bonus.lua.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GossipDef.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <unordered_map>
#include <vector>

namespace
{
    struct Chapitre
    {
        uint8 numero;
        uint32 quete;
        uint8 niveau;
        uint16 ilvl;
    };

    std::vector<Chapitre> chapitres;
    std::unordered_map<uint32, uint32> temoins;   // quête d'origine -> témoin

    Chapitre const* ChapitreDeQuete(uint32 quete)
    {
        for (Chapitre const& c : chapitres)
            if (c.quete == quete)
                return &c;
        return nullptr;
    }

    float IlvlRequis(Chapitre const& c)
    {
        return c.ilvl ? float(c.ilvl) : SolAzeroth::IlvlAttenduNiveau(c.niveau) * 0.9f;
    }

    void CrediterTemoins(Player* player)
    {
        for (auto const& [quete, temoin] : temoins)
            if (player->GetQuestRewardStatus(quete))
                player->KilledMonsterCredit(temoin);
    }
}

class npc_solazeroth_chroniqueur : public CreatureScript
{
public:
    npc_solazeroth_chroniqueur() : CreatureScript("npc_solazeroth_chroniqueur") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        CrediterTemoins(player);

        Chapitre const* suivant = nullptr;
        for (Chapitre const& c : chapitres)
            if (!player->GetQuestRewardStatus(c.quete))
            {
                suivant = &c;
                break;
            }

        if (!suivant)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Ton histoire est complète. Le Roi-liche est tombé.", GOSSIP_SENDER_MAIN, 0);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature);
            return true;
        }

        float ilvl = SolAzeroth::IlvlEquipe(player), requis = IlvlRequis(*suivant);
        bool enCours = player->GetQuestStatus(suivant->quete) != QUEST_STATUS_NONE;
        if (enCours || (player->GetLevel() >= suivant->niveau && ilvl >= requis))
        {
            player->PrepareQuestMenu(creature->GetGUID());
            player->SendPreparedQuest(creature->GetGUID());
            return true;
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("Chapitre {} sur {} : reviens quand tu seras prêt.",
            suivant->numero, chapitres.size()), GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("Niveau requis : {} (tu es {}{}).", suivant->niveau,
            player->GetLevel(), player->GetLevel() >= suivant->niveau ? ", c'est bon" : ""), GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("Niveau d'objet moyen requis : {:.0f} (tu as {:.0f}{}).",
            requis, ilvl, ilvl >= requis ? ", c'est bon" : ""), GOSSIP_SENDER_MAIN, 0);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* /*creature*/, uint32 /*sender*/, uint32 /*action*/) override
    {
        CloseGossipMenuFor(player);
        return true;
    }
};

class solazeroth_histoire_joueur : public PlayerScript
{
public:
    solazeroth_histoire_joueur() : PlayerScript("solazeroth_histoire_joueur",
        { PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST, PLAYERHOOK_ON_PLAYER_QUEST_ACCEPT }) { }

    void OnPlayerCompleteQuest(Player* player, Quest const* quete) override
    {
        auto it = temoins.find(quete->GetQuestId());
        if (it != temoins.end())
            player->KilledMonsterCredit(it->second);
    }

    void OnPlayerQuestAccept(Player* player, Quest const* quete) override
    {
        if (ChapitreDeQuete(quete->GetQuestId()))
            CrediterTemoins(player);
    }
};

class solazeroth_histoire_monde : public WorldScript
{
public:
    solazeroth_histoire_monde() : WorldScript("solazeroth_histoire_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        if (QueryResult r = WorldDatabase.Query("SELECT chapitre, quete, niveau, ilvl FROM solazeroth_histoire ORDER BY chapitre"))
            do
            {
                Field* f = r->Fetch();
                chapitres.push_back({ f[0].Get<uint8>(), f[1].Get<uint32>(), f[2].Get<uint8>(), f[3].Get<uint16>() });
            } while (r->NextRow());
        if (QueryResult r = WorldDatabase.Query("SELECT quete, temoin FROM solazeroth_histoire_temoins"))
            do
                temoins[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        LOG_INFO("module", "Sol'Azeroth histoire : {} chapitres, {} quêtes témoins", chapitres.size(), temoins.size());
    }
};

void AddSC_solazeroth_histoire()
{
    new npc_solazeroth_chroniqueur();
    new solazeroth_histoire_joueur();
    new solazeroth_histoire_monde();
}
