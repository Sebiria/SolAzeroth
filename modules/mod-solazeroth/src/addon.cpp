// Envoi d'un message d'addon au joueur (chuchotement en langue « addon » à lui-même), commun aux addons Sol'Azeroth.

#include "SolAzeroth.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include <cstdlib>
#include <map>
#include <set>
#include <sstream>
#include <vector>

using namespace Acore::ChatCommands;

void SolAzeroth::EnvoyerAddon(Player* player, std::string const& prefixe, std::string const& message)
{
    std::string complet = prefixe + "\t" + message;
    WorldPacket data(SMSG_MESSAGECHAT, 100);
    data << uint8(CHAT_MSG_WHISPER);
    data << int32(LANG_ADDON);
    data << player->GetGUID();
    data << uint32(0);
    data << player->GetGUID();
    data << uint32(complet.length() + 1);
    data << complet;
    data << uint8(0);
    player->GetSession()->SendPacket(&data);
}

// Monstres encore utiles aux quêtes du journal : « .solcibles » répond « DEBUT », des « nom;nom… », puis « FIN »
// (préfixe SolAzerothCibles). Ceux à tuer (crédit de mort compris) tant que le compteur n'est pas plein, et ceux
// qui lâchent un objet de quête qui manque encore. Les plaques de nom les marquent (SolAzerothPlaques).
namespace
{
    // Créature -> créatures qui lui donnent son crédit de mort (KillCredit), construit une fois.
    std::map<uint32, std::vector<uint32>> const& DonneursDeCredit()
    {
        static std::map<uint32, std::vector<uint32>> donneurs;
        static bool construit = false;
        if (!construit)
        {
            for (auto const& [entree, modele] : *sObjectMgr->GetCreatureTemplates())
                for (uint32 credit : modele.KillCredit)
                    if (credit)
                        donneurs[credit].push_back(entree);
            construit = true;
        }
        return donneurs;
    }

    // Objet -> créatures qui le lâchent (table de butin directe), gardé après la première demande.
    std::vector<uint32> const& Porteurs(uint32 objet)
    {
        static std::map<uint32, std::vector<uint32>> cache;
        auto it = cache.find(objet);
        if (it != cache.end())
            return it->second;
        std::vector<uint32>& liste = cache[objet];
        if (QueryResult r = WorldDatabase.Query("SELECT DISTINCT ct.entry FROM creature_loot_template l "
            "JOIN creature_template ct ON ct.lootid = l.Entry WHERE l.Item = {} AND l.Reference = 0 LIMIT 80", objet))
            do liste.push_back((*r)[0].Get<uint32>()); while (r->NextRow());
        return liste;
    }
}

// Noms des objets dans la langue du joueur : « .solnoms 862,2564,… » répond « id:nom;id:nom… » (préfixe SolAzerothNoms).
// Le client ne connaît le nom d'un objet qu'après l'avoir demandé au serveur, un par un ; les addons affichaient
// alors « Objet 862 ». Ils demandent maintenant tous les noms manquants d'un coup.
class solazeroth_addon_commandes : public CommandScript
{
public:
    solazeroth_addon_commandes() : CommandScript("solazeroth_addon_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "solnoms", HandleNoms, SEC_PLAYER, Console::No },
            { "solcibles", HandleCibles, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    static bool HandleNoms(ChatHandler* handler, Tail liste)
    {
        Player* player = handler->GetSession()->GetPlayer();
        LocaleConstant langue = handler->GetSession()->GetSessionDbLocaleIndex();
        std::string paquet;
        std::stringstream flux{ std::string(liste) };
        std::string morceau;
        while (std::getline(flux, morceau, ','))
        {
            uint32 id = uint32(std::strtoul(morceau.c_str(), nullptr, 10));
            ItemTemplate const* modele = id ? sObjectMgr->GetItemTemplate(id) : nullptr;
            if (!modele)
                continue;
            std::string nom = modele->Name1;
            if (ItemLocale const* traduction = sObjectMgr->GetItemLocale(id))
                ObjectMgr::GetLocaleString(traduction->Name, langue, nom);
            std::string element = std::to_string(id) + ":" + nom;
            if (paquet.size() + element.size() + 1 > 220)
            {
                SolAzeroth::EnvoyerAddon(player, "SolAzerothNoms", paquet);
                paquet.clear();
            }
            paquet += (paquet.empty() ? "" : ";") + element;
        }
        if (!paquet.empty())
            SolAzeroth::EnvoyerAddon(player, "SolAzerothNoms", paquet);
        return true;
    }

    static bool HandleCibles(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        LocaleConstant langue = handler->GetSession()->GetSessionDbLocaleIndex();
        std::set<uint32> entrees;
        for (uint16 slot = 0; slot < MAX_QUEST_LOG_SIZE; ++slot)
        {
            uint32 id = player->GetQuestSlotQuestId(slot);
            Quest const* quete = id ? sObjectMgr->GetQuestTemplate(id) : nullptr;
            if (!quete || player->GetQuestStatus(id) != QUEST_STATUS_INCOMPLETE)
                continue;
            for (uint8 i = 0; i < QUEST_OBJECTIVES_COUNT; ++i)
            {
                int32 cible = quete->RequiredNpcOrGo[i];
                if (cible <= 0 || player->GetQuestSlotCounter(slot, i) >= quete->RequiredNpcOrGoCount[i])
                    continue;
                entrees.insert(uint32(cible));
                auto it = DonneursDeCredit().find(uint32(cible));
                if (it != DonneursDeCredit().end())
                    entrees.insert(it->second.begin(), it->second.end());
            }
            for (uint8 i = 0; i < QUEST_ITEM_OBJECTIVES_COUNT; ++i)
            {
                uint32 objet = quete->RequiredItemId[i];
                if (!objet || player->GetItemCount(objet, true) >= quete->RequiredItemCount[i])
                    continue;
                std::vector<uint32> const& porteurs = Porteurs(objet);
                entrees.insert(porteurs.begin(), porteurs.end());
            }
        }

        std::set<std::string> noms;
        for (uint32 entree : entrees)
            if (CreatureTemplate const* modele = sObjectMgr->GetCreatureTemplate(entree))
            {
                std::string nom = modele->Name;
                if (CreatureLocale const* traduction = sObjectMgr->GetCreatureLocale(entree))
                    ObjectMgr::GetLocaleString(traduction->Name, langue, nom);
                noms.insert(nom);
            }

        SolAzeroth::EnvoyerAddon(player, "SolAzerothCibles", "DEBUT");
        std::string paquet;
        for (std::string const& nom : noms)
        {
            if (paquet.size() + nom.size() + 1 > 220)
            {
                SolAzeroth::EnvoyerAddon(player, "SolAzerothCibles", paquet);
                paquet.clear();
            }
            paquet += (paquet.empty() ? "" : ";") + nom;
        }
        if (!paquet.empty())
            SolAzeroth::EnvoyerAddon(player, "SolAzerothCibles", paquet);
        SolAzeroth::EnvoyerAddon(player, "SolAzerothCibles", "FIN");
        return true;
    }
};

void AddSC_solazeroth_addon()
{
    new solazeroth_addon_commandes();
}
