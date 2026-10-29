// Mode défi en extérieur (section 6.6, V3)
// Chaque personnage choisit un niveau de défi de 0 à 5, seulement en zone de repos et hors combat.
// Dans le monde extérieur (hors instance), les monstres qu'il affronte tiennent plus longtemps et frappent plus fort ;
// en échange, son XP, l'or ramassé et les Marques des quêtes augmentent. Même principe que le rang de menace.
// Chaque niveau a ses propres multiplicateurs (listes en config) : la courbe monte fort en haut, pour qu'au niveau 5
// deux monstres à la fois demandent de la tactique (contrôle, ralentissement, mise à distance).
// Addon : messages « EXT;niveau;max;repos;pv;dégâts;xp;or;marques », chaque liste séparée par des virgules (préfixe SOLEXT).
// Quêtes : chacune retient le niveau de défi le plus bas tenu depuis qu'elle a été prise (solazeroth_defi_quetes).
// Son bonus d'XP et de Marques utilise ce niveau : monter le niveau juste avant de rendre ne rapporte rien de plus.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Formulas.h"
#include "LootMgr.h"
#include "Map.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <cmath>
#include <sstream>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLEXT";
    uint8 const NIVEAU_MAX = 10;

    // Multiplicateurs par niveau : l'élément 0 vaut pour le niveau 1.
    struct Reglages
    {
        std::vector<float> pv, degats, xp, gainOr, marques;
        uint8 niveauMax = 0;
    } reglages;

    std::vector<float> Liste(char const* cle, char const* defaut)
    {
        std::vector<float> valeurs;
        std::istringstream flux(sConfigMgr->GetOption<std::string>(cle, defaut));
        float v;
        while (valeurs.size() < NIVEAU_MAX && flux >> v)
            valeurs.push_back(std::max(0.1f, v));
        return valeurs;
    }

    float Valeur(std::vector<float> const& liste, uint8 niveau)
    {
        return niveau && niveau <= liste.size() ? liste[niveau - 1] : 1.0f;
    }

    std::string Texte(std::vector<float> const& liste)
    {
        std::string texte;
        for (uint8 i = 0; i < reglages.niveauMax; ++i)
            texte += (i ? "," : "") + Acore::StringFormat("{:.2f}", liste[i]);
        return texte;
    }

    struct Niveau : DataMap::Base
    {
        uint8 valeur = 0;
    };

    uint8 NiveauDe(Player* player)
    {
        Niveau* n = player->CustomData.Get<Niveau>("solazeroth_defi_exterieur");
        return n ? std::min(n->valeur, reglages.niveauMax) : 0;
    }

    // Niveau qui s'applique en ce moment : 0 dans une instance (donjon, raid, champ de bataille).
    uint8 NiveauActif(Player* player)
    {
        return player->GetMap()->Instanceable() ? 0 : NiveauDe(player);
    }

    // Zone de repos, ou n'importe où avant le niveau 10 : les zones de départ n'ont pas d'auberge (retour de l'utilisateur
    // du 30/10/2026).
    bool EnRepos(Player* player)
    {
        return player->GetLevel() < 10 || player->HasRestFlag(REST_FLAG_IN_TAVERN) || player->HasRestFlag(REST_FLAG_IN_CITY)
            || player->HasRestFlag(REST_FLAG_IN_FACTION_AREA);
    }

    void EnvoyerEtat(Player* player)
    {
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("EXT;{};{};{};{};{};{};{};{}",
            NiveauDe(player), reglages.niveauMax, EnRepos(player) ? 1 : 0, Texte(reglages.pv), Texte(reglages.degats),
            Texte(reglages.xp), Texte(reglages.gainOr), Texte(reglages.marques)));
    }

    Player* JoueurDe(Unit* unite)
    {
        return unite ? unite->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
    }

    template <typename T>
    void Appliquer(Unit* cible, Unit* attaquant, T& degats)
    {
        if (!cible || !attaquant)
            return;
        Player* joueur = JoueurDe(attaquant);
        if (joueur && cible->IsCreature() && !JoueurDe(cible))
        {
            if (uint8 n = NiveauActif(joueur))
                degats = T(degats / Valeur(reglages.pv, n));
            return;
        }
        joueur = JoueurDe(cible);
        if (joueur && attaquant->IsCreature() && !JoueurDe(attaquant))
            if (uint8 n = NiveauActif(joueur))
                degats = T(degats * Valeur(reglages.degats, n));
    }
}

namespace
{
    // Niveau de défi qui compte pour une quête : le plus bas tenu pendant la quête (0 si elle a été prise avant ce suivi).
    uint8 NiveauQuete(Player* player, uint32 quete)
    {
        uint8 retenu = 0;
        if (QueryResult r = CharacterDatabase.Query("SELECT niveau FROM solazeroth_defi_quetes WHERE guid = {} AND quest = {}",
            player->GetGUID().GetCounter(), quete))
            retenu = (*r)[0].Get<uint8>();
        return std::min(retenu, NiveauDe(player));
    }

    // Quêtes du journal : leur niveau retenu ne peut que baisser.
    void PlafonnerQuetes(Player* player, uint8 niveau)
    {
        for (uint8 slot = 0; slot < MAX_QUEST_LOG_SIZE; ++slot)
            if (uint32 quete = player->GetQuestSlotQuestId(slot))
                CharacterDatabase.DirectExecute("INSERT INTO solazeroth_defi_quetes (guid, quest, niveau) VALUES ({}, {}, {}) "
                    "ON DUPLICATE KEY UPDATE niveau = LEAST(niveau, VALUES(niveau))", player->GetGUID().GetCounter(), quete, niveau);
    }
}

unsigned int SolAzeroth::MarquesDefiExterieur(Player* player, unsigned int quete, unsigned int nombre)
{
    uint8 n = NiveauQuete(player, quete);
    return n ? uint32(std::lround(nombre * Valeur(reglages.marques, n))) : nombre;
}

class solazeroth_defi_exterieur_degats : public UnitScript
{
public:
    solazeroth_defi_exterieur_degats() : UnitScript("solazeroth_defi_exterieur_degats", true, {
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK }) { }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override { Appliquer(cible, attaquant, degats); }
    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* /*sort*/) override { Appliquer(cible, attaquant, degats); }
    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* /*sort*/) override { Appliquer(cible, attaquant, degats); }
};

class solazeroth_defi_exterieur_joueur : public PlayerScript
{
public:
    solazeroth_defi_exterieur_joueur() : PlayerScript("solazeroth_defi_exterieur_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_GIVE_EXP, PLAYERHOOK_ON_BEFORE_LOOT_MONEY, PLAYERHOOK_ON_QUEST_COMPUTE_EXP,
        PLAYERHOOK_ON_PLAYER_QUEST_ACCEPT, PLAYERHOOK_ON_QUEST_ABANDON, PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST,
        PLAYERHOOK_ON_CREATURE_KILL_CREDIT }) { }

    // Compteurs des hauts faits (section 7.4) : quêtes rendues en défi 3 ou plus, monstres non gris tués en défi 5.
    // L'or de la quête suit aussi le multiplicateur d'or du niveau de défi pris à l'acceptation (calibrage final,
    // 29/10/2026 : seul l'or des monstres comptait, soit 3 à 5 % du revenu ; la récompense du risque était invisible).
    void OnPlayerCompleteQuest(Player* player, Quest const* quete) override
    {
        uint8 n = NiveauQuete(player, quete->GetQuestId());
        if (n >= 3)
            SolAzeroth::AjouterCompteur(player, "quetes_defi3");
        int32 argent = quete->GetRewOrReqMoney(player->GetLevel());
        if (n && argent > 0)
            if (int32 bonus = int32(argent * (Valeur(reglages.gainOr, n) - 1.0f)); bonus > 0)
                player->ModifyMoney(bonus);
    }

    void OnPlayerCreatureKillCredit(Player* player, Creature* tue) override
    {
        if (tue && NiveauActif(player) >= 5 && tue->GetLevel() > Acore::XP::GetGrayLevel(player->GetLevel()))
            SolAzeroth::AjouterCompteur(player, "tues_defi5");
    }

    void OnPlayerLogin(Player* player) override
    {
        uint8 niveau = 0;
        if (QueryResult r = CharacterDatabase.Query("SELECT niveau FROM solazeroth_defi_exterieur WHERE guid = {}", player->GetGUID().GetCounter()))
            niveau = (*r)[0].Get<uint8>();
        player->CustomData.GetDefault<Niveau>("solazeroth_defi_exterieur")->valeur = niveau;
        if (uint8 n = NiveauDe(player))
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cffffd100Mode défi en extérieur : niveau {}.|r", n));
    }

    // XP gagnée hors instance (monstres, exploration). Les quêtes sont traitées à part, plus bas.
    void OnPlayerGiveXP(Player* player, uint32& xp, Unit* /*victime*/, uint8 source) override
    {
        if (source == XPSOURCE_QUEST || source == XPSOURCE_QUEST_DF)
            return;
        if (uint8 n = NiveauActif(player))
            xp = uint32(xp * Valeur(reglages.xp, n));
    }

    void OnPlayerQuestComputeXP(Player* player, Quest const* quete, uint32& xp) override
    {
        if (uint8 n = NiveauQuete(player, quete->GetQuestId()))
            xp = uint32(xp * Valeur(reglages.xp, n));
    }

    void OnPlayerQuestAccept(Player* player, Quest const* quete) override
    {
        CharacterDatabase.DirectExecute("REPLACE INTO solazeroth_defi_quetes (guid, quest, niveau) VALUES ({}, {}, {})",
            player->GetGUID().GetCounter(), quete->GetQuestId(), NiveauDe(player));
    }

    void OnPlayerQuestAbandon(Player* player, uint32 quete) override
    {
        CharacterDatabase.DirectExecute("DELETE FROM solazeroth_defi_quetes WHERE guid = {} AND quest = {}",
            player->GetGUID().GetCounter(), quete);
    }

    void OnPlayerBeforeLootMoney(Player* player, Loot* loot) override
    {
        if (!loot || !loot->gold)
            return;
        if (uint8 n = NiveauActif(player))
            loot->gold = uint32(loot->gold * Valeur(reglages.gainOr, n));
    }
};

class solazeroth_defi_exterieur_commandes : public CommandScript
{
public:
    solazeroth_defi_exterieur_commandes() : CommandScript("solazeroth_defi_exterieur_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "etat",    HandleEtat,    SEC_PLAYER, Console::No },
            { "choisir", HandleChoisir, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solext", sousCommandes },
        };
        return commandes;
    }

    static bool HandleEtat(ChatHandler* handler)
    {
        EnvoyerEtat(handler->GetPlayer());
        return true;
    }

    static bool HandleChoisir(ChatHandler* handler, uint8 niveau)
    {
        Player* player = handler->GetPlayer();
        if (niveau > reglages.niveauMax)
            return true;
        if (!EnRepos(player) || player->IsInCombat())
        {
            handler->SendSysMessage("Le niveau de défi ne se change qu'en zone de repos (auberge, capitale), hors combat (partout avant le niveau 10).");
            EnvoyerEtat(player);
            return true;
        }

        PlafonnerQuetes(player, std::min(NiveauDe(player), niveau));
        player->CustomData.GetDefault<Niveau>("solazeroth_defi_exterieur")->valeur = niveau;
        CharacterDatabase.DirectExecute("REPLACE INTO solazeroth_defi_exterieur (guid, niveau) VALUES ({}, {})",
            player->GetGUID().GetCounter(), niveau);
        handler->SendSysMessage(niveau
            ? Acore::StringFormat("|cffffd100Mode défi en extérieur : niveau {}.|r", niveau)
            : std::string("Mode défi en extérieur désactivé."));
        EnvoyerEtat(player);
        return true;
    }
};

class solazeroth_defi_exterieur_monde : public WorldScript
{
public:
    solazeroth_defi_exterieur_monde() : WorldScript("solazeroth_defi_exterieur_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.pv = Liste("SolAzeroth.DefiExterieur.PV", "1.15 1.35 1.55 1.75 2.00");
        reglages.degats = Liste("SolAzeroth.DefiExterieur.Degats", "1.10 1.25 1.45 1.70 2.00");
        reglages.xp = Liste("SolAzeroth.DefiExterieur.XP", "1.10 1.20 1.35 1.50 1.75");
        reglages.gainOr = Liste("SolAzeroth.DefiExterieur.Or", "1.10 1.20 1.35 1.50 1.75");
        reglages.marques = Liste("SolAzeroth.DefiExterieur.Marques", "1.10 1.20 1.30 1.40 1.50");
        // Le niveau maximal est la plus courte des listes.
        reglages.niveauMax = uint8(std::min({ reglages.pv.size(), reglages.degats.size(), reglages.xp.size(),
            reglages.gainOr.size(), reglages.marques.size() }));
    }
};

void AddSC_solazeroth_defi_exterieur()
{
    new solazeroth_defi_exterieur_degats();
    new solazeroth_defi_exterieur_joueur();
    new solazeroth_defi_exterieur_commandes();
    new solazeroth_defi_exterieur_monde();
}
