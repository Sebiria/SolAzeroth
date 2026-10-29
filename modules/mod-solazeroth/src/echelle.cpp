// Mise à l'échelle du monde avec retard (section 9.1, V8 ; décisions de l'utilisateur du 29/10/2026).
// Option par personnage, désactivée par défaut (page Réglages > Monde de /sol, commande .solechelle). Activée, hors
// instance, tout monstre plus bas que le niveau du joueur moins 2 ou 3 (selon le monstre) remonte à ce niveau : le jeu
// recalcule alors sa vie, ses dégâts et son armure, et l'XP qu'il rapporte. Jamais vers le bas : un monstre plus fort
// le reste. Exclus : PNJ de service, gardes, civils, déclencheurs, bestioles, boss de monde, familiers des joueurs et
// tout ce qui est amical. Les quêtes trop basses rapportent l'XP d'une quête de ce niveau (l'or des quêtes suit déjà
// le niveau du joueur dans le jeu).
// - À l'apparition, le niveau est choisi d'après le joueur le plus proche qui a l'option (OnBeforeCreatureSelectLevel).
// - Toutes les 3 s, les monstres déjà présents à 100 m sont mis à jour (option changée, montée de niveau), seulement
//   hors combat et en pleine santé. Ceux qu'on a remontés reviennent à leur niveau quand l'option est coupée.
// Addon : « 1 » ou « 0 » (préfixe SolAzerothEchelle).

#include "SolAzeroth.h"
#include "CellImpl.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GridNotifiersImpl.h"
#include "Map.h"
#include "Player.h"
#include "DBCStores.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include <list>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SolAzerothEchelle";
    float const PORTEE = 100.0f;

    struct Option : DataMap::Base
    {
        bool actif = false;
        uint32 attente = 0;
    };

    // Marque d'un monstre remonté, pour le ramener à son niveau quand l'option est coupée.
    struct Remonte : DataMap::Base
    {
        bool oui = false;
    };

    bool Actif(Player* player)
    {
        Option* o = player->CustomData.Get<Option>("solazeroth_echelle");
        return o && o->actif;
    }

    bool Admissible(Creature* c, Player* player)
    {
        CreatureTemplate const* modele = c->GetCreatureTemplate();
        if (!modele || c->FindMap() == nullptr || c->FindMap()->Instanceable())
            return false;
        if (c->IsCharmedOwnedByPlayerOrPlayer() || c->IsTotem() || modele->npcflag)
            return false;
        if (modele->HasFlagsExtra(CREATURE_FLAG_EXTRA_GUARD | CREATURE_FLAG_EXTRA_CIVILIAN | CREATURE_FLAG_EXTRA_TRIGGER))
            return false;
        if (modele->rank == CREATURE_ELITE_WORLDBOSS || modele->type == CREATURE_TYPE_CRITTER)
            return false;
        return !c->IsFriendlyTo(player);
    }

    // Niveau voulu pour ce monstre face à ce joueur, ou 0 s'il garde le sien. Retard de 2 ou 3 niveaux, fixe par monstre.
    uint8 Cible(Creature* c, Player* player)
    {
        if (!player || !Actif(player) || !Admissible(c, player))
            return 0;
        uint8 retard = 2 + c->GetSpawnId() % 2;
        if (player->GetLevel() <= retard)
            return 0;
        uint8 cible = player->GetLevel() - retard;
        return cible > c->GetCreatureTemplate()->maxlevel ? cible : 0;
    }

    Player* JoueurProche(Creature* c)
    {
        Map* map = c->FindMap();
        if (!map)
            return nullptr;
        Player* proche = nullptr;
        float meilleure = 250.0f;
        for (auto const& ref : map->GetPlayers())
            if (Player* p = ref.GetSource(); p && p->IsInWorld() && Actif(p))
                if (float d = c->GetExactDist2d(p); d < meilleure)
                {
                    meilleure = d;
                    proche = p;
                }
        return proche;
    }

    // XP d'une quête d'un niveau donné pour un joueur, comme Quest::XPValue, sans arrondi.
    float XPBrute(Quest const* quete, int32 niveauQuete, uint8 niveauJoueur)
    {
        QuestXPEntry const* entree = sQuestXPStore.LookupEntry(niveauQuete);
        if (!entree || quete->GetXPId() >= 10)
            return 0.0f;
        int32 facteur = std::clamp(2 * (niveauQuete - int32(niveauJoueur)) + 20, 1, 10);
        return facteur * entree->Exp[quete->GetXPId()] / 10.0f;
    }

    void EnvoyerEtat(Player* player)
    {
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Actif(player) ? "1" : "0");
    }

    // Met à jour les monstres déjà présents autour du joueur.
    void Balayer(Player* player)
    {
        if (player->GetMap()->Instanceable())
            return;
        std::list<Unit*> unites;
        Acore::AnyUnfriendlyUnitInObjectRangeCheck verif(player, player, PORTEE);
        Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck> chercheur(player, unites, verif);
        Cell::VisitObjects(player, chercheur, PORTEE);
        for (Unit* u : unites)
        {
            Creature* c = u->ToCreature();
            if (!c || !c->IsAlive() || c->IsInCombat() || !c->IsFullHealth() || c->IsInEvadeMode())
                continue;
            uint8 cible = Cible(c, player);
            Remonte* marque = c->CustomData.Get<Remonte>("solazeroth_echelle");
            bool remonte = marque && marque->oui;
            if ((cible && c->GetLevel() < cible) || (!cible && remonte))
            {
                c->SelectLevel();
                c->UpdateAllStats();
            }
        }
    }
}

class solazeroth_echelle_creature : public AllCreatureScript
{
public:
    solazeroth_echelle_creature() : AllCreatureScript("solazeroth_echelle_creature") { }

    void OnBeforeCreatureSelectLevel(CreatureTemplate const* /*modele*/, Creature* c, uint8& niveau) override
    {
        uint8 cible = Cible(c, JoueurProche(c));
        bool remonte = cible && niveau < cible;
        if (remonte)
            niveau = cible;
        if (remonte || c->CustomData.Get<Remonte>("solazeroth_echelle"))
            c->CustomData.GetDefault<Remonte>("solazeroth_echelle")->oui = remonte;
    }
};

class solazeroth_echelle_joueur : public PlayerScript
{
public:
    solazeroth_echelle_joueur() : PlayerScript("solazeroth_echelle_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_LEVEL_CHANGED, PLAYERHOOK_ON_QUEST_COMPUTE_EXP }) { }

    void OnPlayerLogin(Player* player) override
    {
        bool actif = false;
        if (QueryResult r = CharacterDatabase.Query("SELECT actif FROM solazeroth_echelle WHERE guid = {}", player->GetGUID().GetCounter()))
            actif = (*r)[0].Get<uint8>() != 0;
        player->CustomData.GetDefault<Option>("solazeroth_echelle")->actif = actif;
        if (actif)
            ChatHandler(player->GetSession()).SendSysMessage("|cffffd100Monstres à ton niveau : activé.|r");
    }

    // Balayage toutes les 3 s (aussi après coupure de l'option : il ramène les monstres remontés).
    void OnPlayerUpdate(Player* player, uint32 ecoule) override
    {
        Option* o = player->CustomData.GetDefault<Option>("solazeroth_echelle");
        o->attente += ecoule;
        if (o->attente < 3 * IN_MILLISECONDS)
            return;
        o->attente = 0;
        Balayer(player);
    }

    void OnPlayerLevelChanged(Player* player, uint8 /*ancien*/) override
    {
        player->CustomData.GetDefault<Option>("solazeroth_echelle")->attente = 3 * IN_MILLISECONDS;
    }

    // Quête trop basse : l'XP d'une quête du niveau des monstres (niveau du joueur moins 2).
    void OnPlayerQuestComputeXP(Player* player, Quest const* quete, uint32& xp) override
    {
        if (!xp || !Actif(player) || quete->GetQuestLevel() < 0 || player->GetLevel() <= 2)
            return;
        int32 niveau = player->GetLevel() - 2;
        if (quete->GetQuestLevel() >= niveau)
            return;
        float avant = XPBrute(quete, quete->GetQuestLevel(), player->GetLevel());
        float apres = XPBrute(quete, niveau, player->GetLevel());
        if (avant > 0.0f && apres > avant)
            xp = uint32(xp * apres / avant);
    }
};

class solazeroth_echelle_commandes : public CommandScript
{
public:
    solazeroth_echelle_commandes() : CommandScript("solazeroth_echelle_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "etat", HandleEtat,  SEC_PLAYER, Console::No },
            { "on",   HandleOui,   SEC_PLAYER, Console::No },
            { "off",  HandleNon,   SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solechelle", sousCommandes },
        };
        return commandes;
    }

    static bool HandleEtat(ChatHandler* handler)
    {
        EnvoyerEtat(handler->GetPlayer());
        return true;
    }

    static bool Changer(ChatHandler* handler, bool actif)
    {
        Player* player = handler->GetPlayer();
        Option* o = player->CustomData.GetDefault<Option>("solazeroth_echelle");
        o->actif = actif;
        o->attente = 3 * IN_MILLISECONDS;
        CharacterDatabase.DirectExecute("REPLACE INTO solazeroth_echelle (guid, actif) VALUES ({}, {})",
            player->GetGUID().GetCounter(), actif ? 1 : 0);
        handler->SendSysMessage(actif
            ? "|cffffd100Monstres à ton niveau : activé.|r Les monstres plus faibles remontent à ton niveau moins 2 ou 3."
            : "Monstres à ton niveau : désactivé. Les monstres reprennent leur niveau d'origine.");
        EnvoyerEtat(player);
        return true;
    }

    static bool HandleOui(ChatHandler* handler) { return Changer(handler, true); }
    static bool HandleNon(ChatHandler* handler) { return Changer(handler, false); }
};

void AddSC_solazeroth_echelle()
{
    new solazeroth_echelle_creature();
    new solazeroth_echelle_joueur();
    new solazeroth_echelle_commandes();
}
