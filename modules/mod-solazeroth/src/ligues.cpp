// Ligues Remix et Chaos (section 3.3, V8 ; décisions de l'utilisateur du 30/10/2026). Choisies au niveau 1 dans la
// fenêtre des défis (lua_scripts/defis.lua, réglages 4 et 5 de la source « solazeroth-defis »), comme Destin.
// - Remix : monde à ton niveau imposé (echelle.cpp, l'option ne se coupe pas), XP ×2, et chaque niveau donne
//   1 % de dégâts et de vie en plus (cumulés : +80 % au niveau 80).
// - Chaos : chaque jour (minuit, heure du serveur), une mutation tirée au sort pour ce personnage s'applique : dégâts,
//   soins, XP, or ou une école de magie renforcée. Annoncée à la connexion et au changement de jour, et par .solchaos.
// Addon : « CHAOS;nom;règle » (préfixe SOLDEFI), sur demande « .solchaos etat ».

#include "SolAzeroth.h"
#include "Chat.h"
#include "Creature.h"
#include "LootMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "Timer.h"
#include "GameTime.h"

using namespace Acore::ChatCommands;

namespace
{
    char const* const SOURCE = "solazeroth-defis";
    uint8 const REGLAGE_REMIX = 4;
    uint8 const REGLAGE_CHAOS = 5;
    float const REMIX_XP = 2.0f;
    float const REMIX_PAR_NIVEAU = 1.0f;   // % de dégâts et de vie par niveau

    struct Mutation
    {
        char const* nom;
        char const* regle;
        float infliges = 1.0f;
        float subis = 1.0f;
        float soins = 1.0f;
        float xp = 1.0f;
        float or_ = 1.0f;
        uint32 ecole = 0;        // masque d'école renforcée de 50 %, pour le joueur comme pour les monstres
    };

    // Une dizaine de mutations, certaines favorables, d'autres non (valeurs provisoires).
    Mutation const MUTATIONS[] =
    {
        { "Furie",       "Tu infliges et tu subis 25 % de dégâts en plus.",               1.25f, 1.25f },
        { "Fragilité",   "Tu subis 20 % de dégâts en plus.",                               1.0f,  1.2f },
        { "Puissance",   "Tu infliges 20 % de dégâts en plus.",                            1.2f },
        { "Rempart",     "Tu infliges et tu subis 20 % de dégâts en moins.",               0.8f,  0.8f },
        { "Soins taris", "Les soins que tu reçois sont réduits de 30 %.",                  1.0f,  1.0f, 0.7f },
        { "Bénédiction", "Les soins que tu reçois sont augmentés de 30 %.",                1.0f,  1.0f, 1.3f },
        { "Savoir",      "Expérience gagnée ×1,5.",                                        1.0f,  1.0f, 1.0f, 1.5f },
        { "Fortune",     "Or ramassé sur les monstres ×2.",                                1.0f,  1.0f, 1.0f, 1.0f, 2.0f },
        { "Embrasement", "Les dégâts de feu (les tiens et ceux des monstres) font 50 % de plus.", 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, SPELL_SCHOOL_MASK_FIRE },
        { "Grand froid", "Les dégâts de givre (les tiens et ceux des monstres) font 50 % de plus.", 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, SPELL_SCHOOL_MASK_FROST },
        { "Ténèbres",    "Les dégâts d'ombre (les tiens et ceux des monstres) font 50 % de plus.", 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, SPELL_SCHOOL_MASK_SHADOW },
    };
    uint32 const NOMBRE = sizeof(MUTATIONS) / sizeof(MUTATIONS[0]);

    struct Etat : DataMap::Base
    {
        uint32 jour = 0;          // jour de la dernière annonce Chaos
        uint32 attente = 0;
        float vieRemix = 0.0f;    // % de vie Remix appliqué
    };

    bool Reglage(Player* p, uint8 index)
    {
        return p && p->GetPlayerSetting(SOURCE, index).value == 1;
    }

    uint32 Jour()
    {
        std::tm t = Acore::Time::TimeBreakdown(GameTime::GetGameTime().count());
        return uint32(t.tm_year) * 1000 + uint32(t.tm_yday);
    }

    // Mutation du jour de ce personnage, ou nullptr s'il n'est pas en ligue Chaos.
    Mutation const* MutationDe(Player* p)
    {
        if (!Reglage(p, REGLAGE_CHAOS))
            return nullptr;
        uint32 h = p->GetGUID().GetCounter() * 2654435761u ^ Jour() * 40503u;
        h ^= h >> 15;
        h *= 2246822519u;
        h ^= h >> 13;
        return &MUTATIONS[h % NOMBRE];
    }

    Player* JoueurDe(Unit* u)
    {
        return u ? u->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
    }

    // Multiplicateur des dégâts d'attaquant sur cible (mêlée si sort nul).
    float Degats(Unit* cible, Unit* attaquant, SpellInfo const* sort)
    {
        float f = 1.0f;
        Player* auteur = JoueurDe(attaquant);
        if (Reglage(auteur, REGLAGE_REMIX))
            f *= 1.0f + REMIX_PAR_NIVEAU * auteur->GetLevel() / 100.0f;
        Mutation const* mA = MutationDe(auteur);
        Mutation const* mC = cible && cible->IsPlayer() ? MutationDe(cible->ToPlayer()) : nullptr;
        if (mA)
            f *= mA->infliges;
        if (mC)
            f *= mC->subis;
        if (sort)
            for (Mutation const* m : { mA, mC })
                if (m && m->ecole && (sort->GetSchoolMask() & m->ecole))
                {
                    f *= 1.5f;
                    break;
                }
        return f;
    }

    void AppliquerVieRemix(Player* p)
    {
        Etat* e = p->CustomData.GetDefault<Etat>("solazeroth_ligues");
        float voulu = Reglage(p, REGLAGE_REMIX) ? REMIX_PAR_NIVEAU * p->GetLevel() : 0.0f;
        if (voulu == e->vieRemix)
            return;
        if (e->vieRemix > 0.0f)   // retire l'ancien bonus : (1 + a)(1 + b) = 1
            p->ApplyStatPctModifier(UNIT_MOD_HEALTH, TOTAL_PCT, (1.0f / (1.0f + e->vieRemix / 100.0f) - 1.0f) * 100.0f);
        if (voulu > 0.0f)
            p->ApplyStatPctModifier(UNIT_MOD_HEALTH, TOTAL_PCT, voulu);
        e->vieRemix = voulu;
    }

    void Annoncer(Player* p, bool discret)
    {
        Mutation const* m = MutationDe(p);
        if (!m)
            return;
        SolAzeroth::EnvoyerAddon(p, "SOLDEFI", std::string("CHAOS;") + m->nom + ";" + m->regle);
        if (!discret)
            ChatHandler(p->GetSession()).PSendSysMessage("|cffff8000Mutation du jour (Chaos) : {}.|r {}", m->nom, m->regle);
    }
}

bool SolAzeroth::EstRemix(Player* player)
{
    return Reglage(player, REGLAGE_REMIX);
}

class solazeroth_ligues_unites : public UnitScript
{
public:
    solazeroth_ligues_unites() : UnitScript("solazeroth_ligues_unites", true, {
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK,
        UNITHOOK_MODIFY_HEAL_RECEIVED }) { }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override
    {
        degats = uint32(degats * Degats(cible, attaquant, nullptr));
    }

    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* sort) override
    {
        if (degats > 0)
            degats = int32(degats * Degats(cible, attaquant, sort));
    }

    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* sort) override
    {
        degats = uint32(degats * Degats(cible, attaquant, sort));
    }

    void ModifyHealReceived(Unit* cible, Unit* /*soigneur*/, uint32& soin, SpellInfo const* /*sort*/) override
    {
        if (Mutation const* m = cible && cible->IsPlayer() ? MutationDe(cible->ToPlayer()) : nullptr)
            soin = uint32(soin * m->soins);
    }
};

class solazeroth_ligues_joueur : public PlayerScript
{
public:
    solazeroth_ligues_joueur() : PlayerScript("solazeroth_ligues_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_LEVEL_CHANGED, PLAYERHOOK_ON_GIVE_EXP,
        PLAYERHOOK_ON_BEFORE_LOOT_MONEY }) { }

    void OnPlayerLogin(Player* player) override
    {
        AppliquerVieRemix(player);
        player->CustomData.GetDefault<Etat>("solazeroth_ligues")->jour = Jour();
        Annoncer(player, false);
    }

    // Chaque minute : changement de jour (nouvelle mutation) et ligue choisie depuis la connexion.
    void OnPlayerUpdate(Player* player, uint32 ecoule) override
    {
        Etat* e = player->CustomData.GetDefault<Etat>("solazeroth_ligues");
        e->attente += ecoule;
        if (e->attente < MINUTE * IN_MILLISECONDS)
            return;
        e->attente = 0;
        AppliquerVieRemix(player);
        if (uint32 jour = Jour(); jour != e->jour)
        {
            e->jour = jour;
            Annoncer(player, false);
        }
    }

    void OnPlayerLevelChanged(Player* player, uint8 /*ancien*/) override
    {
        AppliquerVieRemix(player);
    }

    void OnPlayerGiveXP(Player* player, uint32& xp, Unit* /*victime*/, uint8 /*source*/) override
    {
        float f = Reglage(player, REGLAGE_REMIX) ? REMIX_XP : 1.0f;
        if (Mutation const* m = MutationDe(player))
            f *= m->xp;
        if (f != 1.0f)
            xp = uint32(xp * f);
    }

    void OnPlayerBeforeLootMoney(Player* player, Loot* loot) override
    {
        if (Mutation const* m = MutationDe(player); m && m->or_ != 1.0f && player->GetLootGUID().IsCreatureOrVehicle())
            loot->gold = uint32(loot->gold * m->or_);
    }
};

class solazeroth_ligues_commandes : public CommandScript
{
public:
    solazeroth_ligues_commandes() : CommandScript("solazeroth_ligues_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "solchaos", HandleChaos, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    // .solchaos : annonce la mutation du jour ; « .solchaos etat » : seulement pour l'addon.
    static bool HandleChaos(ChatHandler* handler, Optional<std::string> action)
    {
        Player* player = handler->GetPlayer();
        if (!MutationDe(player))
        {
            if (!action)
                handler->SendSysMessage("Ce personnage n'est pas en ligue Chaos.");
            return true;
        }
        Annoncer(player, action.has_value());
        return true;
    }
};

void AddSC_solazeroth_ligues()
{
    new solazeroth_ligues_unites();
    new solazeroth_ligues_joueur();
    new solazeroth_ligues_commandes();
}
