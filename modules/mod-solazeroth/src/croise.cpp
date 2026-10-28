// L'épreuve du croisé seul (section 4.7, V6 ; même règle que les autres raids : adapter chaque mécanique impossible
// seul en gardant l'esprit du combat). Ne joue que lorsqu'un seul joueur est dans l'instance.
// - Champions de faction : six champions joueurs (deux soigneurs) contre un seul joueur. Seul, les deux soigneurs et
//   un des quatre autres meurent dès leur arrivée : il en reste trois, sans soigneur. Ils sont tués et non retirés, car
//   le script compte leurs morts pour finir la rencontre.
// - Val'kyrs jumelles : le Pacte des jumelles se brise en vidant le bouclier qui l'accompagne, prévu pour tout un
//   groupe. Seul, le bouclier n'absorbe que 25 % de sa valeur.

#include "SolAzeroth.h"
#include "Creature.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellMgr.h"
#include <mutex>
#include <unordered_set>
#include <vector>

namespace
{
    uint32 const EPREUVE = 649;

    enum Sorts : uint32
    {
        BOUCLIER_LUMIERE = 65858,
        BOUCLIER_TENEBRES = 65874,
    };

    // Soigneurs des deux factions (druide, paladin, prêtre, chaman).
    std::unordered_set<uint32> const SOIGNEURS = { 34469, 34465, 34466, 34470, 34459, 34445, 34447, 34444 };
    // Autres champions des deux factions.
    std::unordered_set<uint32> const AUTRES = {
        34461, 34460, 34467, 34468, 34471, 34473, 34472, 34463, 34474, 34475,
        34458, 34451, 34448, 34449, 34456, 34441, 34454, 34455, 34450, 34453 };

    float const BOUCLIER_GARDE = 0.25f;

    std::mutex verrou;
    std::vector<ObjectGuid> aTuer;   // champions tués au prochain passage de la carte
    uint32 compteAutres = 0;
    uint32 attente = 0;

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
}

class solazeroth_croise_carte : public AllMapScript
{
public:
    solazeroth_croise_carte() : AllMapScript("solazeroth_croise_carte", { ALLMAPHOOK_ON_MAP_UPDATE }) { }

    void OnMapUpdate(Map* map, uint32 ecoule) override
    {
        if (map->GetId() != EPREUVE)
            return;
        attente += ecoule;
        if (attente < 500)
            return;
        attente = 0;
        if (!JoueurSeul(map))
            return;

        std::lock_guard<std::mutex> garde(verrou);
        for (ObjectGuid const& g : aTuer)
            if (Creature* c = map->GetCreature(g))
                if (c->IsAlive())
                    Unit::Kill(c, c);
        aTuer.clear();
    }
};

class solazeroth_croise_creatures : public AllCreatureScript
{
public:
    solazeroth_croise_creatures() : AllCreatureScript("solazeroth_croise_creatures") { }

    void OnCreatureAddWorld(Creature* creature) override
    {
        if (creature->GetMapId() != EPREUVE || !JoueurSeul(creature->GetMap()))
            return;
        bool soigneur = SOIGNEURS.count(creature->GetEntry()) > 0;
        if (!soigneur && !AUTRES.count(creature->GetEntry()))
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (soigneur || ++compteAutres % 4 == 0)
            aTuer.push_back(creature->GetGUID());
    }
};

class solazeroth_croise_auras : public UnitScript
{
public:
    solazeroth_croise_auras() : UnitScript("solazeroth_croise_auras", true, { UNITHOOK_ON_AURA_APPLY }) { }

    void OnAuraApply(Unit* unit, Aura* aura) override
    {
        if (!unit || !aura || unit->GetMapId() != EPREUVE || !JoueurSeul(unit->GetMap()))
            return;
        uint32 id = aura->GetId();
        if (id != sSpellMgr->GetSpellIdForDifficulty(BOUCLIER_LUMIERE, unit)
            && id != sSpellMgr->GetSpellIdForDifficulty(BOUCLIER_TENEBRES, unit))
            return;
        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            if (AuraEffect* effet = aura->GetEffect(i))
                if (effet->GetAuraType() == SPELL_AURA_SCHOOL_ABSORB)
                    effet->ChangeAmount(int32(effet->GetAmount() * BOUCLIER_GARDE));
    }
};

void AddSC_solazeroth_croise()
{
    new solazeroth_croise_carte();
    new solazeroth_croise_creatures();
    new solazeroth_croise_auras();
}
