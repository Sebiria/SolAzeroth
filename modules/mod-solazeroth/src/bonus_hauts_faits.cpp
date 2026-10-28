// Bonus permanents de compte tirés des hauts faits (section 7.4, V4, décisions de l'utilisateur du 29/10/2026).
// Valeurs provisoires dans mod_solazeroth.conf (SolAzeroth.BonusHF.*) :
//   - chaque continent exploré (hauts faits natifs 42 à 45, sur n'importe quel personnage du compte) : +5 % de vitesse
//     de course hors combat. Aura du sort 17498 « Vitesse » réglée à la bonne valeur ; comme toutes les auras de vitesse
//     de course, elle ne se cumule pas avec une autre (la plus forte l'emporte : bottes enchantées, talents…) ;
//   - contrats rendus (compteur « contrats ») : +10 % d'or des contrats à 25, +20 % à 50, +100 % à 100 ;
//   - défis de boss réussis sur un boss non gris pour le personnage (compteur « defis_boss_niveau ») : +2 % de points
//     de vie par palier de 10, jusqu'à +20 % à 100 ;
//   - herboristerie, minage ou dépeçage à 375 (meilleure valeur du compte) : +1 unité à chaque récolte de ce métier ;
//   - XP de quête : + le pourcentage de la fin « Histoire » du Codex.
// Recalcul à la connexion puis toutes les 30 secondes ; « .solhf liste » envoie les lignes « BONUS;texte » (hauts_faits.cpp).

#include "SolAzeroth.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "LootMgr.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <algorithm>
#include <array>
#include <map>
#include <sstream>
#include <vector>

namespace
{
    uint32 const SORT_VITESSE = 17498;                                // « Vitesse », passif, sans effet visuel
    std::array<uint32, 4> const CONTINENTS = { 42, 43, 44, 45 };      // Explorer les Royaumes de l'Est, Kalimdor, l'Outreterre, le Norfendre
    uint32 const HERBORISTERIE = 182, MINAGE = 186, DEPECAGE = 393;

    struct Reglages
    {
        uint32 vitesseParContinent = 5;
        std::map<uint32, uint32> orContrats = { { 25, 10 }, { 50, 20 }, { 100, 100 } };   // contrats -> % d'or
        uint32 palierDefis = 10;
        uint32 pvParPalier = 2;
        uint32 pvMax = 20;
        uint32 recolteCompetence = 375;
        float xpCodex = 1.0f;                                           // part du pourcentage « Histoire » du Codex
    } reglages;

    struct Bonus : DataMap::Base
    {
        bool calcule = false;
        uint32 continents = 0, vitesse = 0;
        uint32 contrats = 0, orContrats = 0;
        uint32 defis = 0, pv = 0;
        std::vector<uint32> recolte;                                    // métiers de récolte à 375
        float xpQuete = 0.0f;
        uint32 attenteVitesse = 0, attenteCalcul = 0;
    };

    Bonus* BonusDe(Player* player)
    {
        return player->CustomData.GetDefault<Bonus>("solazeroth_bonus_hf");
    }

    uint32 Compteur(uint32 compte, char const* cle)
    {
        QueryResult r = CharacterDatabase.Query("SELECT valeur FROM solazeroth_compteurs WHERE account = {} AND cle = '{}'", compte, cle);
        return r ? (*r)[0].Get<uint32>() : 0;
    }

    void Calculer(Player* player)
    {
        Bonus* b = BonusDe(player);
        uint32 compte = player->GetSession()->GetAccountId();
        uint32 pvAvant = b->pv;

        b->continents = 0;
        for (uint32 hf : CONTINENTS)
        {
            if (player->HasAchieved(hf))
            {
                ++b->continents;
                continue;
            }
            QueryResult r = CharacterDatabase.Query("SELECT 1 FROM character_achievement a JOIN characters c ON c.guid = a.guid "
                "WHERE c.account = {} AND a.achievement = {} LIMIT 1", compte, hf);
            if (r)
                ++b->continents;
        }
        b->vitesse = b->continents * reglages.vitesseParContinent;

        b->contrats = Compteur(compte, "contrats");
        b->orContrats = 0;
        for (auto const& [seuil, pourcent] : reglages.orContrats)
            if (b->contrats >= seuil)
                b->orContrats = pourcent;

        b->defis = Compteur(compte, "defis_boss_niveau");
        b->pv = std::min(reglages.pvMax, (b->defis / std::max<uint32>(1, reglages.palierDefis)) * reglages.pvParPalier);

        b->recolte.clear();
        for (uint32 metier : { HERBORISTERIE, MINAGE, DEPECAGE })
        {
            uint32 valeur = player->GetPureSkillValue(metier);
            if (QueryResult r = CharacterDatabase.Query("SELECT valeur FROM solazeroth_metiers_compte WHERE account = {} AND skill = {}", compte, metier))
                valeur = std::max(valeur, (*r)[0].Get<uint32>());
            if (valeur >= reglages.recolteCompetence)
                b->recolte.push_back(metier);
        }

        b->xpQuete = SolAzeroth::PourcentFinCodex(player, 1) * reglages.xpCodex;
        b->calcule = true;

        if (b->pv != pvAvant)
            player->UpdateMaxHealth();
    }

    // Vitesse hors combat : l'aura est posée ou retirée selon l'état du personnage.
    void AppliquerVitesse(Player* player)
    {
        Bonus* b = BonusDe(player);
        bool voulu = b->vitesse > 0 && player->IsAlive() && !player->IsInCombat();
        Aura* aura = player->GetAura(SORT_VITESSE);
        if (!voulu)
        {
            if (aura)
                player->RemoveAurasDueToSpell(SORT_VITESSE);
            return;
        }
        if (!aura)
            aura = player->AddAura(SORT_VITESSE, player);
        if (aura)
            if (AuraEffect* effet = aura->GetEffect(EFFECT_0))
                if (effet->GetAmount() != int32(b->vitesse))
                    effet->ChangeAmount(int32(b->vitesse));
    }

    std::string Pourcent(float valeur)
    {
        return Acore::StringFormat("{:.0f} %", valeur);
    }
}

float SolAzeroth::BonusOrContrats(Player* player)
{
    Bonus* b = BonusDe(player);
    if (!b->calcule)
        Calculer(player);
    return b->orContrats / 100.0f;
}

std::vector<std::string> SolAzeroth::LignesBonusHautsFaits(Player* player)
{
    Calculer(player);
    Bonus* b = BonusDe(player);
    std::vector<std::string> lignes;
    lignes.push_back(Acore::StringFormat("Vitesse de course hors combat : +{} ({} continent(s) explorés sur 4, +{} % chacun)",
        Pourcent(b->vitesse), b->continents, reglages.vitesseParContinent));

    std::string paliers;
    for (auto const& [seuil, pourcent] : reglages.orContrats)
        paliers += (paliers.empty() ? "" : ", ") + Acore::StringFormat("{} à {}", Pourcent(pourcent), seuil);
    lignes.push_back(Acore::StringFormat("Or des contrats : +{} ({} contrats rendus. Paliers : {})", Pourcent(b->orContrats), b->contrats, paliers));

    lignes.push_back(Acore::StringFormat("Points de vie : +{} ({} défis de boss réussis sur un boss non gris, +{} % tous les {}, {} % au plus)",
        Pourcent(b->pv), b->defis, reglages.pvParPalier, reglages.palierDefis, reglages.pvMax));

    std::string metiers;
    for (uint32 m : b->recolte)
        metiers += (metiers.empty() ? "" : ", ") + std::string(m == HERBORISTERIE ? "herboristerie" : m == MINAGE ? "minage" : "dépeçage");
    lignes.push_back(Acore::StringFormat("Récolte : +1 unité en {} (herboristerie, minage ou dépeçage à {})",
        metiers.empty() ? "aucun métier pour l'instant" : metiers, reglages.recolteCompetence));

    lignes.push_back(Acore::StringFormat("XP des quêtes : +{} (pourcentage de la fin Histoire du Codex)", Pourcent(b->xpQuete)));
    return lignes;
}

class solazeroth_bonus_hauts_faits : public PlayerScript
{
public:
    solazeroth_bonus_hauts_faits() : PlayerScript("solazeroth_bonus_hauts_faits", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_PLAYER_ENTER_COMBAT, PLAYERHOOK_ON_AFTER_UPDATE_MAX_HEALTH,
        PLAYERHOOK_ON_QUEST_COMPUTE_EXP, PLAYERHOOK_ON_LOOT_ITEM }) { }

    void OnPlayerLogin(Player* player) override
    {
        Calculer(player);
        AppliquerVitesse(player);
    }

    void OnPlayerUpdate(Player* player, uint32 ecoule) override
    {
        Bonus* b = BonusDe(player);
        if (!b->calcule)
            return;
        b->attenteCalcul += ecoule;
        if (b->attenteCalcul >= 30000)
        {
            b->attenteCalcul = 0;
            Calculer(player);
        }
        b->attenteVitesse += ecoule;
        if (b->attenteVitesse >= 1000)
        {
            b->attenteVitesse = 0;
            AppliquerVitesse(player);
        }
    }

    void OnPlayerEnterCombat(Player* player, Unit* /*ennemi*/) override
    {
        player->RemoveAurasDueToSpell(SORT_VITESSE);
    }

    void OnPlayerAfterUpdateMaxHealth(Player* player, float& valeur) override
    {
        valeur *= 1.0f + BonusDe(player)->pv / 100.0f;
    }

    void OnPlayerQuestComputeXP(Player* player, Quest const* /*quete*/, uint32& xp) override
    {
        xp = uint32(xp * (1.0f + BonusDe(player)->xpQuete / 100.0f));
    }

    // Récolte : herbe ou minerai pris sur un objet du monde, cuir pris sur un monstre dépecé.
    void OnPlayerLootItem(Player* player, Item* objet, uint32 /*nombre*/, ObjectGuid source) override
    {
        if (!objet)
            return;
        Bonus* b = BonusDe(player);
        if (b->recolte.empty())
            return;
        ItemTemplate const* modele = objet->GetTemplate();
        if (modele->Class != ITEM_CLASS_TRADE_GOODS)
            return;
        uint32 metier = 0;
        if (source.IsGameObject() && modele->SubClass == ITEM_SUBCLASS_HERB)
            metier = HERBORISTERIE;
        else if (source.IsGameObject() && modele->SubClass == ITEM_SUBCLASS_METAL_STONE)
            metier = MINAGE;
        else if (source.IsCreatureOrVehicle() && modele->SubClass == ITEM_SUBCLASS_LEATHER)
            if (Creature* corps = ObjectAccessor::GetCreature(*player, source))
                if (corps->loot.loot_type == LOOT_SKINNING)
                    metier = DEPECAGE;
        if (metier && std::find(b->recolte.begin(), b->recolte.end(), metier) != b->recolte.end())
            player->AddItem(objet->GetEntry(), 1);
    }
};

class solazeroth_bonus_hauts_faits_config : public WorldScript
{
public:
    solazeroth_bonus_hauts_faits_config() : WorldScript("solazeroth_bonus_hauts_faits_config", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.vitesseParContinent = sConfigMgr->GetOption<uint32>("SolAzeroth.BonusHF.VitesseParContinent", 5);
        reglages.orContrats.clear();
        std::istringstream paliers(sConfigMgr->GetOption<std::string>("SolAzeroth.BonusHF.OrContrats", "25:10 50:20 100:100"));
        std::string palier;
        while (paliers >> palier)
        {
            size_t deuxPoints = palier.find(':');
            if (deuxPoints != std::string::npos)
                reglages.orContrats[uint32(std::stoul(palier.substr(0, deuxPoints)))] = uint32(std::stoul(palier.substr(deuxPoints + 1)));
        }
        reglages.palierDefis = sConfigMgr->GetOption<uint32>("SolAzeroth.BonusHF.PalierDefis", 10);
        reglages.pvParPalier = sConfigMgr->GetOption<uint32>("SolAzeroth.BonusHF.PvParPalier", 2);
        reglages.pvMax = sConfigMgr->GetOption<uint32>("SolAzeroth.BonusHF.PvMax", 20);
        reglages.recolteCompetence = sConfigMgr->GetOption<uint32>("SolAzeroth.BonusHF.RecolteCompetence", 375);
        reglages.xpCodex = sConfigMgr->GetOption<float>("SolAzeroth.BonusHF.XpCodex", 1.0f);
    }
};

void AddSC_solazeroth_bonus_hauts_faits()
{
    new solazeroth_bonus_hauts_faits();
    new solazeroth_bonus_hauts_faits_config();
}
