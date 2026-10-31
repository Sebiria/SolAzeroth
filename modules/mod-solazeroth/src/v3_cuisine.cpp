// v3 (31/10/2026) : cuisine par zone (demande de l'utilisateur). Plats générés par outils\cuisine_v3.py (migration 079).
// - Manger un plat lance son sort (spell_solazeroth_v3_plat) : il pose l'aura « Bien nourri » de la caractéristique de
//   la spécialisation (Force, Agilité ou Intelligence), d'autant de points que la puissance moyenne de la zone du plat,
//   pendant 30 minutes. Un seul repas à la fois : le nouveau remplace l'ancien.
// - La fabrication (catégorie Cuisine, près d'un feu) passe par v3_equipement.cpp.

#include "SolAzeroth.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include <array>
#include <unordered_map>
#include <vector>

namespace
{
    // sort du plat -> auras Force, Agilité, Intelligence
    std::unordered_map<uint32, std::array<uint32, 3>> plats;
    std::vector<uint32> auras;

    uint32 AuraDe(std::array<uint32, 3> const& trois, uint8 caracteristique)
    {
        switch (caracteristique)
        {
            case STAT_AGILITY:
                return trois[1];
            case STAT_INTELLECT:
                return trois[2];
            default:
                return trois[0];
        }
    }
}

class spell_solazeroth_v3_plat : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_plat);

    void Manger(SpellEffIndex /*effet*/)
    {
        Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        auto it = plats.find(GetSpellInfo()->Id);
        if (!player || it == plats.end())
            return;
        for (uint32 aura : auras)
            player->RemoveAurasDueToSpell(aura);
        player->CastSpell(player, AuraDe(it->second, SolAzeroth::CaracteristiquePrincipale(player)), true);
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_solazeroth_v3_plat::Manger, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

class solazeroth_v3_cuisine_monde : public WorldScript
{
public:
    solazeroth_v3_cuisine_monde() : WorldScript("solazeroth_v3_cuisine_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        plats.clear();
        auras.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT sort, force_, agilite, intelligence FROM solazeroth_v3_plats"))
        {
            do
            {
                Field* f = r->Fetch();
                std::array<uint32, 3> trois = { f[1].Get<uint32>(), f[2].Get<uint32>(), f[3].Get<uint32>() };
                plats[f[0].Get<uint32>()] = trois;
                auras.insert(auras.end(), trois.begin(), trois.end());
            } while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} plats", plats.size());
    }
};

void AddSC_solazeroth_v3_cuisine()
{
    new solazeroth_v3_cuisine_monde();
    RegisterSpellScript(spell_solazeroth_v3_plat);
}
