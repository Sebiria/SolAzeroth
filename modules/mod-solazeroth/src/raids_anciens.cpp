// Raids classiques et de l'Outreterre seul, et règles communes à toutes les instances (section 4.7, V8 ; décision de
// l'utilisateur du 30/10/2026 : adapter seulement les mécaniques impossibles seul, d'après la lecture des scripts, sans
// test dédié). Ne joue que lorsqu'un seul joueur est dans l'instance.
// - Toutes les instances : le joueur est insensible aux contrôles mentaux des monstres (charme, possession). Seul, un
//   contrôle mental lui ôte tout ennemi et le combat se réinitialise (Lucifron, Skeram, Hakkar, Jin'do, Kael'thas...).
// - Zul'Gurub, Thekal : lui et ses deux zélotes se relèvent si les trois ne tombent pas à moins de 10 s d'écart. Seul,
//   les dégâts faits à l'un sont faits aux autres, en proportion de leur vie.
// - Karazhan, Romulo et Julianne : même règle (ils se relèvent l'un l'autre) et même partage. Dédain-du-Néant : seul,
//   on ne bloque qu'un rayon et les deux autres le renforcent ou le soignent sans fin ; il est insensible aux rayons.
// - Ahn'Qiraj, empereurs jumeaux : à moins de 60 m l'un de l'autre ils se soignent ; seul, ils restent toujours près du
//   joueur. Le Soin fraternel ne soigne plus. Viscidus : il faut 200 coups de givre pour le geler puis 150 coups de
//   mêlée en 15 s pour le briser. Seul, chaque coup compte pour 20 coups de givre, puis pour 30 coups de mêlée.
// - Repaire de l'Aile noire : l'Adrénaline brûlante de Vaelastrasz finit toujours sur le joueur seul et le tue au bout
//   de 20 s (les tanks se relaient) : il est insensible à la mort instantanée, pas à l'explosion. L'Ombre d'Ébonroc,
//   prévue pour un changement de tank, le soigne à chaque coup : le joueur y est insensible.
// - Magtheridon : cinq cubes à cliquer en même temps pour interrompre l'Onde explosive. Seul, un cube active les cinq.
// - Caverne du sanctuaire du Serpent, Vashj : le porteur d'un noyau contaminé est paralysé et le passe aux autres.
//   Seul, il n'est pas paralysé.
// - Temple noir, Naj'entus : son Bouclier de marée ne tombe que sous une épine, qui n'empale jamais le tank. Seul, une
//   épine apparaît aux pieds du joueur quand le bouclier se lève.
// - Plateau du Puits de soleil, Kalecgos : le Souffle spectral, qui envoie dans le royaume de Sathrovarr, évite le tank.
//   Seul, les dégâts faits à Kalecgos sont faits aussi à Sathrovarr, et Sathrovarr ne blesse plus Kalec. Brutallus : la
//   Taillade météorique s'empile sur le tank (relais prévu) ; seul, elle plafonne à 2 piles.
// - Fosse de Saron, Tyrannus : la Marque du seigneur renvoie au joueur seul ses propres dégâts : il y est insensible.

#include "SolAzeroth.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "GameObject.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include <algorithm>
#include <list>
#include <vector>

namespace
{
    enum Cartes : uint32
    {
        ZUL_GURUB    = 309,
        AILE_NOIRE   = 469,
        AHN_QIRAJ    = 531,
        KARAZHAN     = 532,
        MAGTHERIDON  = 544,
        SERPENT      = 548,
        TEMPLE_NOIR  = 564,
        PUITS_SOLEIL = 580,
        FOSSE_SARON  = 658,
    };

    enum Creatures : uint32
    {
        THEKAL = 14509, ZATH = 11348, LORKHAN = 11347,
        ROMULO = 17533, JULIANNE = 17534,
        NETHERSPITE = 15689,
        VEKNILASH = 15275, VEKLOR = 15276,
        VISCIDUS = 15299,
        DECLENCHEUR_FLAMMES_INFERNALES = 17376,
        NAJENTUS = 22887,
        KALECGOS = 24850, KALEC = 24891, SATHROVARR = 24892,
    };

    enum Sorts : uint32
    {
        RAYONS_DEDAIN_1 = 30466, RAYONS_DEDAIN_2 = 30467, RAYONS_DEDAIN_3 = 30468,
        SOIN_FRATERNEL  = 7393,
        TRAIT_DE_GIVRE  = 116,     // sert seulement à compter un coup de givre sur Viscidus
        ADRENALINE_MORT = 23644,
        OMBRE_EBONROC   = 23340,
        POIGNE_OMBRE    = 30410,   // joueur qui tient un cube de Magtheridon
        POIGNE_VISUEL   = 30166,   // lien d'un cube vers Magtheridon (5 = banni)
        PARALYSIE_NOYAU = 38132,
        BOUCLIER_MAREE  = 39872,
        INVOQUER_EPINE  = 39929,
        TAILLADE        = 45150,
        MARQUE_SEIGNEUR = 69172,
    };

    uint32 const CUBE_MANTICRON = 181713;
    uint32 const COUPS_GIVRE = 20;
    uint32 const COUPS_MELEE = 30;

    std::vector<uint32> const TRIO_THEKAL = { THEKAL, ZATH, LORKHAN };
    std::vector<uint32> const AMANTS = { ROMULO, JULIANNE };

    thread_local bool partageEnCours = false;

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

    bool Seul(Unit* u)
    {
        return u && u->FindMap() && u->FindMap()->IsDungeon() && JoueurSeul(u->FindMap());
    }

    // Sorts auxquels le joueur seul est insensible, par carte.
    std::vector<uint32> Insensibilites(uint32 carte)
    {
        switch (carte)
        {
            case AILE_NOIRE:  return { ADRENALINE_MORT, OMBRE_EBONROC };
            case SERPENT:     return { PARALYSIE_NOYAU };
            case FOSSE_SARON: return { MARQUE_SEIGNEUR };
            default:          return {};
        }
    }

    void Proteger(Player* player, Map* map, bool oui)
    {
        player->ApplySpellImmune(0, IMMUNITY_STATE, SPELL_AURA_MOD_CHARM, oui);
        player->ApplySpellImmune(0, IMMUNITY_STATE, SPELL_AURA_MOD_POSSESS, oui);
        player->ApplySpellImmune(0, IMMUNITY_STATE, SPELL_AURA_AOE_CHARM, oui);
        for (uint32 sort : Insensibilites(map->GetId()))
            player->ApplySpellImmune(0, IMMUNITY_ID, sort, oui);
    }

    // Dégâts faits à une créature du groupe : faits aussi aux autres, en proportion de leur vie (si attaquables, ou
    // toujours pour `forcer`).
    void Partager(Unit* attaquant, Unit* victime, uint32 degats, std::vector<uint32> const& groupe, bool forcer = false)
    {
        if (std::find(groupe.begin(), groupe.end(), victime->GetEntry()) == groupe.end())
            return;
        float part = float(degats) / float(std::max<uint32>(victime->GetMaxHealth(), 1));
        partageEnCours = true;
        for (uint32 entree : groupe)
        {
            if (entree == victime->GetEntry())
                continue;
            Creature* c = victime->FindNearestCreature(entree, 200.0f);
            if (!c || !c->IsInCombat() || (!forcer && c->HasUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE))))
                continue;
            Unit::DealDamage(attaquant, c, std::max<uint32>(1, uint32(part * c->GetMaxHealth())), nullptr, DIRECT_DAMAGE,
                SPELL_SCHOOL_MASK_NORMAL, nullptr, false);
        }
        partageEnCours = false;
    }

    // Viscidus : chaque coup du joueur compte pour plusieurs (gel puis bris). Le script ne compte que les coups de givre
    // pendant la phase de gel, et que les coups directs une fois gelé ; les deux appels sont donc sans effet hors phase.
    void CompterViscidus(Unit* attaquant, Creature* viscidus)
    {
        CreatureAI* ia = viscidus->AI();
        SpellInfo const* givre = sSpellMgr->GetSpellInfo(TRAIT_DE_GIVRE);
        if (!ia || !givre)
            return;
        for (uint32 i = 0; i < COUPS_GIVRE; ++i)
            ia->SpellHit(attaquant, givre);
        for (uint32 i = 0; i < COUPS_MELEE; ++i)
        {
            uint32 zero = 0;
            ia->DamageTaken(attaquant, zero, DIRECT_DAMAGE, SPELL_SCHOOL_MASK_NORMAL);
        }
    }

    // Déclencheurs des cubes de Magtheridon (un par cube).
    std::vector<Creature*> DeclencheursCubes(Player* player)
    {
        std::vector<Creature*> resultat;
        std::list<GameObject*> cubes;
        player->GetGameObjectListWithEntryInGrid(cubes, CUBE_MANTICRON, 200.0f);
        for (GameObject* cube : cubes)
            if (Creature* d = cube->FindNearestCreature(DECLENCHEUR_FLAMMES_INFERNALES, 10.0f))
                resultat.push_back(d);
        return resultat;
    }
}

class solazeroth_raids_anciens_carte : public AllMapScript
{
public:
    solazeroth_raids_anciens_carte() : AllMapScript("solazeroth_raids_anciens_carte", {
        ALLMAPHOOK_ON_PLAYER_ENTER_ALL, ALLMAPHOOK_ON_PLAYER_LEAVE_ALL, ALLMAPHOOK_ON_MAP_UPDATE }) { }

    void OnPlayerEnterAll(Map* map, Player* player) override
    {
        if (map->IsDungeon() && JoueurSeul(map) == player)
            Proteger(player, map, true);
    }

    void OnPlayerLeaveAll(Map* map, Player* player) override
    {
        if (map->IsDungeon())
            Proteger(player, map, false);
    }

    void OnMapUpdate(Map* map, uint32 /*ecoule*/) override
    {
        if (map->GetId() != KARAZHAN && map->GetId() != PUITS_SOLEIL)
            return;
        Player* player = JoueurSeul(map);
        if (!player || !player->IsAlive() || !player->IsInCombat())
            return;
        if (map->GetId() == KARAZHAN)
        {
            if (Creature* dedain = player->FindNearestCreature(NETHERSPITE, 200.0f))
                for (uint32 sort : { RAYONS_DEDAIN_1, RAYONS_DEDAIN_2, RAYONS_DEDAIN_3 })
                {
                    SpellInfo const* info = sSpellMgr->GetSpellInfo(sort);
                    if (info && !dedain->IsImmunedToSpell(info))
                        dedain->ApplySpellImmune(0, IMMUNITY_ID, sort, true);
                    dedain->RemoveAurasDueToSpell(sort);
                }
        }
        else if (Aura* taillade = player->GetAura(TAILLADE); taillade && taillade->GetStackAmount() > 2)
            taillade->SetStackAmount(2);
    }
};

class solazeroth_raids_anciens_unites : public UnitScript
{
public:
    solazeroth_raids_anciens_unites() : UnitScript("solazeroth_raids_anciens_unites", true, {
        UNITHOOK_ON_DAMAGE, UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN,
        UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK, UNITHOOK_MODIFY_HEAL_RECEIVED, UNITHOOK_ON_AURA_APPLY,
        UNITHOOK_ON_AURA_REMOVE }) { }

    void OnDamage(Unit* attaquant, Unit* victime, uint32& degats) override
    {
        if (partageEnCours || !attaquant || !victime || !degats || !victime->IsCreature())
            return;
        Player* player = attaquant->GetCharmerOrOwnerPlayerOrPlayerItself();
        if (!player || JoueurSeul(victime->GetMap()) != player)
            return;
        switch (victime->GetMapId())
        {
            case ZUL_GURUB:    Partager(attaquant, victime, degats, TRIO_THEKAL); break;
            case KARAZHAN:     Partager(attaquant, victime, degats, AMANTS); break;
            case PUITS_SOLEIL: Partager(attaquant, victime, degats, { KALECGOS, SATHROVARR }, true); break;
            case AHN_QIRAJ:
                if (victime->GetEntry() == VISCIDUS)
                    CompterViscidus(attaquant, victime->ToCreature());
                break;
            default:
                break;
        }
    }

    // Sathrovarr ne blesse plus Kalec quand le joueur est seul (il ne peut pas venir l'aider).
    static bool Epargner(Unit* cible, Unit* attaquant)
    {
        return cible && attaquant && cible->GetEntry() == KALEC && attaquant->GetEntry() == SATHROVARR && Seul(cible);
    }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override
    {
        if (Epargner(cible, attaquant))
            degats = 0;
    }

    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* /*sort*/) override
    {
        if (Epargner(cible, attaquant))
            degats = 0;
    }

    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* /*sort*/) override
    {
        if (Epargner(cible, attaquant))
            degats = 0;
    }

    void ModifyHealReceived(Unit* cible, Unit* /*soigneur*/, uint32& soin, SpellInfo const* sort) override
    {
        if (sort && sort->Id == SOIN_FRATERNEL && cible && cible->GetMapId() == AHN_QIRAJ && Seul(cible))
            soin = 0;
    }

    void OnAuraApply(Unit* unite, Aura* aura) override
    {
        if (!unite || !aura || !Seul(unite))
            return;
        uint32 sort = aura->GetId();
        if (sort == POIGNE_OMBRE && unite->IsPlayer() && unite->GetMapId() == MAGTHERIDON)
        {
            for (Creature* d : DeclencheursCubes(unite->ToPlayer()))
                if (!d->HasUnitState(UNIT_STATE_CASTING))
                    d->CastSpell((Unit*)nullptr, POIGNE_VISUEL);
        }
        else if (sort == BOUCLIER_MAREE && unite->GetEntry() == NAJENTUS)
        {
            if (Player* player = JoueurSeul(unite->GetMap()))
                player->CastSpell(player, INVOQUER_EPINE, true);
        }
    }

    void OnAuraRemove(Unit* unite, AuraApplication* application, AuraRemoveMode /*mode*/) override
    {
        if (!unite || !application || application->GetBase()->GetId() != POIGNE_OMBRE || !unite->IsPlayer()
            || unite->GetMapId() != MAGTHERIDON || !Seul(unite))
            return;
        for (Creature* d : DeclencheursCubes(unite->ToPlayer()))
            d->InterruptNonMeleeSpells(false);
    }
};

void AddSC_solazeroth_raids_anciens()
{
    new solazeroth_raids_anciens_carte();
    new solazeroth_raids_anciens_unites();
}
