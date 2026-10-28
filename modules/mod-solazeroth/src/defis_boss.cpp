// Défis de boss façon Dofus (section 4.6) : au début de chaque combat contre un boss de donjon, un défi est tiré
// au sort. Réussi à la mort du boss, il rapporte des Marques du voyageur. Valeurs provisoires dans mod_solazeroth.conf.
//   Sobriété          : vaincre le boss sans boire de potion
//   Contre la montre  : le vaincre en moins de N secondes
//   Sans filet        : sans te soigner toi-même (sorts, potions, pierres de soins…)
//   Intouchable       : sans descendre sous N % de PV
// L'addon SolAzerothMenace affiche le défi en cours (préfixe SOLMENACE, messages DEFI, DEFI_ECHEC, DEFI_REUSSI,
// DEFI_ANNULE). « Tuer l'adjoint en premier » (exemple du document) dépend de chaque boss : pas encore géré.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Formulas.h"
#include "Item.h"
#include "Map.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <chrono>
#include <mutex>
#include <unordered_map>

namespace
{
    char const* const PREFIXE = "SOLMENACE";

    enum TypeDefi : uint8 { SANS_POTION = 0, CHRONO, SANS_SOIN, PLEINE_FORME, NOMBRE_DE_DEFIS };

    struct Reglages
    {
        bool active = true;
        uint32 marques = 3;
        uint32 chrono = 60;
        uint32 seuilPv = 50;
    } reglages;

    struct Defi
    {
        TypeDefi type;
        uint32 instance;
        std::chrono::steady_clock::time_point debut;
        bool echoue = false;
    };

    std::mutex verrou;
    std::unordered_map<ObjectGuid, Defi> defis;   // clé : le boss

    char const* Nom(TypeDefi type)
    {
        switch (type)
        {
            case SANS_POTION:  return "Sobriété";
            case CHRONO:       return "Contre la montre";
            case SANS_SOIN:    return "Sans filet";
            case PLEINE_FORME: return "Intouchable";
            default:           return "?";
        }
    }

    std::string Description(TypeDefi type)
    {
        switch (type)
        {
            case SANS_POTION:  return "Vaincre le boss sans boire de potion.";
            case CHRONO:       return Acore::StringFormat("Vaincre le boss en moins de {} secondes.", reglages.chrono);
            case SANS_SOIN:    return "Vaincre le boss sans te soigner toi-même.";
            case PLEINE_FORME: return Acore::StringFormat("Vaincre le boss sans descendre sous {} % de PV.", reglages.seuilPv);
            default:           return "";
        }
    }

    bool EstDonjon(Map const* map)
    {
        return map && map->IsDungeon() && !map->IsRaid();
    }

    void ATous(Map* map, std::string const& chat, std::string const& addon)
    {
        for (auto const& ref : map->GetPlayers())
            if (Player* player = ref.GetSource())
                SolAzeroth::EnvoyerAddon(player, PREFIXE, addon);   // pas de message dans la discussion : la fenêtre suffit
        SolAzeroth::Journaliser(map, chat);
    }

    // Fait échouer le défi en cours de l'instance du joueur s'il est du type donné (verrou tenu par l'appelant).
    void Echouer(Player* player, TypeDefi type, char const* raison)
    {
        uint32 instance = player->GetMap()->GetInstanceId();
        for (auto& [boss, defi] : defis)
        {
            if (defi.instance != instance || defi.type != type || defi.echoue)
                continue;
            defi.echoue = true;
            ATous(player->GetMap(), Acore::StringFormat("|cffff4040Défi « {} » échoué :|r {}.", Nom(type), raison),
                Acore::StringFormat("DEFI_ECHEC;{}", raison));
        }
    }

    bool CoteJoueur(Unit const* unite)
    {
        return unite && unite->GetCharmerOrOwnerPlayerOrPlayerItself();
    }

    bool BossDeDonjon(Unit const* unite)
    {
        Creature const* creature = unite ? unite->ToCreature() : nullptr;
        return creature && creature->IsDungeonBoss() && EstDonjon(creature->GetMap());
    }
}

class solazeroth_defis_boss_unites : public UnitScript
{
public:
    solazeroth_defis_boss_unites() : UnitScript("solazeroth_defis_boss_unites", true, {
        UNITHOOK_ON_UNIT_ENTER_COMBAT, UNITHOOK_ON_UNIT_EXIT_COMBAT, UNITHOOK_ON_UNIT_DEATH, UNITHOOK_ON_HEAL, UNITHOOK_ON_DAMAGE }) { }

    // Début du combat : tirage du défi.
    void OnUnitEnterCombat(Unit* unite, Unit* cible) override
    {
        if (!reglages.active || !BossDeDonjon(unite) || !CoteJoueur(cible))
            return;
        TypeDefi type;
        {
            std::lock_guard<std::mutex> garde(verrou);
            if (defis.count(unite->GetGUID()))
                return;
            type = TypeDefi(urand(0, NOMBRE_DE_DEFIS - 1));
            defis[unite->GetGUID()] = { type, unite->GetMap()->GetInstanceId(), std::chrono::steady_clock::now() };
        }
        ATous(unite->GetMap(), Acore::StringFormat("|cffffd100Défi de boss : {}.|r {} Récompense : {} Marques.", Nom(type), Description(type), reglages.marques),
            Acore::StringFormat("DEFI;{};{};{};{}", Nom(type), Description(type), type == CHRONO ? reglages.chrono : 0, reglages.marques));
    }

    // Le boss revient à sa place sans mourir (le joueur est mort ou a fui) : défi annulé.
    void OnUnitExitCombat(Unit* unite) override
    {
        if (!BossDeDonjon(unite) || !unite->IsAlive())
            return;
        {
            std::lock_guard<std::mutex> garde(verrou);
            if (!defis.erase(unite->GetGUID()))
                return;
        }
        ATous(unite->GetMap(), "Défi de boss annulé : le combat est terminé sans victoire.", "DEFI_ANNULE");
    }

    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        if (!BossDeDonjon(unite))
            return;
        Defi defi;
        {
            std::lock_guard<std::mutex> garde(verrou);
            auto it = defis.find(unite->GetGUID());
            if (it == defis.end())
                return;
            defi = it->second;
            defis.erase(it);
        }
        double duree = std::chrono::duration<double>(std::chrono::steady_clock::now() - defi.debut).count();
        if (defi.type == CHRONO && duree > reglages.chrono)
        {
            ATous(unite->GetMap(), Acore::StringFormat("|cffff4040Défi « {} » échoué :|r boss vaincu en {:.0f} s.", Nom(defi.type), duree),
                Acore::StringFormat("DEFI_ECHEC;boss vaincu en {:.0f} s", duree));
            return;
        }
        if (defi.echoue)
            return;
        ATous(unite->GetMap(), Acore::StringFormat("|cff00ff00Défi « {} » réussi !|r", Nom(defi.type)),
            Acore::StringFormat("DEFI_REUSSI;{}", reglages.marques));
        for (auto const& ref : unite->GetMap()->GetPlayers())
            if (Player* player = ref.GetSource())
            {
                SolAzeroth::DonnerMarques(player, reglages.marques, Acore::StringFormat("défi « {} »", Nom(defi.type)));
                // Boss dont le défi est réussi au moins une fois (ligne « Défis de base » du Codex).
                CharacterDatabase.DirectExecute("INSERT IGNORE INTO solazeroth_defis_reussis (account, boss) VALUES ({}, {})",
                    player->GetSession()->GetAccountId(), unite->GetEntry());
                // Compteurs des hauts faits (section 7.4).
                SolAzeroth::AjouterCompteur(player, "defis_boss");
                // Bonus de points de vie (bonus_hauts_faits.cpp) : seulement si le boss n'est pas gris pour ce personnage.
                if (unite->GetLevel() > Acore::XP::GetGrayLevel(player->GetLevel()))
                    SolAzeroth::AjouterCompteur(player, "defis_boss_niveau");
                if (defi.type == SANS_SOIN)
                    SolAzeroth::AjouterCompteur(player, "defis_sans_filet");
            }
    }

    // Sans filet : un soin que le joueur se donne à lui-même (sort, potion, pierre de soins…).
    void OnHeal(Unit* soigneur, Unit* cible, uint32& soins) override
    {
        Player* player = cible ? cible->ToPlayer() : nullptr;
        if (!player || !soins || soigneur != cible || !EstDonjon(player->GetMap()))
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (!defis.empty())
            Echouer(player, SANS_SOIN, "tu t'es soigné");
    }

    // Intouchable : les PV passent sous le seuil.
    void OnDamage(Unit* /*attaquant*/, Unit* victime, uint32& degats) override
    {
        Player* player = victime ? victime->ToPlayer() : nullptr;
        if (!player || !degats || !EstDonjon(player->GetMap()))
            return;
        uint32 restants = player->GetHealth() > degats ? player->GetHealth() - degats : 0;
        if (restants * 100 >= uint64(player->GetMaxHealth()) * reglages.seuilPv)
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (!defis.empty())
            Echouer(player, PLEINE_FORME, Acore::StringFormat("tes PV sont passés sous {} %", reglages.seuilPv).c_str());
    }
};

// Sobriété : une potion bue pendant le défi.
class solazeroth_defis_boss_joueur : public PlayerScript
{
public:
    solazeroth_defis_boss_joueur() : PlayerScript("solazeroth_defis_boss_joueur", { PLAYERHOOK_ON_SPELL_CAST }) { }

    void OnPlayerSpellCast(Player* player, Spell* sort, bool /*sansVerification*/) override
    {
        if (!sort || !sort->m_CastItem || !EstDonjon(player->GetMap()))
            return;
        ItemTemplate const* modele = sort->m_CastItem->GetTemplate();
        if (!modele || modele->Class != ITEM_CLASS_CONSUMABLE || modele->SubClass != ITEM_SUBCLASS_POTION)
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (!defis.empty())
            Echouer(player, SANS_POTION, "tu as bu une potion");
    }
};

class solazeroth_defis_boss_config : public WorldScript
{
public:
    solazeroth_defis_boss_config() : WorldScript("solazeroth_defis_boss_config", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.active = sConfigMgr->GetOption<bool>("SolAzeroth.DefisBoss.Enable", true);
        reglages.marques = sConfigMgr->GetOption<uint32>("SolAzeroth.DefisBoss.Marques", 3);
        reglages.chrono = sConfigMgr->GetOption<uint32>("SolAzeroth.DefisBoss.Chrono", 60);
        reglages.seuilPv = sConfigMgr->GetOption<uint32>("SolAzeroth.DefisBoss.SeuilPV", 50);
    }
};

void AddSC_solazeroth_defis_boss()
{
    new solazeroth_defis_boss_unites();
    new solazeroth_defis_boss_joueur();
    new solazeroth_defis_boss_config();
}
