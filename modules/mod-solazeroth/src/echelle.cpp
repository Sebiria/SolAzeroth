// Mise à l'échelle du monde avec retard (section 9.1, V8 ; décisions de l'utilisateur du 29/10/2026).
// Option par personnage, désactivée par défaut (page Réglages > Monde de /sol, commande .solechelle). Activée, hors
// instance, tout monstre plus bas que le niveau du joueur moins 2 ou 3 (selon le monstre) remonte à ce niveau : le jeu
// recalcule alors sa vie, ses dégâts et son armure, et l'XP qu'il rapporte. Jamais vers le bas : un monstre plus fort
// le reste. Exclus : PNJ de service, gardes, civils, déclencheurs, bestioles, boss de monde, familiers des joueurs et
// tout ce qui est amical. Les quêtes trop basses rapportent l'XP d'une quête de ce niveau (l'or des quêtes suit déjà
// le niveau du joueur dans le jeu).
// - À l'apparition, le niveau est choisi d'après le joueur le plus proche qui a l'option (OnBeforeCreatureSelectLevel).
// - Toutes les 3 s, les monstres déjà présents à 200 m sont mis à jour (option changée, montée de niveau), seulement
//   hors combat, en pleine santé et hors de la vue du joueur : le jeu montrerait sinon l'animation de gain de niveau.
//   Ceux qu'on a remontés reviennent à leur niveau quand l'option est coupée, eux aussi hors de vue.
// - Un monstre qui réapparaît sous les yeux du joueur garde son niveau, pour la même raison.
// - Or et sorts suivent : l'or ramassé sur un monstre remonté est multiplié par le rapport entre l'or moyen des monstres
//   normaux de son nouveau niveau et de son niveau d'origine ; ses sorts (dégâts directs, sur la durée, soins) par le
//   rapport des dégâts de base de ces deux niveaux, comme sa mêlée. Les sorts à dégâts d'arme suivent déjà la mêlée.
// Addon : « 1 » ou « 0 » (préfixe SolAzerothEchelle).

#include "SolAzeroth.h"
#include "CellImpl.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GridNotifiersImpl.h"
#include "LootMgr.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "SpellInfo.h"
#include "Map.h"
#include "Player.h"
#include "DBCStores.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include <array>
#include <list>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SolAzerothEchelle";
    float const PORTEE = 200.0f;

    struct Option : DataMap::Base
    {
        bool actif = false;
        uint32 attente = 0;
    };

    // Marque d'un monstre remonté, pour le ramener à son niveau quand l'option est coupée.
    struct Remonte : DataMap::Base
    {
        bool oui = false;
        uint8 origine = 0;
    };

    // Rapport des dégâts de base entre le niveau actuel d'un monstre remonté et son niveau d'origine (1 sinon).
    float Rapport(Unit* u)
    {
        Creature* c = u ? u->ToCreature() : nullptr;
        if (!c)
            return 1.0f;
        Remonte* marque = c->CustomData.Get<Remonte>("solazeroth_echelle");
        if (!marque || !marque->oui || !marque->origine || marque->origine >= c->GetLevel())
            return 1.0f;
        CreatureTemplate const* modele = c->GetCreatureTemplate();
        float avant = sObjectMgr->GetCreatureBaseStats(marque->origine, modele->unit_class)->BaseDamage[modele->expansion];
        float apres = sObjectMgr->GetCreatureBaseStats(c->GetLevel(), modele->unit_class)->BaseDamage[modele->expansion];
        return avant > 0.0f && apres > avant ? apres / avant : 1.0f;
    }

    // Les dégâts d'arme suivent déjà la mêlée du monstre.
    bool DegatsArme(SpellInfo const* sort)
    {
        return sort && (sort->HasEffect(SPELL_EFFECT_WEAPON_DAMAGE) || sort->HasEffect(SPELL_EFFECT_NORMALIZED_WEAPON_DMG)
            || sort->HasEffect(SPELL_EFFECT_WEAPON_PERCENT_DAMAGE) || sort->HasEffect(SPELL_EFFECT_WEAPON_DAMAGE_NOSCHOOL));
    }

    // Or moyen des monstres normaux par niveau (calculé une fois, d'après creature_template ; trous comblés).
    std::array<float, DEFAULT_MAX_LEVEL + 1> const& OrMoyen()
    {
        static std::array<float, DEFAULT_MAX_LEVEL + 1> const moyen = []
        {
            std::array<float, DEFAULT_MAX_LEVEL + 1> somme{}, nombre{}, m{};
            for (auto const& [entree, modele] : *sObjectMgr->GetCreatureTemplates())
            {
                uint32 niveau = (modele.minlevel + modele.maxlevel) / 2;
                if (modele.rank != CREATURE_ELITE_NORMAL || !modele.maxgold || niveau < 1 || niveau > DEFAULT_MAX_LEVEL)
                    continue;
                somme[niveau] += (modele.mingold + modele.maxgold) / 2.0f;
                nombre[niveau] += 1.0f;
            }
            float dernier = 0.0f;
            for (uint32 n = 1; n <= DEFAULT_MAX_LEVEL; ++n)
                m[n] = dernier = nombre[n] > 0.0f ? std::max(somme[n] / nombre[n], dernier) : dernier;
            return m;
        }();
        return moyen;
    }

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
            if (Player* p = ref.GetSource(); p && Actif(p))   // pas IsInWorld : la grille se charge avant l'entrée du joueur
                if (float d = c->GetExactDist2d(p); d < meilleure)
                {
                    meilleure = d;
                    proche = p;
                }
        return proche;
    }

    // Un joueur de la carte voit-il ce monstre ? Changer son niveau montrerait alors l'animation de gain de niveau.
    bool Vu(Creature* c)
    {
        for (auto const& ref : c->GetMap()->GetPlayers())
            if (Player* p = ref.GetSource(); p && p->HaveAtClient(c))
                return true;
        return false;
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
            if (!c || !c->IsAlive() || c->IsInCombat() || !c->IsFullHealth() || c->IsInEvadeMode() || Vu(c))
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
        Remonte* actuel = c->CustomData.Get<Remonte>("solazeroth_echelle");
        if (c->IsInWorld() && Vu(c))
        {
            // Réapparition sous les yeux du joueur : un monstre remonté garde son niveau, les autres font comme d'habitude.
            if (actuel && actuel->oui)
                niveau = c->GetLevel();
            return;
        }
        uint8 cible = Cible(c, JoueurProche(c));
        bool remonte = cible && niveau < cible;
        if (remonte || actuel)
        {
            Remonte* marque = c->CustomData.GetDefault<Remonte>("solazeroth_echelle");
            marque->oui = remonte;
            marque->origine = niveau;
        }
        if (remonte)
            niveau = cible;
    }
};

class solazeroth_echelle_joueur : public PlayerScript
{
public:
    solazeroth_echelle_joueur() : PlayerScript("solazeroth_echelle_joueur", {
        PLAYERHOOK_ON_LOAD_FROM_DB, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_LEVEL_CHANGED, PLAYERHOOK_ON_QUEST_COMPUTE_EXP,
        PLAYERHOOK_ON_BEFORE_LOOT_MONEY }) { }

    // Lu avant l'entrée dans le monde : les monstres chargés autour du joueur apparaissent déjà à son niveau.
    void OnPlayerLoadFromDB(Player* player) override
    {
        bool actif = false;
        if (QueryResult r = CharacterDatabase.Query("SELECT actif FROM solazeroth_echelle WHERE guid = {}", player->GetGUID().GetCounter()))
            actif = (*r)[0].Get<uint8>() != 0;
        player->CustomData.GetDefault<Option>("solazeroth_echelle")->actif = actif;
    }

    void OnPlayerLogin(Player* player) override
    {
        if (Actif(player))
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

    // Or d'un monstre remonté : celui d'un monstre normal de son nouveau niveau.
    void OnPlayerBeforeLootMoney(Player* player, Loot* loot) override
    {
        if (!loot->gold || !player->GetLootGUID().IsCreatureOrVehicle())
            return;
        Creature* c = ObjectAccessor::GetCreature(*player, player->GetLootGUID());
        Remonte* marque = c ? c->CustomData.Get<Remonte>("solazeroth_echelle") : nullptr;
        if (!marque || !marque->oui || !marque->origine || c->GetLevel() > DEFAULT_MAX_LEVEL)
            return;
        auto const& moyen = OrMoyen();
        float avant = moyen[marque->origine];
        float apres = moyen[c->GetLevel()];
        if (avant > 0.0f && apres > avant)
            loot->gold = uint32(loot->gold * apres / avant);
    }
};

// Sorts d'un monstre remonté : dégâts et soins au même rapport que sa mêlée.
class solazeroth_echelle_sorts : public UnitScript
{
public:
    solazeroth_echelle_sorts() : UnitScript("solazeroth_echelle_sorts", true, {
        UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK, UNITHOOK_MODIFY_HEAL_RECEIVED }) { }

    void ModifySpellDamageTaken(Unit* /*cible*/, Unit* attaquant, int32& degats, SpellInfo const* sort) override
    {
        if (degats > 0 && !DegatsArme(sort))
            degats = int32(degats * Rapport(attaquant));
    }

    void ModifyPeriodicDamageAurasTick(Unit* /*cible*/, Unit* attaquant, uint32& degats, SpellInfo const* sort) override
    {
        if (!DegatsArme(sort))
            degats = uint32(degats * Rapport(attaquant));
    }

    void ModifyHealReceived(Unit* /*cible*/, Unit* soigneur, uint32& soin, SpellInfo const* /*sort*/) override
    {
        soin = uint32(soin * Rapport(soigneur));
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
            ? "|cffffd100Monstres à ton niveau : activé.|r Les monstres plus faibles remontent à ton niveau moins 2 ou 3 dès qu'ils sont hors de ta vue."
            : "Monstres à ton niveau : désactivé. Les monstres reprennent leur niveau d'origine dès qu'ils sont hors de ta vue.");
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
    new solazeroth_echelle_sorts();
    new solazeroth_echelle_commandes();
}
