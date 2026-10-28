// Ulduar seul (section 4.7, V6 ; même règle que la Citadelle et Naxxramas : adapter chaque mécanique impossible seul en
// gardant l'esprit du combat). Ne joue que lorsqu'un seul joueur est dans l'instance.
// - Freya : le trio de la première vague (flagellant cassant, flagellant tempétueux, esprit de l'eau ancien) revient à
//   la vie si les trois ne tombent pas à moins de 11 s d'écart. Seul, les dégâts faits à l'un sont faits aux deux
//   autres, en proportion de leur vie.
// - Mimiron : en phase 4, les trois machines doivent tomber ensemble. Seul, même partage des dégâts entre elles.
// - Hodir : un joueur pris dans le Gel instantané attend qu'on brise sa glace. Seul, elle se brise au bout de 5 s.
// - Yogg-Saron : un tentacule constricteur serre le joueur jusqu'à ce qu'on le tue. Seul, il meurt au bout de 3 s.
// - Algalon : à 5 Coups de phase, le tank passe dans une autre phase et un autre doit prendre le boss. Seul, le Coup
//   de phase plafonne à 4 piles.

#include "SolAzeroth.h"
#include "Creature.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuras.h"
#include "SpellMgr.h"
#include <algorithm>
#include <unordered_map>
#include <vector>

namespace
{
    uint32 const ULDUAR = 603;

    enum Sorts : uint32
    {
        GEL_INSTANTANE   = 61969,   // joueur pris dans la glace
        ETREINTE         = 64125,   // tentacule constricteur
        COUP_DE_PHASE    = 64412,
        PHASE_DECALEE    = 64417,   // effet de la 5e pile
    };

    enum Creatures : uint32
    {
        GLACE_HODIR      = 32926,
        CONSTRICTEUR     = 33983,
        FLAGELLANT_CASSANT    = 32916,
        FLAGELLANT_TEMPETUEUX = 32919,
        ESPRIT_DE_L_EAU       = 33202,
        LEVIATHAN_MK_II  = 33432,
        VX_001           = 33651,
        UNITE_AERIENNE   = 33670,
    };

    std::vector<uint32> const TRIO_FREYA = { FLAGELLANT_CASSANT, FLAGELLANT_TEMPETUEUX, ESPRIT_DE_L_EAU };
    std::vector<uint32> const MACHINES_MIMIRON = { LEVIATHAN_MK_II, VX_001, UNITE_AERIENNE };

    std::unordered_map<ObjectGuid, uint32> geles;    // joueur -> ms passées dans le Gel instantané
    std::unordered_map<ObjectGuid, uint32> serres;   // joueur -> ms passées dans l'Étreinte
    uint32 attente = 0;
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

    // Après `delai` ms sous l'aura `sort`, tue la créature `piege` qui retient le joueur.
    void Liberer(Player* player, std::unordered_map<ObjectGuid, uint32>& suivi, uint32 pas, uint32 sort, uint32 piege,
        uint32 delai, float portee)
    {
        ObjectGuid guid = player->GetGUID();
        if (!player->HasAura(sSpellMgr->GetSpellIdForDifficulty(sort, player)))
        {
            suivi.erase(guid);
            return;
        }
        if ((suivi[guid] += pas) < delai)
            return;
        if (Creature* c = player->FindNearestCreature(piege, portee))
            Unit::Kill(c, c);
        suivi.erase(guid);
    }

    // Groupe de créatures qui doivent tomber ensemble ; `toutes` : ne partager que si le groupe entier est attaquable.
    bool Partager(Unit* attaquant, Unit* victime, uint32 degats, std::vector<uint32> const& groupe, bool toutes)
    {
        if (std::find(groupe.begin(), groupe.end(), victime->GetEntry()) == groupe.end())
            return false;
        std::vector<Creature*> autres;
        for (uint32 entree : groupe)
        {
            if (entree == victime->GetEntry())
                continue;
            Creature* c = victime->FindNearestCreature(entree, 200.0f);
            bool attaquable = c && c->IsInCombat()
                && !c->HasUnitFlag(UnitFlags(UNIT_FLAG_NON_ATTACKABLE | UNIT_FLAG_NOT_SELECTABLE));
            if (attaquable)
                autres.push_back(c);
            else if (toutes)
                return true;
        }
        float part = float(degats) / float(std::max<uint32>(victime->GetMaxHealth(), 1));
        partageEnCours = true;
        for (Creature* c : autres)
            Unit::DealDamage(attaquant, c, std::max<uint32>(1, uint32(part * c->GetMaxHealth())), nullptr, DIRECT_DAMAGE,
                SPELL_SCHOOL_MASK_NORMAL, nullptr, false);
        partageEnCours = false;
        return true;
    }
}

class solazeroth_ulduar_carte : public AllMapScript
{
public:
    solazeroth_ulduar_carte() : AllMapScript("solazeroth_ulduar_carte", { ALLMAPHOOK_ON_MAP_UPDATE }) { }

    void OnMapUpdate(Map* map, uint32 ecoule) override
    {
        if (map->GetId() != ULDUAR)
            return;
        attente += ecoule;
        if (attente < 500)
            return;
        uint32 pas = attente;
        attente = 0;

        Player* player = JoueurSeul(map);
        if (!player || !player->IsAlive())
            return;

        Liberer(player, geles, pas, GEL_INSTANTANE, GLACE_HODIR, 5 * IN_MILLISECONDS, 5.0f);
        Liberer(player, serres, pas, ETREINTE, CONSTRICTEUR, 3 * IN_MILLISECONDS, 15.0f);

        if (Aura* coup = player->GetAura(sSpellMgr->GetSpellIdForDifficulty(COUP_DE_PHASE, player)))
            if (coup->GetStackAmount() > 4)
                coup->SetStackAmount(4);
        player->RemoveAurasDueToSpell(PHASE_DECALEE);
    }
};

class solazeroth_ulduar_degats : public UnitScript
{
public:
    solazeroth_ulduar_degats() : UnitScript("solazeroth_ulduar_degats", true, { UNITHOOK_ON_DAMAGE }) { }

    void OnDamage(Unit* attaquant, Unit* victime, uint32& degats) override
    {
        if (partageEnCours || !attaquant || !victime || !degats || victime->GetMapId() != ULDUAR || !victime->IsCreature())
            return;
        Player* player = attaquant->GetCharmerOrOwnerPlayerOrPlayerItself();
        if (!player || JoueurSeul(victime->GetMap()) != player)
            return;
        if (!Partager(attaquant, victime, degats, TRIO_FREYA, false))
            Partager(attaquant, victime, degats, MACHINES_MIMIRON, true);
    }
};

void AddSC_solazeroth_ulduar()
{
    new solazeroth_ulduar_carte();
    new solazeroth_ulduar_degats();
}
