// v3 (01/11/2026, proposition validée par l'utilisateur : « Réputation des donjons — proposition.md ») : passifs de
// donjon et du monde extérieur. Liste, numéros et chiffres : outils\passifs_v3.py (valeurs simulées par
// outils\simulation_donjons.py : chaque passif de combat vaut à peu près « + 5 % de puissance »).
// - Tous les passifs sont ouverts ; le joueur choisit lesquels mettre dans ses emplacements, au compte.
//   - Donjon : 6 emplacements, ouverts par les rangs 1, 2, 4, 6, 8 et 10 de la réputation des donjons (v3_donjons.cpp) ;
//     les passifs de donjon valent dans les instances. Ils se changent hors combat, hors d'une instance ou dans un
//     donjon avant le premier combat.
//   - Extérieur : 6 emplacements, ouverts par les paliers 2, 5, 9, 15, 23 et 31 du rang d'aventurier puis achetés en
//     Marques du voyageur (25, 50, 100, 175, 275, 400), dans l'ordre ; les passifs extérieurs valent hors des instances
//     et se changent dans une zone de repos (auberge, ville).
// - Effets ici : dégâts infligés et subis, vol de vie, Second souffle, Dernier rempart, Épines, Contre-attaque,
//   Instinct de fuite, régénérations, Fin de combat, Élan, Fin de traque, Pilleur de faille, Main vive, Tenace,
//   Gourmet, Marchandage, auras (Carrure, Cuirasse, Pas léger, Rôdeur). Ailleurs : Mauvais œil (v3_modes.cpp), Défi
//   tenu et Chasseur de primes (v3_annexes.cpp), Gorgée de plus et Veillée (v3_bivouac.cpp), Âme tenace (v3_ame.cpp),
//   Charognard, Éclats d'aventure, Cueilleur et Main experte (v3_collection.cpp), Foyer proche (v3_aventurier.cpp).
// - Commandes : .passif (état), .passif donjon|exterieur <emplacement 1-6> <passif|0>, .passif acheter.
// - Interface (SolUI_Passifs.lua, préfixe SOLPASSIF) : « ETAT;points;rang;emplacements donjon;emplacements extérieurs
//   ouverts;achetés;modifiable en donjon;modifiable dehors », « DONJON;p1;…;p6 », « EXT;p1;…;p6 », « FIN ».

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <algorithm>
#include <unordered_map>
#include <unordered_set>

using namespace Acore::ChatCommands;
using namespace SolAzeroth;

namespace
{
    uint8 const EMPLACEMENTS = 6;
    uint8 const RANGS_DONJON[EMPLACEMENTS] = { 1, 2, 4, 6, 8, 10 };
    uint8 const PALIERS_EXTERIEUR[EMPLACEMENTS] = { 2, 5, 9, 15, 23, 31 };
    uint32 const PRIX_EXTERIEUR[EMPLACEMENTS] = { 25, 50, 100, 175, 275, 400 };
    uint8 const DERNIER_DONJON = PILLEUR_DE_FAILLE, DERNIER_EXTERIEUR = MARCHANDAGE;

    uint32 const AURA_CARRURE = 100040, AURA_CUIRASSE = 100041, AURA_PAS_LEGER = 100042, AURA_FUITE = 100043,
        AURA_RODEUR = 100044;
    uint32 const PIERRE_DE_FOYER = 8690;
    uint32 const FISSURE = 900101, SPHERE = 900100;                                // v3_modes.cpp
    uint32 const CHEF_RENFORCE_PREMIER = 910010, CHEF_RENFORCE_DERNIER = 910014;   // migration 075
    uint32 const TICK = 1000;

    struct Choix
    {
        uint8 donjon[EMPLACEMENTS] = {};
        uint8 exterieur[EMPLACEMENTS] = {};
        uint8 achetes = 0;
    };
    std::unordered_map<uint32, Choix> comptes;
    std::unordered_set<uint32> sortsDesPlats;   // Gourmet

    struct Etat : DataMap::Base
    {
        uint64 actifs = 0;          // bit n : le passif n est dans un emplacement ouvert
        bool pret = false;
        uint32 attente = 0;
        std::string envoye;
        bool souffle = false;       // Second souffle pris pendant ce combat
        uint32 rempart = 0;         // instance où Dernier rempart a servi
        uint8 elan = 0;
        uint32 fuite = 0;           // heure (ms) où Instinct de fuite revient
    };

    Etat* EtatDe(Player* player) { return player->CustomData.GetDefault<Etat>("solazeroth_v3_passifs"); }
    uint32 CompteDe(Player* player) { return player->GetSession()->GetAccountId(); }

    Choix& ChoixDe(uint32 compte)
    {
        auto it = comptes.find(compte);
        if (it != comptes.end())
            return it->second;
        Choix& c = comptes[compte];
        if (QueryResult r = CharacterDatabase.Query("SELECT genre, emplacement, passif FROM solazeroth_v3_passifs "
            "WHERE compte = {}", compte))
        {
            do
            {
                Field* f = r->Fetch();
                uint8 emplacement = f[1].Get<uint8>();
                if (emplacement < EMPLACEMENTS)
                    (f[0].Get<uint8>() ? c.exterieur : c.donjon)[emplacement] = f[2].Get<uint8>();
            } while (r->NextRow());
        }
        if (QueryResult r = CharacterDatabase.Query("SELECT emplacements FROM solazeroth_v3_reputation WHERE compte = {}", compte))
            c.achetes = std::min<uint8>((*r)[0].Get<uint8>(), EMPLACEMENTS);
        return c;
    }

    uint8 EmplacementsDonjon(Player* player)
    {
        uint8 rang = RangReputation(player), n = 0;
        for (uint8 r : RANGS_DONJON)
            if (rang >= r)
                ++n;
        return n;
    }

    uint8 ExterieursOuverts(Player* player)
    {
        uint8 palier = PalierAventurier(player), n = 0;
        for (uint8 p : PALIERS_EXTERIEUR)
            if (palier >= p)
                ++n;
        return n;
    }

    uint8 EmplacementsExterieur(Player* player)
    {
        return std::min(ExterieursOuverts(player), ChoixDe(CompteDe(player)).achetes);
    }

    void Recalculer(Player* player)
    {
        Etat* e = EtatDe(player);
        Choix const& c = ChoixDe(CompteDe(player));
        e->actifs = 0;
        for (uint8 i = 0, n = EmplacementsDonjon(player); i < n; ++i)
            if (c.donjon[i])
                e->actifs |= uint64(1) << c.donjon[i];
        for (uint8 i = 0, n = EmplacementsExterieur(player); i < n; ++i)
            if (c.exterieur[i])
                e->actifs |= uint64(1) << c.exterieur[i];
        e->pret = true;
    }

    bool AuRepos(Player* player)
    {
        return player->HasRestFlag(REST_FLAG_IN_TAVERN) || player->HasRestFlag(REST_FLAG_IN_CITY);
    }

    // Passifs de donjon : hors combat, hors d'une instance ou dans un donjon avant le premier combat.
    bool ModifiableDonjon(Player* player)
    {
        Map* map = player->GetMap();
        if (player->IsInCombat())
            return false;
        return !map->Instanceable() || (map->IsNonRaidDungeon() && !DonjonVerrouille(map));
    }

    bool ModifiableExterieur(Player* player) { return !player->IsInCombat() && AuRepos(player); }

    void Envoyer(Player* player, bool force)
    {
        Etat* e = EtatDe(player);
        Choix const& c = ChoixDe(CompteDe(player));
        std::string etat = Acore::StringFormat("ETAT;{};{};{};{};{};{};{}", PointsReputation(player), uint32(RangReputation(player)),
            uint32(EmplacementsDonjon(player)), uint32(ExterieursOuverts(player)), uint32(c.achetes),
            ModifiableDonjon(player) ? 1 : 0, ModifiableExterieur(player) ? 1 : 0);
        std::string donjon = "DONJON", exterieur = "EXT";
        for (uint8 i = 0; i < EMPLACEMENTS; ++i)
        {
            donjon += ";" + std::to_string(c.donjon[i]);
            exterieur += ";" + std::to_string(c.exterieur[i]);
        }
        if (!force && etat + donjon + exterieur == e->envoye)
            return;
        e->envoye = etat + donjon + exterieur;
        for (std::string const& message : { etat, donjon, exterieur, std::string("FIN") })
            EnvoyerAddon(player, "SOLPASSIF", message);
    }

    void Synchroniser(Player* player, uint32 aura, bool voulue)
    {
        if (voulue && !player->HasAura(aura))
            player->AddAura(aura, player);
        else if (!voulue && player->HasAura(aura))
            player->RemoveAurasDueToSpell(aura);
    }

    bool ChefOuRare(Creature* creature)
    {
        uint32 rang = creature->GetCreatureTemplate()->rank;
        return rang == CREATURE_ELITE_ELITE || rang == CREATURE_ELITE_RARE || rang == CREATURE_ELITE_RAREELITE
            || (creature->GetEntry() >= CHEF_RENFORCE_PREMIER && creature->GetEntry() <= CHEF_RENFORCE_DERNIER);
    }

    float Inflige(Player* player, Creature* cible)
    {
        float f = 1.0f, vie = cible->GetHealthPct();
        if (vie < 35.0f && PassifActif(player, BOURREAU))
            f += 0.30f;
        if (vie > 80.0f && PassifActif(player, PREMIER_SANG))
            f += 0.50f;
        if (cible->IsDungeonBoss() && PassifActif(player, BRISE_CHEF))
            f += 0.10f;
        if (PassifActif(player, ELAN))
            f += 0.02f * EtatDe(player)->elan;
        if (PassifActif(player, FUREUR_DU_NOMBRE))
            f += 0.04f * std::min<size_t>(4, player->getAttackers().size());
        if (vie > 90.0f && PassifActif(player, EMBUSCADE))
            f += 0.80f;
        if (ChefOuRare(cible) && PassifActif(player, CHASSEUR_DE_RARES))
            f += 0.10f;
        if (MonstreDeLieu(cible->GetEntry()) && PassifActif(player, NETTOYEUR))
            f += 0.10f;
        return f;
    }

    float Subis(Player* player, Creature* attaquant, SpellInfo const* sort)
    {
        float f = 1.0f;
        if (PassifActif(player, PEAU_DE_BRAISE))
            f -= 0.08f;
        if (PassifActif(player, CONTRE_LA_MEUTE))
        {
            uint32 contact = 0;
            for (Unit* u : player->getAttackers())
                if (u->IsWithinMeleeRange(player))
                    ++contact;
            f -= 0.03f * std::min<uint32>(4, contact > 1 ? contact - 1 : 0);
        }
        if ((attaquant->GetEntry() == FISSURE || attaquant->GetEntry() == SPHERE || (sort && sort->IsAffectingArea()))
            && PassifActif(player, PIED_SUR))
            f -= 0.30f;
        if (player->getAttackers().size() <= 1 && PassifActif(player, SOLITAIRE))
            f -= 0.08f;
        return std::max(0.1f, f);
    }

    std::string ListePassifs(uint8 const (&emplacements)[EMPLACEMENTS], uint8 ouverts)
    {
        std::string s;
        for (uint8 i = 0; i < EMPLACEMENTS; ++i)
            s += Acore::StringFormat("{}{}", i ? ", " : "", i >= ouverts ? std::string("fermé")
                : emplacements[i] ? std::to_string(emplacements[i]) : std::string("libre"));
        return s;
    }
}

bool SolAzeroth::PassifActif(Player* player, unsigned char passif)
{
    if (!player || !player->IsInWorld())
        return false;
    Etat* e = EtatDe(player);
    if (!e->pret)
        Recalculer(player);
    if (!(e->actifs & (uint64(1) << passif)))
        return false;
    Map* map = player->GetMap();
    return passif <= DERNIER_DONJON ? map->IsDungeon() : !map->Instanceable();
}

class solazeroth_v3_passifs_unites : public UnitScript
{
public:
    solazeroth_v3_passifs_unites() : UnitScript("solazeroth_v3_passifs_unites", true, { UNITHOOK_ON_DAMAGE,
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK }) { }

    template <typename T>
    static void Modifier(Unit* cible, Unit* attaquant, T& degats, SpellInfo const* sort)
    {
        if (!cible || !attaquant || cible == attaquant || !degats)
            return;
        if (Player* player = attaquant->ToPlayer(); player && cible->ToCreature())
            degats = T(degats * Inflige(player, cible->ToCreature()));
        else if (Player* touche = cible->ToPlayer(); touche && attaquant->ToCreature())
            degats = T(degats * Subis(touche, attaquant->ToCreature(), sort));
    }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override
    {
        Modifier(cible, attaquant, degats, nullptr);
        // Épines et Contre-attaque : après le coup, pour ne pas frapper pendant le calcul de ses dégâts.
        Player* player = cible ? cible->ToPlayer() : nullptr;
        if (!player || !degats || !attaquant || !attaquant->ToCreature())
            return;
        uint32 epines = PassifActif(player, EPINES) ? std::max<uint32>(1, uint32(degats * 0.07f)) : 0;
        bool contre = PassifActif(player, CONTRE_ATTAQUE) && urand(1, 100) <= 20;
        if (!epines && !contre)
            return;
        ObjectGuid guid = attaquant->GetGUID();
        player->m_Events.AddEventAtOffset([player, guid, epines, contre]()
        {
            Creature* creature = ObjectAccessor::GetCreature(*player, guid);
            if (!creature || !creature->IsAlive() || !player->IsAlive())
                return;
            if (epines)
                Unit::DealDamage(player, creature, epines, nullptr, DIRECT_DAMAGE, SPELL_SCHOOL_MASK_NORMAL, nullptr, false);
            if (contre && creature->IsAlive() && player->IsWithinMeleeRange(creature))
                player->AttackerStateUpdate(creature, BASE_ATTACK, true);
        }, 1ms);
    }

    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* sort) override
    {
        if (degats > 0)
            Modifier(cible, attaquant, degats, sort);
    }

    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* sort) override
    {
        if (!sort || !sort->IsPositive())   // le moteur passe aussi par ici pour les soins sur la durée
            Modifier(cible, attaquant, degats, sort);
    }

    void OnDamage(Unit* attaquant, Unit* victime, uint32& degats) override
    {
        if (!attaquant || !victime || attaquant == victime || !degats)
            return;
        // Soif de sang : une part des dégâts infligés rendue en vie.
        if (Player* player = attaquant->ToPlayer(); player && victime->ToCreature() && PassifActif(player, SOIF_DE_SANG))
            player->ModifyHealth(int32(std::min(degats, victime->GetHealth()) * 0.06f));

        Player* player = victime->ToPlayer();
        if (!player || !player->IsAlive())
            return;
        Etat* e = EtatDe(player);
        uint32 max = player->GetMaxHealth();
        // Dernier rempart : une fois par donjon, la mort est évitée à 30 % de la vie.
        if (degats >= player->GetHealth() && PassifActif(player, DERNIER_REMPART)
            && e->rempart != player->GetMap()->GetInstanceId())
        {
            e->rempart = player->GetMap()->GetInstanceId();
            uint32 reste = uint32(max * 0.30f);
            if (player->GetHealth() > reste)
                degats = player->GetHealth() - reste;
            else
            {
                degats = 0;
                player->SetHealth(reste);
            }
            ChatHandler(player->GetSession()).SendSysMessage("|cffffd100Dernier rempart : la mort est évitée.|r");
        }
        uint32 apres = player->GetHealth() > degats ? player->GetHealth() - degats : 0;
        if (!apres)
            return;
        // Second souffle (une fois par combat) et Instinct de fuite (une fois par minute) : juste après le coup.
        bool souffle = !e->souffle && apres < max * 0.30f && PassifActif(player, SECOND_SOUFFLE);
        bool fuite = apres < max * 0.25f && GameTime::GetGameTimeMS().count() >= e->fuite
            && PassifActif(player, INSTINCT_DE_FUITE);
        if (souffle)
            e->souffle = true;
        if (fuite)
            e->fuite = GameTime::GetGameTimeMS().count() + MINUTE * IN_MILLISECONDS;
        if (souffle || fuite)
            player->m_Events.AddEventAtOffset([player, souffle, fuite]()
            {
                if (!player->IsAlive())
                    return;
                if (souffle)
                    player->ModifyHealth(int32(player->GetMaxHealth() * 0.15f));
                if (fuite)
                    player->CastSpell(player, AURA_FUITE, true);
            }, 1ms);
    }
};

class solazeroth_v3_passifs_joueur : public PlayerScript
{
public:
    solazeroth_v3_passifs_joueur() : PlayerScript("solazeroth_v3_passifs_joueur", { PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_PLAYER_JUST_DIED,
        PLAYERHOOK_ON_PLAYER_LEAVE_COMBAT, PLAYERHOOK_ON_SPELL_CAST, PLAYERHOOK_ON_GET_REPUTATION_PRICE_DISCOUNT }) { }

    void OnPlayerLogin(Player* player) override
    {
        Recalculer(player);
        Envoyer(player, true);
    }

    void OnPlayerMapChanged(Player* player) override
    {
        Recalculer(player);
        Envoyer(player, true);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Etat* e = EtatDe(player);
        e->attente += diff;
        if (e->attente < TICK || !player->IsInWorld())
            return;
        e->attente = 0;
        Recalculer(player);
        Envoyer(player, false);
        if (!player->IsAlive())
            return;
        Synchroniser(player, AURA_CARRURE, PassifActif(player, CARRURE));
        Synchroniser(player, AURA_CUIRASSE, PassifActif(player, CUIRASSE));
        Synchroniser(player, AURA_PAS_LEGER, PassifActif(player, PAS_LEGER));
        Synchroniser(player, AURA_RODEUR, PassifActif(player, RODEUR));
        // Récupération (+ 2 %/s) et Second vent (+ 50 % de la régénération de v3_niveau.cpp, 2 %/s), hors combat.
        if (player->IsInCombat() || player->IsFullHealth())
            return;
        float pourcent = (PassifActif(player, RECUPERATION) ? 2.0f : 0.0f) + (PassifActif(player, SECOND_VENT) ? 1.0f : 0.0f);
        if (pourcent > 0.0f)
            player->ModifyHealth(std::max<int32>(1, int32(player->GetMaxHealth() * pourcent / 100.0f)));
    }

    void OnPlayerLeaveCombat(Player* player) override
    {
        EtatDe(player)->souffle = false;
        if (player->IsAlive() && PassifActif(player, FIN_DE_COMBAT))
            player->ModifyHealth(int32(player->GetMaxHealth() * 0.10f));
    }

    void OnPlayerCreatureKill(Player* player, Creature* creature) override
    {
        if (creature->GetCharmerOrOwnerPlayerOrPlayerItself())
            return;
        Etat* e = EtatDe(player);
        if (PassifActif(player, ELAN))
            e->elan = std::min<uint8>(5, e->elan + 1);
        if (PassifActif(player, FIN_DE_TRAQUE))
            player->ModifyHealth(int32(player->GetMaxHealth() * 0.03f));
        if (creature->IsDungeonBoss() && PassifActif(player, PILLEUR_DE_FAILLE))
            DonnerMarques(player, 1, "Pilleur de faille");
    }

    void OnPlayerJustDied(Player* player) override
    {
        EtatDe(player)->elan = 0;
    }

    // Main vive : recharges − 10 %, une fois la recharge posée par le moteur.
    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        uint32 sort = spell->GetSpellInfo()->Id;
        if (spell->m_CastItem || sort == PIERRE_DE_FOYER || !PassifActif(player, MAIN_VIVE))
            return;
        player->m_Events.AddEventAtOffset([player, sort]()
        {
            if (uint32 reste = player->GetSpellCooldownDelay(sort); reste >= 1000)
                player->ModifySpellCooldown(sort, -int32(reste / 10));
        }, 100ms);
    }

    void OnPlayerGetReputationPriceDiscount(Player const* player, Creature const* /*creature*/, float& remise) override
    {
        if (PassifActif(const_cast<Player*>(player), MARCHANDAGE))
            remise *= 0.9f;
    }
};

// Tenace (étourdissements, immobilisations et ralentissements − 25 %) et Gourmet (plats + 50 %).
class solazeroth_v3_passifs_sorts : public AllSpellScript
{
public:
    solazeroth_v3_passifs_sorts() : AllSpellScript("solazeroth_v3_passifs_sorts", { ALLSPELLHOOK_ON_CALC_MAX_DURATION }) { }

    void OnCalcMaxDuration(Aura const* aura, int32& duree) override
    {
        Player* player = aura->GetOwner() ? aura->GetOwner()->ToPlayer() : nullptr;
        if (!player || duree <= 0)
            return;
        SpellInfo const* sort = aura->GetSpellInfo();
        if (sortsDesPlats.count(sort->Id))
        {
            if (PassifActif(player, GOURMET))
                duree = duree * 3 / 2;
        }
        else if (!sort->IsPositive() && (sort->HasAura(SPELL_AURA_MOD_STUN) || sort->HasAura(SPELL_AURA_MOD_ROOT)
            || sort->HasAura(SPELL_AURA_MOD_DECREASE_SPEED)) && PassifActif(player, TENACE))
            duree = duree * 3 / 4;
    }
};

class solazeroth_v3_passifs_monde : public WorldScript
{
public:
    solazeroth_v3_passifs_monde() : WorldScript("solazeroth_v3_passifs_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        sortsDesPlats.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT sort FROM solazeroth_v3_plats"))
        {
            do
                sortsDesPlats.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
    }
};

class solazeroth_v3_passifs_commandes : public CommandScript
{
public:
    solazeroth_v3_passifs_commandes() : CommandScript("solazeroth_v3_passifs_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable passif =
        {
            { "",          HandleEtat,      SEC_PLAYER, Console::No },
            { "donjon",    HandleDonjon,    SEC_PLAYER, Console::No },
            { "exterieur", HandleExterieur, SEC_PLAYER, Console::No },
            { "acheter",   HandleAcheter,   SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "passif", passif },
        };
        return commandes;
    }

    // .passif : emplacements et passifs choisis (et renvoi à l'interface).
    static bool HandleEtat(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Choix const& c = ChoixDe(CompteDe(player));
        handler->PSendSysMessage("Passifs de donjon (réputation rang {}) : {}.", uint32(RangReputation(player)),
            ListePassifs(c.donjon, EmplacementsDonjon(player)));
        handler->PSendSysMessage("Passifs extérieurs ({} acheté(s) sur {} ouvert(s)) : {}.", uint32(c.achetes),
            uint32(ExterieursOuverts(player)), ListePassifs(c.exterieur, EmplacementsExterieur(player)));
        Envoyer(player, true);
        return true;
    }

    static bool Placer(ChatHandler* handler, bool exterieur, uint8 emplacement, uint8 passif)
    {
        Player* player = handler->GetPlayer();
        uint32 compte = CompteDe(player);
        Choix& c = ChoixDe(compte);
        uint8 ouverts = exterieur ? EmplacementsExterieur(player) : EmplacementsDonjon(player);
        uint8 premier = exterieur ? EMBUSCADE : PEAU_DE_BRAISE, dernier = exterieur ? DERNIER_EXTERIEUR : DERNIER_DONJON;
        if (emplacement < 1 || emplacement > ouverts)
        {
            handler->SendErrorMessage("Emplacement fermé ({} ouvert(s)).", uint32(ouverts));
            return false;
        }
        if (passif && (passif < premier || passif > dernier))
        {
            handler->SendErrorMessage("Passifs {} : {} à {} (0 pour vider l'emplacement).", exterieur ? "extérieurs" : "de donjon",
                uint32(premier), uint32(dernier));
            return false;
        }
        if (exterieur ? !ModifiableExterieur(player) : !ModifiableDonjon(player))
        {
            handler->SendErrorMessage(exterieur ? "Les passifs extérieurs se changent hors combat, dans une zone de repos (auberge, ville)."
                : "Les passifs de donjon se changent hors combat, hors d'une instance ou dans un donjon avant le premier combat.");
            return false;
        }
        uint8* emplacements = exterieur ? c.exterieur : c.donjon;
        for (uint8 i = 0; i < EMPLACEMENTS; ++i)
            if (passif && emplacements[i] == passif && i != emplacement - 1)
            {
                handler->SendErrorMessage("Ce passif est déjà dans l'emplacement {}.", uint32(i + 1));
                return false;
            }
        emplacements[emplacement - 1] = passif;
        if (passif)
            CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_passifs (compte, genre, emplacement, passif) VALUES "
                "({}, {}, {}, {})", compte, exterieur ? 1 : 0, emplacement - 1, passif);
        else
            CharacterDatabase.Execute("DELETE FROM solazeroth_v3_passifs WHERE compte = {} AND genre = {} AND emplacement = {}",
                compte, exterieur ? 1 : 0, emplacement - 1);
        Recalculer(player);
        Envoyer(player, true);
        handler->PSendSysMessage("Emplacement {} : {}.", uint32(emplacement), passif ? "passif " + std::to_string(passif)
            : std::string("vidé"));
        return true;
    }

    static bool HandleDonjon(ChatHandler* handler, uint8 emplacement, uint8 passif)
    {
        return Placer(handler, false, emplacement, passif);
    }

    static bool HandleExterieur(ChatHandler* handler, uint8 emplacement, uint8 passif)
    {
        return Placer(handler, true, emplacement, passif);
    }

    // .passif acheter : le prochain emplacement extérieur, ouvert par le rang d'aventurier, contre des Marques.
    static bool HandleAcheter(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        uint32 compte = CompteDe(player);
        Choix& c = ChoixDe(compte);
        if (c.achetes >= EMPLACEMENTS)
        {
            handler->SendErrorMessage("Les six emplacements extérieurs sont achetés.");
            return false;
        }
        if (PalierAventurier(player) < PALIERS_EXTERIEUR[c.achetes])
        {
            handler->SendErrorMessage("Le prochain emplacement s'ouvre au palier {} du rang d'aventurier.",
                uint32(PALIERS_EXTERIEUR[c.achetes]));
            return false;
        }
        uint32 prix = PRIX_EXTERIEUR[c.achetes];
        if (!RetirerMarques(player, prix))
        {
            handler->SendErrorMessage("Il faut {} Marques du voyageur.", prix);
            return false;
        }
        ++c.achetes;
        CharacterDatabase.Execute("INSERT INTO solazeroth_v3_reputation (compte, points, emplacements) VALUES ({}, 0, {}) "
            "ON DUPLICATE KEY UPDATE emplacements = VALUES(emplacements)", compte, uint32(c.achetes));
        Recalculer(player);
        Envoyer(player, true);
        handler->PSendSysMessage("Emplacement extérieur {} acheté ({} Marques).", uint32(c.achetes), prix);
        return true;
    }
};

void AddSC_solazeroth_v3_passifs()
{
    new solazeroth_v3_passifs_unites();
    new solazeroth_v3_passifs_joueur();
    new solazeroth_v3_passifs_sorts();
    new solazeroth_v3_passifs_monde();
    new solazeroth_v3_passifs_commandes();
}
