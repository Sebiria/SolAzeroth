// Naxxramas seul (section 4.7, V6 : chapitre 11 de l'histoire ; même règle que la Citadelle, adapter chaque mécanique
// impossible seul en gardant l'esprit du combat). Ne joue que lorsqu'un seul joueur est dans l'instance.
// - Le Recousu : la Frappe haineuse frappe le deuxième joueur en menace ; seul, elle tombe chaque seconde sur le joueur.
//   Elle ne lui fait que 25 % de ses dégâts.
// - Gluth : la Décimation laisse le joueur à 50 % de sa vie au lieu de 5 % (les monstres restent à 5 %).
// - Thaddius : Stalagg et Feugen doivent tomber à moins de 5 s d'écart, sur deux plates-formes séparées. Seul, les
//   dégâts faits à l'un sont faits aussi à l'autre, et le Choc de la bobine Tesla (quand l'un quitte sa plate-forme
//   pour rejoindre le joueur) ne touche plus le joueur.
// - Les quatre cavaliers : les marques sont prévues pour tourner entre quatre tanks. Seul, une marque ne fait jamais
//   plus de 1 500 dégâts (le coût de la troisième pile).

#include "SolAzeroth.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"

namespace
{
    uint32 const NAXXRAMAS = 533;

    enum Sorts : uint32
    {
        FRAPPE_HAINEUSE  = 41926,
        DECIMATION       = 28375,
        CHOC_TESLA       = 28099,
        DEGATS_MARQUE    = 28836,
    };

    enum Creatures : uint32
    {
        STALAGG = 15929,
        FEUGEN  = 15930,
    };

    uint32 const MARQUE_MAX = 1500;

    thread_local bool partageEnCours = false;   // évite que les dégâts recopiés sur l'autre serviteur reviennent au premier

    Player* JoueurSeul(Map* map)
    {
        Player* seul = nullptr;
        for (auto const& ref : map->GetPlayers())
        {
            if (seul)
                return nullptr;
            seul = ref.GetSource();
        }
        return seul;
    }

    bool EstSort(SpellInfo const* sort, uint32 base, Unit* cible)
    {
        return sort->Id == base || sort->Id == sSpellMgr->GetSpellIdForDifficulty(base, cible);
    }
}

class solazeroth_naxxramas_degats : public UnitScript
{
public:
    solazeroth_naxxramas_degats() : UnitScript("solazeroth_naxxramas_degats", true,
        { UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_ON_DAMAGE }) { }

    void ModifySpellDamageTaken(Unit* cible, Unit* /*attaquant*/, int32& degats, SpellInfo const* sort) override
    {
        if (!cible || !sort || degats <= 0 || cible->GetMapId() != NAXXRAMAS || !cible->IsPlayer()
            || JoueurSeul(cible->GetMap()) != cible)
            return;

        if (EstSort(sort, FRAPPE_HAINEUSE, cible))
            degats /= 4;
        else if (EstSort(sort, DECIMATION, cible))
            degats = std::min<int32>(degats, std::max<int32>(0, int32(cible->GetHealth()) - int32(cible->CountPctFromMaxHealth(50))));
        else if (EstSort(sort, CHOC_TESLA, cible))
            degats = 0;
        else if (EstSort(sort, DEGATS_MARQUE, cible))
            degats = std::min<int32>(degats, MARQUE_MAX);
    }

    void OnDamage(Unit* attaquant, Unit* victime, uint32& degats) override
    {
        if (partageEnCours || !attaquant || !victime || !degats || victime->GetMapId() != NAXXRAMAS
            || (victime->GetEntry() != STALAGG && victime->GetEntry() != FEUGEN) || !victime->IsCreature())
            return;
        Player* player = attaquant->GetCharmerOrOwnerPlayerOrPlayerItself();
        if (!player || JoueurSeul(victime->GetMap()) != player)
            return;
        Creature* autre = victime->FindNearestCreature(victime->GetEntry() == STALAGG ? FEUGEN : STALAGG, 200.0f);
        if (!autre || !autre->IsInCombat())
            return;
        partageEnCours = true;
        Unit::DealDamage(attaquant, autre, degats, nullptr, DIRECT_DAMAGE, SPELL_SCHOOL_MASK_NORMAL, nullptr, false);
        partageEnCours = false;
    }
};

void AddSC_solazeroth_naxxramas()
{
    new solazeroth_naxxramas_degats();
}
