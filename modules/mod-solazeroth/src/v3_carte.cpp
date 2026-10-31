// v3 (31/10/2026) : les quêtes qu'on peut prendre, sur la carte du monde (demande de l'utilisateur : la quête de
// Hana'zua passait inaperçue). Pour la carte où se trouve le joueur, le serveur cherche les quêtes que le personnage
// peut accepter maintenant (Player::CanTakeQuest : niveau, classe, race, quête précédente, réputation…) et la position
// de chaque PNJ ou objet qui les donne, dans la phase du joueur. Relu toutes les RELECTURE ms ; la liste n'est
// renvoyée que si elle a changé (quête prise ou rendue, niveau gagné, changement de carte).
// Messages d'addon SOLQDISPO (SolUI_Quetes.lua) : « DEBUT;carte », puis « Q;quête;niveau;x;y;titre » (position en mètres
// du jeu), puis « FIN ».

#include "SolAzeroth.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <functional>
#include <unordered_map>
#include <vector>

namespace
{
    char const* const PREFIXE = "SOLQDISPO";
    uint32 const RELECTURE = 3000;

    struct Donneur
    {
        uint32 quete;
        float x, y;
        uint32 phases;
    };

    std::unordered_map<uint32, std::vector<Donneur>> donneurs;   // carte -> donneurs de quête

    struct Suivi : DataMap::Base
    {
        uint32 attente = 0;
        size_t empreinte = 0;
    };

    void Ajouter(QuestRelations const& relations, uint32 entree, SpawnData const& lieu)
    {
        auto [debut, fin] = relations.equal_range(entree);
        for (auto it = debut; it != fin; ++it)
            donneurs[lieu.mapid].push_back({ it->second, lieu.posX, lieu.posY, lieu.phaseMask });
    }

    void Envoyer(Player* player, Suivi* suivi)
    {
        std::vector<std::string> lignes;
        std::string tout;
        if (auto it = donneurs.find(player->GetMapId()); it != donneurs.end())
            for (Donneur const& d : it->second)
            {
                Quest const* quete = sObjectMgr->GetQuestTemplate(d.quete);
                if (!quete || !(d.phases & player->GetPhaseMask()) || !player->CanTakeQuest(quete, false))
                    continue;
                std::string titre = quete->GetTitle();
                if (QuestLocale const* l = sObjectMgr->GetQuestLocale(d.quete))
                    ObjectMgr::GetLocaleString(l->Title, LOCALE_frFR, titre);
                int32 niveau = quete->GetQuestLevel() > 0 ? quete->GetQuestLevel() : int32(quete->GetMinLevel());
                lignes.push_back(Acore::StringFormat("Q;{};{};{};{};{}", d.quete, niveau, int32(d.x), int32(d.y),
                    titre.substr(0, 120)));
                tout += lignes.back();
            }
        size_t empreinte = std::hash<std::string>{}(tout) ^ player->GetMapId();
        if (empreinte == suivi->empreinte)
            return;
        suivi->empreinte = empreinte;
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("DEBUT;{}", player->GetMapId()));
        for (std::string const& ligne : lignes)
            SolAzeroth::EnvoyerAddon(player, PREFIXE, ligne);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "FIN");
    }
}

class solazeroth_v3_carte_joueur : public PlayerScript
{
public:
    solazeroth_v3_carte_joueur() : PlayerScript("solazeroth_v3_carte_joueur", { PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Suivi* suivi = player->CustomData.GetDefault<Suivi>("solazeroth_v3_carte");
        if (suivi->attente > diff)
        {
            suivi->attente -= diff;
            return;
        }
        suivi->attente = RELECTURE;
        if (player->IsInWorld())
            Envoyer(player, suivi);
    }
};

class solazeroth_v3_carte_monde : public WorldScript
{
public:
    solazeroth_v3_carte_monde() : WorldScript("solazeroth_v3_carte_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        donneurs.clear();
        for (auto const& [guid, lieu] : sObjectMgr->GetAllCreatureData())
            Ajouter(*sObjectMgr->GetCreatureQuestRelationMap(), lieu.id, lieu);
        for (auto const& [guid, lieu] : sObjectMgr->GetAllGOData())
            Ajouter(*sObjectMgr->GetGOQuestRelationMap(), lieu.id, lieu);
        size_t total = 0;
        for (auto const& [carte, liste] : donneurs)
            total += liste.size();
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} donneurs de quête placés sur la carte", total);
    }
};

void AddSC_solazeroth_v3_carte()
{
    new solazeroth_v3_carte_joueur();
    new solazeroth_v3_carte_monde();
}
