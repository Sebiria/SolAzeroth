// v3 (31/10/2026) : potion et feu de camp, rang de départ (document v3, F7). Deux boutons à droite des techniques
// (SolUI_Bivouac.lua), pour ne plus attendre que la vie remonte seule entre deux combats.
// - Potion de soins (100029) : rend SOIN_POTION % de la vie maximale. CHARGES charges, gardées en base ; elles
//   reviennent une par une assis près de son feu, et toutes d'un coup en zone de repos (auberge, ville).
// - Feu de camp (100030) : pose un feu pour 2 minutes (objet 29784, comme le Feu de camp simple de Blizzard). Assis à
//   moins de PORTEE_FEU mètres de son propre feu, hors combat : REGEN_FEU % de la vie toutes les 2 s, une charge de
//   potion toutes les 15 s, et au bout de 60 s le Repos au coin du feu (100031, vie maximale +5 % pendant 10 minutes).
// Les sorts sont générés par outils\bivouac_v3.py (migration 067) ; les améliorations par rang viendront avec F7.

#include "SolAzeroth.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "StringFormat.h"
#include <cmath>

namespace
{
    char const* const PREFIXE = "SOLBIV";
    uint32 const POTION = 100029;
    uint32 const FEU = 100030;
    uint32 const REPOS = 100031;
    uint32 const OBJET_FEU = 29784;
    uint32 const TICK = 2000;
    uint32 const RENVOI = 10000;            // l'état repart au moins toutes les 10 s : l'interface le retrouve après un /reload
    uint32 const ASSIS_POUR_REPOS = 60000;
    uint32 const ASSIS_PAR_CHARGE = 15000;
    float const PORTEE_FEU = 5.0f;
    uint8 const CHARGES = 3;
    float const SOIN_POTION = 30.0f;
    float const REGEN_FEU = 6.0f;

    struct Bivouac : DataMap::Base
    {
        uint8 charges = CHARGES;
        uint32 attente = 0;
        uint32 depuisEnvoi = RENVOI;
        uint32 assis = 0;
        uint32 versCharge = 0;
        std::string envoye;
    };

    Bivouac* BivouacDe(Player* player)
    {
        return player->CustomData.GetDefault<Bivouac>("solazeroth_v3_bivouac");
    }

    void Sauver(Player* player)
    {
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_bivouac (guid, charges) VALUES ({}, {})",
            player->GetGUID().GetCounter(), BivouacDe(player)->charges);
    }

    void Envoyer(Player* player, bool force = false)
    {
        Bivouac* b = BivouacDe(player);
        std::string message = Acore::StringFormat("ETAT;{};{}", b->charges, CHARGES);
        if (!force && message == b->envoye)
            return;
        b->envoye = message;
        b->depuisEnvoi = 0;
        SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
    }

    void FixerCharges(Player* player, uint8 charges)
    {
        Bivouac* b = BivouacDe(player);
        if (charges == b->charges)
            return;
        b->charges = charges;
        Sauver(player);
        Envoyer(player);
    }

    // Son propre feu, posé par le sort, à portée.
    bool PresDeSonFeu(Player* player)
    {
        GameObject* feu = player->FindNearestGameObject(OBJET_FEU, PORTEE_FEU, true);
        return feu && feu->GetOwnerGUID() == player->GetGUID() && feu->GetSpellId() == FEU;
    }
}

class spell_solazeroth_v3_potion : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_potion);

    SpellCastResult Verifier()
    {
        Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        return joueur && BivouacDe(joueur)->charges > 0 ? SPELL_CAST_OK : SPELL_FAILED_NO_CHARGES_REMAIN;
    }

    void Soigner()
    {
        if (Unit* lanceur = GetCaster())
            SetHitHeal(int32(std::lround(lanceur->GetMaxHealth() * SOIN_POTION / 100.0f)));
    }

    void Consommer()
    {
        if (Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr)
            FixerCharges(joueur, BivouacDe(joueur)->charges - 1);
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_potion::Verifier);
        OnHit += SpellHitFn(spell_solazeroth_v3_potion::Soigner);
        AfterCast += SpellCastFn(spell_solazeroth_v3_potion::Consommer);
    }
};

class solazeroth_v3_bivouac_joueur : public PlayerScript
{
public:
    solazeroth_v3_bivouac_joueur() : PlayerScript("solazeroth_v3_bivouac_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_DELETE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Bivouac* b = BivouacDe(player);
        if (QueryResult r = CharacterDatabase.Query("SELECT charges FROM solazeroth_v3_bivouac WHERE guid = {}",
            player->GetGUID().GetCounter()))
            b->charges = std::min<uint8>((*r)[0].Get<uint8>(), CHARGES);
        for (uint32 sort : { POTION, FEU })
            if (!player->HasSpell(sort))
                player->learnSpell(sort);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Bivouac* b = BivouacDe(player);
        b->attente += diff;
        b->depuisEnvoi += diff;
        if (b->attente < TICK)
            return;
        b->attente = 0;

        if (player->HasPlayerFlag(PLAYER_FLAGS_RESTING))
            FixerCharges(player, CHARGES);

        if (player->IsAlive() && !player->IsInCombat() && player->IsSitState() && PresDeSonFeu(player))
        {
            b->assis += TICK;
            b->versCharge += TICK;
            player->ModifyHealth(int32(std::lround(player->GetMaxHealth() * REGEN_FEU / 100.0f)));
            if (b->versCharge >= ASSIS_PAR_CHARGE)
            {
                b->versCharge = 0;
                if (b->charges < CHARGES)
                    FixerCharges(player, b->charges + 1);
            }
            if (b->assis >= ASSIS_POUR_REPOS && !player->HasAura(REPOS))
                player->CastSpell(player, REPOS, true);
        }
        else
            b->assis = b->versCharge = 0;

        Envoyer(player, b->depuisEnvoi >= RENVOI);
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_bivouac WHERE guid = {}", guid.GetCounter());
    }
};

void AddSC_solazeroth_v3_bivouac()
{
    new solazeroth_v3_bivouac_joueur();
    RegisterSpellScript(spell_solazeroth_v3_potion);
}
