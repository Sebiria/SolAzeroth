// Métiers partagés sur le compte (section 3.2, V2)
// À chaque sauvegarde et à la déconnexion, le niveau des métiers du personnage et ses recettes sont
// recopiés dans les tables du compte (on garde le meilleur). À la connexion, le personnage reçoit
// tous les métiers et recettes du compte.

#include "SolAzeroth.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellMgr.h"
#include <algorithm>
#include <array>
#include <string>

namespace
{
    // Métiers principaux et secondaires (cuisine, secourisme, pêche).
    std::array<uint16, 14> const METIERS = {
        164, 165, 171, 182, 186, 197, 202, 333, 393, 755, 773, // forge, travail du cuir, alchimie, herboristerie, minage, couture, ingénierie, enchantement, dépeçage, joaillerie, calligraphie
        185, 129, 356                                          // cuisine, secourisme, pêche
    };

    bool EstMetier(uint32 skill)
    {
        return std::find(METIERS.begin(), METIERS.end(), skill) != METIERS.end();
    }

    // Sort appris par un métier, sans restriction de race ni de classe (on écarte les bonus raciaux).
    bool EstSortDeMetier(uint32 sort)
    {
        SkillLineAbilityMapBounds bornes = sSpellMgr->GetSkillLineAbilityMapBounds(sort);
        for (auto it = bornes.first; it != bornes.second; ++it)
            if (EstMetier(it->second->SkillLine) && !it->second->RaceMask && !it->second->ClassMask)
                return true;
        return false;
    }

    void Enregistrer(Player* player)
    {
        uint32 compte = player->GetSession()->GetAccountId();

        for (uint16 skill : METIERS)
        {
            if (!player->HasSkill(skill))
                continue;
            CharacterDatabase.DirectExecute(
                "INSERT INTO solazeroth_metiers_compte (account, skill, valeur, maximum) VALUES ({}, {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE valeur = GREATEST(valeur, VALUES(valeur)), maximum = GREATEST(maximum, VALUES(maximum))",
                compte, skill, player->GetPureSkillValue(skill), player->GetPureMaxSkillValue(skill));
        }

        std::string valeurs;
        for (auto const& [sort, info] : player->GetSpellMap())
        {
            if (info->State == PLAYERSPELL_REMOVED || !EstSortDeMetier(sort))
                continue;
            if (!valeurs.empty())
                valeurs += ',';
            valeurs += "(" + std::to_string(compte) + "," + std::to_string(sort) + ")";
        }
        if (!valeurs.empty())
            CharacterDatabase.DirectExecute("INSERT IGNORE INTO solazeroth_recettes_compte (account, spell) VALUES " + valeurs);
    }

    void Appliquer(Player* player)
    {
        uint32 compte = player->GetSession()->GetAccountId();

        // Recettes d'abord : les sorts de rang (Apprenti, Compagnon…) donnent le métier et son plafond.
        if (QueryResult resultat = CharacterDatabase.Query("SELECT spell FROM solazeroth_recettes_compte WHERE account = {}", compte))
        {
            do
            {
                uint32 sort = (*resultat)[0].Get<uint32>();
                if (!player->HasSpell(sort) && sSpellMgr->GetSpellInfo(sort))
                    player->learnSpell(sort);
            } while (resultat->NextRow());
        }

        if (QueryResult resultat = CharacterDatabase.Query("SELECT skill, valeur, maximum FROM solazeroth_metiers_compte WHERE account = {}", compte))
        {
            do
            {
                uint16 skill = (*resultat)[0].Get<uint16>();
                uint16 valeur = (*resultat)[1].Get<uint16>();
                uint16 maximum = (*resultat)[2].Get<uint16>();

                uint16 max = std::max(maximum, player->GetPureMaxSkillValue(skill));
                uint16 val = std::max(valeur, player->GetPureSkillValue(skill));
                uint16 palier = std::max<uint16>(player->GetSkillStep(skill), max / 75);
                if (val != player->GetPureSkillValue(skill) || max != player->GetPureMaxSkillValue(skill))
                    player->SetSkill(skill, palier, std::min(val, max), max);
            } while (resultat->NextRow());
        }
    }
}

class solazeroth_metiers : public PlayerScript
{
public:
    solazeroth_metiers() : PlayerScript("solazeroth_metiers", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_SAVE }) { }

    // Ce que le personnage a de mieux remonte d'abord au compte, puis il reçoit tout le compte.
    void OnPlayerLogin(Player* player) override
    {
        Enregistrer(player);
        Appliquer(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        Enregistrer(player);
    }

    void OnPlayerSave(Player* player) override
    {
        Enregistrer(player);
    }
};

void AddSC_solazeroth_metiers()
{
    new solazeroth_metiers();
}
