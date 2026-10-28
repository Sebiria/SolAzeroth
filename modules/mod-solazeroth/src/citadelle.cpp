// Citadelle de la Couronne de glace seul (section 4.7, V6 ; décision de l'utilisateur du 28/10/2026 : adapter chaque
// mécanique impossible seul, en gardant l'esprit du combat). Ne joue que lorsqu'un seul joueur est dans l'instance.
// - Pulentraille : le Gonflement gastrique plafonne à 6 piles (l'explosion vient à 10, prévue pour un changement de tank).
// - Professeur Putricide : la Peste mutée plafonne à 4 piles (même raison).
// - Reine Lana'thel : si un familier tient la reine et que le joueur est mordu, la Soif de sang frénétique (qui
//   demande de mordre un autre joueur) est retirée au lieu de finir en contrôle mental.
// - Valithria Marcherêve : chaque créature du combat tuée la soigne (6 % de sa vie, 1 % pour un ver putride), pour
//   qu'une classe sans soins puisse la remonter à 100 %. Les soins du joueur comptent toujours. Chaque soin est annoncé
//   dans la discussion (retour de test du 28/10/2026 : on ne comprenait pas quels monstres la soignaient).
// - Antichambre de Sindragosa : deux nérubiens nouveau-nés sur trois meurent dès leur arrivée (10 par vague au lieu
//   de 30, retour de test du 28/10/2026). Ils sont tués et non retirés : le script compte les morts pour passer à la
//   vague suivante.
// - Sindragosa : un Tombeau de glace se brise seul au bout de 5 s.
// - Roi-liche : une Val'kyr qui a saisi le joueur le lâche au bout de 3 s ; il est ramené au centre de la plateforme
//   et la Val'kyr disparaît.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Creature.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuras.h"
#include "SpellMgr.h"
#include <mutex>
#include <unordered_map>
#include <vector>

namespace
{
    uint32 const CITADELLE = 631;

    enum Sorts : uint32
    {
        GONFLEMENT_GASTRIQUE    = 72219,
        PESTE_MUTEE             = 72451,
        SOIF_DE_SANG_FRENETIQUE = 70877,
        TOMBEAU_DE_GLACE        = 70157,
    };

    enum Creatures : uint32
    {
        VALITHRIA   = 36789,
        TOMBEAU     = 36980,
        VALKYR      = 36609,
        VER_PUTRIDE = 37907,
        NOUVEAU_NE  = 37232,
    };

    // Créatures du combat de Valithria : archimage ressuscité, squelette flamboyant, suppresseur, zombie boursouflé,
    // abomination gloutonne, ver putride.
    struct SoinValithria { float pourcent; char const* nom; };
    std::unordered_map<uint32, SoinValithria> const SOINS_VALITHRIA = {
        { 37868, { 6.0f, "Archimage ressuscité" } }, { 36791, { 6.0f, "Squelette flamboyant" } },
        { 37863, { 6.0f, "Suppresseur" } }, { 37934, { 6.0f, "Zombie boursouflé" } },
        { 37886, { 6.0f, "Abomination gloutonne" } }, { VER_PUTRIDE, { 1.0f, "Ver putride" } } };

    std::mutex verrouNouveauxNes;
    std::vector<ObjectGuid> nouveauxNesATuer;   // deux nouveau-nés sur trois, tués au prochain passage de la carte
    uint32 compteNouveauxNes = 0;

    Position const CENTRE_TRONE = { 503.6282f, -2124.655f, 840.8569f, 0.0f };

    std::unordered_map<ObjectGuid, uint32> enfermes;   // joueur -> ms passées dans un Tombeau de glace
    std::unordered_map<ObjectGuid, uint32> saisis;     // joueur -> ms passées dans les bras d'une Val'kyr
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

    void Plafonner(Player* player, uint32 sort, uint8 maximum)
    {
        if (Aura* aura = player->GetAura(sSpellMgr->GetSpellIdForDifficulty(sort, player)))
            if (aura->GetStackAmount() > maximum)
                aura->SetStackAmount(maximum);
    }
}

class solazeroth_citadelle_carte : public AllMapScript
{
public:
    solazeroth_citadelle_carte() : AllMapScript("solazeroth_citadelle_carte", { ALLMAPHOOK_ON_MAP_UPDATE }) { }

    void OnMapUpdate(Map* map, uint32 ecoule) override
    {
        if (map->GetId() != CITADELLE)
            return;
        attente += ecoule;
        if (attente < 500)
            return;
        uint32 pas = attente;
        attente = 0;

        Player* player = JoueurSeul(map);
        if (!player || !player->IsAlive())
            return;

        {
            std::lock_guard<std::mutex> verrou(verrouNouveauxNes);
            for (ObjectGuid const& g : nouveauxNesATuer)
                if (Creature* c = map->GetCreature(g))
                    if (c->IsAlive())
                        Unit::Kill(c, c);
            nouveauxNesATuer.clear();
        }

        Plafonner(player, GONFLEMENT_GASTRIQUE, 6);
        Plafonner(player, PESTE_MUTEE, 4);
        player->RemoveAurasDueToSpell(sSpellMgr->GetSpellIdForDifficulty(SOIF_DE_SANG_FRENETIQUE, player));

        ObjectGuid guid = player->GetGUID();
        if (player->HasAura(sSpellMgr->GetSpellIdForDifficulty(TOMBEAU_DE_GLACE, player)))
        {
            if ((enfermes[guid] += pas) >= 5 * IN_MILLISECONDS)
            {
                if (Creature* tombeau = player->FindNearestCreature(TOMBEAU, 5.0f))
                    Unit::Kill(tombeau, tombeau);
                enfermes.erase(guid);
            }
        }
        else
            enfermes.erase(guid);

        Unit* porteur = player->GetVehicleBase();
        if (porteur && porteur->GetEntry() == VALKYR)
        {
            if ((saisis[guid] += pas) >= 3 * IN_MILLISECONDS)
            {
                player->ExitVehicle();
                player->NearTeleportTo(CENTRE_TRONE.GetPositionX(), CENTRE_TRONE.GetPositionY(), CENTRE_TRONE.GetPositionZ(),
                    player->GetOrientation());
                if (Creature* valkyr = porteur->ToCreature())
                    valkyr->DespawnOrUnsummon();
                saisis.erase(guid);
            }
        }
        else
            saisis.erase(guid);
    }
};

class solazeroth_citadelle_morts : public UnitScript
{
public:
    solazeroth_citadelle_morts() : UnitScript("solazeroth_citadelle_morts", true, { UNITHOOK_ON_UNIT_DEATH }) { }

    void OnUnitDeath(Unit* unit, Unit* tueur) override
    {
        if (!unit || !tueur || unit->GetMapId() != CITADELLE || !unit->IsCreature())
            return;
        auto soin = SOINS_VALITHRIA.find(unit->GetEntry());
        if (soin == SOINS_VALITHRIA.end())
            return;
        Player* player = tueur->GetCharmerOrOwnerPlayerOrPlayerItself();
        if (!player || JoueurSeul(unit->GetMap()) != player)
            return;
        Creature* valithria = unit->FindNearestCreature(VALITHRIA, 200.0f);
        if (!valithria || !valithria->IsInCombat())
            return;
        Unit::DealHeal(player, valithria, uint32(valithria->GetMaxHealth() * soin->second.pourcent / 100.0f));
        ChatHandler(player->GetSession()).PSendSysMessage("|cff40ff40{} tué : Valithria reprend {:.0f} % ({:.0f} %).|r",
            soin->second.nom, soin->second.pourcent, valithria->GetHealthPct());
    }
};

class solazeroth_citadelle_creatures : public AllCreatureScript
{
public:
    solazeroth_citadelle_creatures() : AllCreatureScript("solazeroth_citadelle_creatures") { }

    void OnCreatureAddWorld(Creature* creature) override
    {
        if (creature->GetEntry() != NOUVEAU_NE || creature->GetMapId() != CITADELLE || !JoueurSeul(creature->GetMap()))
            return;
        std::lock_guard<std::mutex> verrou(verrouNouveauxNes);
        if (++compteNouveauxNes % 3 != 0)
            nouveauxNesATuer.push_back(creature->GetGUID());
    }
};

void AddSC_solazeroth_citadelle()
{
    new solazeroth_citadelle_carte();
    new solazeroth_citadelle_morts();
    new solazeroth_citadelle_creatures();
}
