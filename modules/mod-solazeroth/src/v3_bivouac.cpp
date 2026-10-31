// v3 (31/10/2026) : potion et feu de camp, rang de départ (document v3, F7). Deux boutons à droite des techniques
// (SolUI_Bivouac.lua), pour ne plus attendre que la vie remonte seule entre deux combats.
// - Potion de soins (100029) : rend SOIN_POTION % de la vie maximale. CHARGES charge(s), gardée(s) en base ; elles
//   reviennent toutes avec le Repos au coin du feu, et en zone de repos (auberge, ville).
// - Feu de camp (100030) : pose un feu pour 2 minutes (objet 29784, comme le Feu de camp simple de Blizzard), sans le
//   Feu douillet de Blizzard (+4 esprit, piège lié au feu). Le personnage s'assoit aussitôt ; se lever, entrer en
//   combat ou mourir éteint le feu (31/10/2026, demande de l'utilisateur). Assis : REGEN_FEU % de la vie toutes les
//   2 s, et au bout de 60 s le Repos au coin du feu (100031, vie maximale +5 % pendant 30 minutes) et les potions.
// - Repos au coin du feu : hors combat, REGEN_REPOS % de la vie maximale par seconde (demande du 31/10/2026 ; à
//   améliorer par rang avec F7, comme le bonus de vie).
// L'interface reçoit « ETAT;charges;max;secondes avant le Repos » (préfixe SOLBIV) : compte à rebours du feu.
// Les sorts sont générés par outils\bivouac_v3.py (migration 067) ; les améliorations par rang viendront avec F7.

#include "SolAzeroth.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "ObjectAccessor.h"
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
    uint32 const FEU_DOUILLET = 7353;       // aura du piège lié au feu de Blizzard
    uint32 const OBJET_FEU = 29784;
    uint32 const TICK = 2000;
    uint32 const TICK_FEU = 250;            // se lever éteint le feu presque aussitôt
    uint32 const RECHERCHE_FEU = 3000;      // délai pour trouver le feu après l'incantation
    uint32 const RENVOI = 10000;            // l'état repart au moins toutes les 10 s : l'interface le retrouve après un /reload
    uint32 const ASSIS_POUR_REPOS = 60000;
    float const PORTEE_FEU = 10.0f;
    uint8 const CHARGES = 1;
    float const SOIN_POTION = 30.0f;
    float const REGEN_FEU = 6.0f;
    float const REGEN_REPOS = 1.0f;         // par seconde, hors combat

    struct Bivouac : DataMap::Base
    {
        uint8 charges = CHARGES;
        uint32 attente = 0;
        uint32 depuisEnvoi = RENVOI;
        uint32 attenteFeu = 0;
        uint32 assis = 0;
        bool allume = false;                // feu de camp lancé, pas encore éteint
        uint32 depuisAllumage = 0;
        ObjectGuid feu;
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
        // Dernier champ : secondes avant le Repos au coin du feu (0 hors du feu), pour le compte à rebours de l'interface.
        uint32 restant = b->allume && b->feu && b->assis < ASSIS_POUR_REPOS ? (ASSIS_POUR_REPOS - b->assis) / 1000 : 0;
        std::string message = Acore::StringFormat("ETAT;{};{};{}", b->charges, CHARGES, restant);
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
    GameObject* ChercherSonFeu(Player* player)
    {
        GameObject* feu = player->FindNearestGameObject(OBJET_FEU, PORTEE_FEU, true);
        return feu && feu->GetOwnerGUID() == player->GetGUID() && feu->GetSpellId() == FEU ? feu : nullptr;
    }

    void Eteindre(Player* player)
    {
        Bivouac* b = BivouacDe(player);
        if (GameObject* feu = b->feu ? ObjectAccessor::GetGameObject(*player, b->feu) : nullptr)
        {
            if (GameObject* piege = feu->GetLinkedTrap())
                piege->Delete();
            feu->Delete();
        }
        player->RemoveAurasDueToSpell(FEU_DOUILLET);
        b->feu.Clear();
        b->allume = false;
        b->assis = 0;
    }

    // Le feu vient d'apparaître : on retire son piège (le Feu douillet de Blizzard).
    void Adopter(Player* player, GameObject* feu)
    {
        BivouacDe(player)->feu = feu->GetGUID();
        if (GameObject* piege = feu->GetLinkedTrap())
            piege->Delete();
        player->RemoveAurasDueToSpell(FEU_DOUILLET);
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

class spell_solazeroth_v3_feu : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_feu);

    void Asseoir()
    {
        Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        if (!joueur)
            return;
        Bivouac* b = BivouacDe(joueur);
        b->feu.Clear();
        b->allume = true;
        b->depuisAllumage = 0;
        b->assis = 0;
        joueur->SetStandState(UNIT_STAND_STATE_SIT);
        if (GameObject* feu = ChercherSonFeu(joueur))
            Adopter(joueur, feu);
    }

    void Register() override
    {
        AfterCast += SpellCastFn(spell_solazeroth_v3_feu::Asseoir);
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
        b->attenteFeu += diff;

        if (b->allume && b->attenteFeu >= TICK_FEU)
        {
            b->attenteFeu = 0;
            b->depuisAllumage += TICK_FEU;
            if (!b->feu)
            {
                if (GameObject* feu = ChercherSonFeu(player))
                    Adopter(player, feu);
                else if (b->depuisAllumage >= RECHERCHE_FEU)
                    b->allume = false;
            }
            else if (!ObjectAccessor::GetGameObject(*player, b->feu))
            {
                // Le feu a fini de brûler.
                b->feu.Clear();
                b->allume = false;
                b->assis = 0;
            }
            else if (!player->IsSitState() || player->IsInCombat() || !player->IsAlive())
                Eteindre(player);
        }

        if (b->attente < TICK)
            return;
        b->attente = 0;

        if (player->HasPlayerFlag(PLAYER_FLAGS_RESTING))
            FixerCharges(player, CHARGES);

        if (b->allume && b->feu && player->IsSitState())
        {
            bool avant = b->assis < ASSIS_POUR_REPOS;
            b->assis += TICK;
            player->ModifyHealth(int32(std::lround(player->GetMaxHealth() * REGEN_FEU / 100.0f)));
            if (avant && b->assis >= ASSIS_POUR_REPOS)
            {
                player->CastSpell(player, REPOS, true);
                FixerCharges(player, CHARGES);
            }
        }

        if (player->HasAura(REPOS) && !player->IsInCombat() && player->IsAlive() && !player->IsFullHealth())
            player->ModifyHealth(int32(std::lround(player->GetMaxHealth() * REGEN_REPOS * TICK / 1000 / 100.0f)));

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
    RegisterSpellScript(spell_solazeroth_v3_feu);
}
