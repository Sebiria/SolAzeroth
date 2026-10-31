// v3, F3 (31/10/2026) : kit du guerrier tank (document v3, partie 3 et F3).
// - La spécialisation se choisit à l'entrée en jeu (.kit spe tank, depuis la page Techniques de /sol). Pour l'instant,
//   seul le guerrier tank existe. Elle donne d'emblée le passif Rempart et les 4 premières techniques.
// - Tous les 5 points de puissance, une technique de plus se débloque, dans l'ordre de ORDRE (proposition de Claude,
//   à corriger) : les 16 sont ouvertes à 60. 8 au plus sont équipées ; le choix se fait hors combat (.kit equiper).
//   Les techniques équipées sont apprises et posées sur la barre, les autres oubliées. Les anciens sorts du guerrier
//   (postures, Frappe héroïque…) sont retirés.
// - Rempart : chaque coup encaissé, après l'armure, verse SolAzeroth.V3.Rempart.Part % de ses dégâts dans un bouclier
//   (aura 100010, absorption), plafonné à SolAzeroth.V3.Rempart.Plafond % de la vie maximale. Hors combat, il perd
//   SolAzeroth.V3.Rempart.Fuite % de la vie maximale toutes les 2 secondes. Riposte du rempart et Second souffle le
//   consomment, Vengeance le demande plein, Frappe du bouclier et Dernier rempart le remplissent.
// Les sorts eux-mêmes (copies retouchées de sorts de Blizzard) sont générés par outils\techniques_v3.py (migration 061).

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "StringFormat.h"
#include <cmath>
#include <sstream>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLKIT";
    uint32 const TICK_KIT = 2000;
    uint32 const TICK_REMPART = 250;
    uint8 const SPE_AUCUNE = 0;
    uint8 const SPE_GUERRIER_TANK = 1;
    uint32 const PASSIF_REMPART = 100009;
    uint32 const REMPART = 100010;
    size_t const DE_DEPART = 4;
    size_t const EQUIPEES_MAX = 8;
    float const PUISSANCE_PAR_TECHNIQUE = 5.0f;

    struct Technique
    {
        uint32 sort;
        char const* nom;
    };

    // Ordre de déblocage : les 4 premières dès le départ, puis une tous les 5 points de puissance (5, 10… 60).
    Technique const ORDRE[] =
    {
        { 100011, "Frappe du bouclier" },
        { 100012, "Coup de tonnerre" },
        { 100013, "Charge" },
        { 100014, "Riposte du rempart" },
        { 100015, "Cri de défi" },          // 5
        { 100016, "Second souffle" },       // 10
        { 100017, "Ravage" },               // 15
        { 100018, "Mur protecteur" },       // 20
        { 100019, "Heurt de bouclier" },    // 25
        { 100020, "Fracasser armure" },     // 30
        { 100021, "Désarmement" },          // 35
        { 100022, "Onde de choc" },         // 40
        { 100023, "Bond héroïque" },        // 45
        { 100024, "Renvoi de sort" },       // 50
        { 100025, "Vengeance" },            // 55
        { 100026, "Dernier rempart" },      // 60
    };
    size_t const NB_TECHNIQUES = std::size(ORDRE);

    struct Reglages
    {
        float part = 40.0f;
        float plafond = 30.0f;
        float fuite = 1.0f;
        float frappe = 8.0f;
    } reglages;

    struct Kit : DataMap::Base
    {
        uint8 spe = SPE_AUCUNE;
        std::vector<uint32> equipees;
        size_t debloquees = 0;              // 0 : pas encore appliqué depuis la connexion
        uint32 attente = 0;
        uint32 attenteRempart = 0;
        std::string rempartEnvoye;
    };

    Kit* KitDe(Player* player)
    {
        return player->CustomData.GetDefault<Kit>("solazeroth_v3_kit");
    }

    bool EstTechnique(uint32 sort)
    {
        for (Technique const& t : ORDRE)
            if (t.sort == sort)
                return true;
        return false;
    }

    char const* NomDe(uint32 sort)
    {
        for (Technique const& t : ORDRE)
            if (t.sort == sort)
                return t.nom;
        return "?";
    }

    size_t Debloquees(Player* player)
    {
        float puissance = SolAzeroth::PuissanceJoueur(player);
        return std::min(NB_TECHNIQUES, DE_DEPART + size_t(std::max(0.0f, puissance) / PUISSANCE_PAR_TECHNIQUE));
    }

    bool EstDebloquee(uint32 sort, size_t debloquees)
    {
        for (size_t i = 0; i < debloquees; ++i)
            if (ORDRE[i].sort == sort)
                return true;
        return false;
    }

    void Sauver(Player* player)
    {
        Kit* kit = KitDe(player);
        std::string liste;
        for (uint32 sort : kit->equipees)
            liste += (liste.empty() ? "" : " ") + std::to_string(sort);
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_kit (guid, spe, equipees) VALUES ({}, {}, '{}')",
            player->GetGUID().GetCounter(), kit->spe, liste);
    }

    // ---------------------------------------------------------------- Rempart

    int32 Plafond(Unit* unite)
    {
        return int32(unite->GetMaxHealth() * reglages.plafond / 100.0f);
    }

    AuraEffect* Bouclier(Unit* unite)
    {
        return unite->GetAuraEffect(REMPART, EFFECT_0);
    }

    int32 Montant(Unit* unite)
    {
        AuraEffect* effet = Bouclier(unite);
        return effet ? std::max(0, effet->GetAmount()) : 0;
    }

    void Fixer(Unit* unite, int32 montant)
    {
        montant = std::min(montant, Plafond(unite));
        AuraEffect* effet = Bouclier(unite);
        if (montant <= 0)
        {
            if (effet)
                unite->RemoveAurasDueToSpell(REMPART);
            return;
        }
        if (!effet)
        {
            Aura* aura = unite->AddAura(REMPART, unite);
            effet = aura ? aura->GetEffect(EFFECT_0) : nullptr;
            if (!effet)
                return;
        }
        effet->SetAmount(montant);
    }

    void Ajouter(Unit* unite, int32 montant)
    {
        if (montant > 0)
            Fixer(unite, Montant(unite) + montant);
    }

    int32 Vider(Unit* unite)
    {
        int32 montant = Montant(unite);
        Fixer(unite, 0);
        return montant;
    }

    bool PorteLeRempart(Unit* unite)
    {
        Player* player = unite ? unite->ToPlayer() : nullptr;
        return player && KitDe(player)->spe == SPE_GUERRIER_TANK;
    }

    // ---------------------------------------------------------------- Techniques apprises et barre d'action

    void Envoyer(Player* player)
    {
        Kit* kit = KitDe(player);
        size_t debloquees = Debloquees(player);
        std::string message = Acore::StringFormat("ETAT;{};{:.0f};{};", kit->spe, SolAzeroth::PuissanceJoueur(player),
            debloquees < NB_TECHNIQUES ? uint32(PUISSANCE_PAR_TECHNIQUE * (debloquees - DE_DEPART + 1)) : 0);
        for (size_t i = 0; i < NB_TECHNIQUES; ++i)
        {
            bool equipee = std::find(kit->equipees.begin(), kit->equipees.end(), ORDRE[i].sort) != kit->equipees.end();
            message += Acore::StringFormat("{}{}:{}", i ? "," : "", ORDRE[i].sort, i >= debloquees ? 0 : (equipee ? 2 : 1));
        }
        SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
    }

    void PoserSurLaBarre(Player* player)
    {
        Kit* kit = KitDe(player);
        // Boutons des sorts oubliés (anciens sorts du guerrier, techniques retirées) : vidés.
        for (uint8 bouton = 0; bouton < MAX_ACTION_BUTTONS; ++bouton)
            if (ActionButton const* b = player->GetActionButton(bouton))
                if (b->GetType() == ACTION_BUTTON_SPELL && !player->HasSpell(b->GetAction()))
                    player->removeActionButton(bouton);
        for (uint32 sort : kit->equipees)
        {
            bool posee = false;
            for (uint8 bouton = 0; bouton < MAX_ACTION_BUTTONS && !posee; ++bouton)
                if (ActionButton const* b = player->GetActionButton(bouton))
                    posee = b->GetType() == ACTION_BUTTON_SPELL && b->GetAction() == sort;
            for (uint8 bouton = 0; bouton < MAX_ACTION_BUTTONS && !posee; ++bouton)
                if (!player->GetActionButton(bouton))
                    posee = player->addActionButton(bouton, sort, ACTION_BUTTON_SPELL) != nullptr;
        }
        player->SendActionButtons(1);
    }

    void Appliquer(Player* player)
    {
        Kit* kit = KitDe(player);
        if (player->getClass() != CLASS_WARRIOR)
            return;

        // Anciens sorts du guerrier : postures, Frappe héroïque… Les techniques v3 sont hors de la famille du guerrier.
        std::vector<uint32> anciens;
        for (auto const& [sort, etat] : player->GetSpellMap())
            if (etat->State != PLAYERSPELL_REMOVED)
                if (SpellInfo const* info = sSpellMgr->GetSpellInfo(sort))
                    if (info->SpellFamilyName == SPELLFAMILY_WARRIOR)
                        anciens.push_back(sort);
        for (uint32 sort : anciens)
            player->removeSpell(sort, SPEC_MASK_ALL, false);

        size_t debloquees = kit->spe == SPE_GUERRIER_TANK ? Debloquees(player) : 0;
        if (kit->debloquees && debloquees > kit->debloquees)
            for (size_t i = kit->debloquees; i < debloquees; ++i)
                ChatHandler(player->GetSession()).PSendSysMessage("|cff40c0ffNouvelle technique débloquée : {}.|r "
                    "Choisis tes 8 techniques dans /sol, page Techniques.", ORDRE[i].nom);
        kit->debloquees = std::max<size_t>(debloquees, 1);

        // Techniques équipées : seulement celles qui sont débloquées, complétées dans l'ordre jusqu'à 8.
        std::vector<uint32> equipees;
        for (uint32 sort : kit->equipees)
            if (EstDebloquee(sort, debloquees) && std::find(equipees.begin(), equipees.end(), sort) == equipees.end()
                && equipees.size() < EQUIPEES_MAX)
                equipees.push_back(sort);
        for (size_t i = 0; i < debloquees && equipees.size() < EQUIPEES_MAX; ++i)
            if (std::find(equipees.begin(), equipees.end(), ORDRE[i].sort) == equipees.end())
                equipees.push_back(ORDRE[i].sort);
        if (equipees != kit->equipees)
        {
            kit->equipees = equipees;
            Sauver(player);
        }

        for (Technique const& t : ORDRE)
        {
            bool equipee = std::find(equipees.begin(), equipees.end(), t.sort) != equipees.end();
            if (equipee && !player->HasSpell(t.sort))
                player->learnSpell(t.sort);
            else if (!equipee && player->HasSpell(t.sort))
                player->removeSpell(t.sort, SPEC_MASK_ALL, false);
        }
        bool passif = kit->spe == SPE_GUERRIER_TANK;
        if (passif && !player->HasSpell(PASSIF_REMPART))
            player->learnSpell(PASSIF_REMPART);
        else if (!passif && player->HasSpell(PASSIF_REMPART))
            player->removeSpell(PASSIF_REMPART, SPEC_MASK_ALL, false);

        PoserSurLaBarre(player);
        Envoyer(player);
    }
}

// ---------------------------------------------------------------- Sorts

class spell_solazeroth_v3_rempart : public AuraScript
{
    PrepareAuraScript(spell_solazeroth_v3_rempart);

    // Un coup absorbé remplit aussi le Rempart (le moteur retire ensuite la part absorbée).
    void Absorbe(AuraEffect* effet, DamageInfo& /*degats*/, uint32& absorbe)
    {
        Unit* cible = GetTarget();
        int32 apport = int32(std::lround(absorbe * reglages.part / 100.0f));
        effet->SetAmount(std::min(effet->GetAmount() + apport, Plafond(cible) + int32(absorbe)));
    }

    void Register() override
    {
        AfterEffectAbsorb += AuraEffectAbsorbFn(spell_solazeroth_v3_rempart::Absorbe, EFFECT_0);
    }
};

class spell_solazeroth_v3_frappe_bouclier : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_frappe_bouclier);

    void Remplir()
    {
        if (Unit* lanceur = GetCaster())
            Ajouter(lanceur, int32(std::lround(lanceur->GetMaxHealth() * reglages.frappe / 100.0f)));
    }

    void Register() override
    {
        AfterHit += SpellHitFn(spell_solazeroth_v3_frappe_bouclier::Remplir);
    }
};

// Riposte du rempart et Second souffle : consomment tout le Rempart au lancement.
class ConsommeLeRempart : public SpellScript
{
protected:
    int32 consomme = 0;

    SpellCastResult Verifier()
    {
        return GetCaster() && Montant(GetCaster()) > 0 ? SPELL_CAST_OK : SPELL_FAILED_CASTER_AURASTATE;
    }

    void Consommer()
    {
        if (Unit* lanceur = GetCaster())
            consomme = Vider(lanceur);
    }
};

class spell_solazeroth_v3_riposte : public ConsommeLeRempart
{
    PrepareSpellScript(spell_solazeroth_v3_riposte);

    void Frapper()
    {
        SetHitDamage(int32(consomme * 1.5f));
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_riposte::Verifier);
        BeforeCast += SpellCastFn(spell_solazeroth_v3_riposte::Consommer);
        OnHit += SpellHitFn(spell_solazeroth_v3_riposte::Frapper);
    }
};

class spell_solazeroth_v3_second_souffle : public ConsommeLeRempart
{
    PrepareSpellScript(spell_solazeroth_v3_second_souffle);

    void Soigner()
    {
        SetHitHeal(consomme);
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_second_souffle::Verifier);
        BeforeCast += SpellCastFn(spell_solazeroth_v3_second_souffle::Consommer);
        OnHit += SpellHitFn(spell_solazeroth_v3_second_souffle::Soigner);
    }
};

class spell_solazeroth_v3_ravage : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_ravage);

    size_t touches = 0;

    void Compter(std::list<WorldObject*>& cibles)
    {
        touches = cibles.size();
    }

    void Frapper()
    {
        SetHitDamage(int32(GetHitDamage() * (1.0f + 0.1f * std::min<size_t>(touches, 5))));
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_solazeroth_v3_ravage::Compter, EFFECT_0, TARGET_UNIT_SRC_AREA_ENEMY);
        OnHit += SpellHitFn(spell_solazeroth_v3_ravage::Frapper);
    }
};

class spell_solazeroth_v3_vengeance : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_vengeance);

    SpellCastResult Verifier()
    {
        Unit* lanceur = GetCaster();
        return lanceur && Montant(lanceur) > 0 && Montant(lanceur) >= Plafond(lanceur) - 1
            ? SPELL_CAST_OK : SPELL_FAILED_CASTER_AURASTATE;
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_vengeance::Verifier);
    }
};

class spell_solazeroth_v3_dernier_rempart : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_dernier_rempart);

    void Remplir()
    {
        if (Unit* lanceur = GetCaster())
            Fixer(lanceur, Plafond(lanceur));
    }

    void Register() override
    {
        AfterHit += SpellHitFn(spell_solazeroth_v3_dernier_rempart::Remplir);
    }
};

// ---------------------------------------------------------------- Joueur

class solazeroth_v3_kit_unites : public UnitScript
{
public:
    solazeroth_v3_kit_unites() : UnitScript("solazeroth_v3_kit_unites", true, { UNITHOOK_ON_DAMAGE }) { }

    // Dégâts réellement subis (après l'armure et le Rempart) : la part absorbée passe par l'AuraScript.
    void OnDamage(Unit* attaquant, Unit* victime, uint32& degats) override
    {
        if (degats && attaquant && attaquant != victime && victime->IsAlive() && PorteLeRempart(victime))
            Ajouter(victime, int32(std::lround(degats * reglages.part / 100.0f)));
    }
};

class solazeroth_v3_kit_joueur : public PlayerScript
{
public:
    solazeroth_v3_kit_joueur() : PlayerScript("solazeroth_v3_kit_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_FIRST_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_DELETE }) { }

    // F5d (31/10/2026) : le personnage commence sans arme ; la première vient des quêtes de Durotar.
    void OnPlayerFirstLogin(Player* player) override
    {
        for (uint8 emplacement : { EQUIPMENT_SLOT_MAINHAND, EQUIPMENT_SLOT_OFFHAND, EQUIPMENT_SLOT_RANGED })
            if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, emplacement))
                player->DestroyItem(INVENTORY_SLOT_BAG_0, emplacement, true);
    }

    void OnPlayerLogin(Player* player) override
    {
        Kit* kit = KitDe(player);
        if (QueryResult r = CharacterDatabase.Query("SELECT spe, equipees FROM solazeroth_v3_kit WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            kit->spe = (*r)[0].Get<uint8>();
            std::istringstream flux((*r)[1].Get<std::string>());
            for (uint32 sort; flux >> sort;)
                kit->equipees.push_back(sort);
        }
        // Le kit s'applique au premier passage de OnPlayerUpdate, une fois la puissance calculée (v3_combat.cpp).
        if (player->getClass() == CLASS_WARRIOR && kit->spe == SPE_AUCUNE)
            ChatHandler(player->GetSession()).SendSysMessage("|cff40c0ffChoisis ta spécialisation : /sol, page Techniques.|r");
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Kit* kit = KitDe(player);
        kit->attente += diff;
        kit->attenteRempart += diff;

        if (kit->attenteRempart >= TICK_REMPART && kit->spe == SPE_GUERRIER_TANK)
        {
            kit->attenteRempart = 0;
            std::string message = Acore::StringFormat("REMPART;{};{}", Montant(player), Plafond(player));
            if (message != kit->rempartEnvoye)
            {
                kit->rempartEnvoye = message;
                SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
            }
        }

        if (kit->attente < TICK_KIT)
            return;
        kit->attente = 0;
        // Le Rempart est renvoyé au moins toutes les 2 s : l'interface v3 (F4) le retrouve après un /reload.
        kit->rempartEnvoye.clear();
        if (player->getClass() != CLASS_WARRIOR)
            return;
        if (!kit->debloquees || (kit->spe != SPE_AUCUNE && Debloquees(player) != kit->debloquees))
            Appliquer(player);
        if (kit->spe == SPE_GUERRIER_TANK && !player->IsInCombat() && player->IsAlive())
            Fixer(player, Montant(player) - std::max(1, int32(player->GetMaxHealth() * reglages.fuite / 100.0f)));
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_kit WHERE guid = {}", guid.GetCounter());
    }
};

class solazeroth_v3_kit_monde : public WorldScript
{
public:
    solazeroth_v3_kit_monde() : WorldScript("solazeroth_v3_kit_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        reglages.part = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.Part", 40.0f);
        reglages.plafond = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.Plafond", 30.0f);
        reglages.fuite = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.Fuite", 1.0f);
        reglages.frappe = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.FrappeBouclier", 8.0f);
    }
};

class solazeroth_v3_kit_commandes : public CommandScript
{
public:
    solazeroth_v3_kit_commandes() : CommandScript("solazeroth_v3_kit_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable kit =
        {
            { "",        HandleEtat,    SEC_PLAYER, Console::No },
            { "spe",     HandleSpe,     SEC_PLAYER, Console::No },
            { "equiper", HandleEquiper, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "kit", kit },
        };
        return commandes;
    }

    static bool HandleEtat(ChatHandler* handler)
    {
        Envoyer(handler->GetPlayer());
        return true;
    }

    // .kit spe tank : choix de la spécialisation, une fois pour toutes (le changement viendra plus tard).
    static bool HandleSpe(ChatHandler* handler, std::string nom)
    {
        Player* player = handler->GetPlayer();
        Kit* kit = KitDe(player);
        if (player->getClass() != CLASS_WARRIOR || nom != "tank")
        {
            handler->SendErrorMessage("Seule la spécialisation tank du guerrier existe pour l'instant.");
            return false;
        }
        if (kit->spe != SPE_AUCUNE)
        {
            handler->SendErrorMessage("Ta spécialisation est déjà choisie.");
            return false;
        }
        kit->spe = SPE_GUERRIER_TANK;
        kit->equipees.clear();
        kit->debloquees = 0;
        Sauver(player);
        // La première barre (boutons 1 à 12) ne garde que les techniques : Attaque et sorts de départ en sont retirés.
        for (uint8 bouton = 0; bouton < 12; ++bouton)
            player->removeActionButton(bouton);
        Appliquer(player);
        handler->SendSysMessage("|cff40c0ffSpécialisation choisie : guerrier tank. Le Rempart et tes premières techniques sont prêts.|r");
        return true;
    }

    // .kit equiper <sort> … : jusqu'à 8 techniques débloquées, hors combat. Les places libres se remplissent dans l'ordre.
    static bool HandleEquiper(ChatHandler* handler, Tail liste)
    {
        Player* player = handler->GetPlayer();
        Kit* kit = KitDe(player);
        if (kit->spe == SPE_AUCUNE)
        {
            handler->SendErrorMessage("Choisis d'abord ta spécialisation.");
            return false;
        }
        if (player->IsInCombat())
        {
            handler->SendErrorMessage("Les techniques se changent hors combat.");
            return false;
        }
        size_t debloquees = Debloquees(player);
        std::vector<uint32> equipees;
        std::istringstream flux{ std::string(liste) };
        for (uint32 sort; flux >> sort;)
        {
            if (!EstTechnique(sort) || !EstDebloquee(sort, debloquees))
            {
                handler->SendErrorMessage("Technique inconnue ou pas encore débloquée.");
                return false;
            }
            if (std::find(equipees.begin(), equipees.end(), sort) == equipees.end())
                equipees.push_back(sort);
        }
        if (equipees.size() > EQUIPEES_MAX)
        {
            handler->SendErrorMessage("8 techniques au plus.");
            return false;
        }
        kit->equipees = equipees;
        Sauver(player);
        Appliquer(player);
        std::string noms;
        for (uint32 sort : kit->equipees)
            noms += (noms.empty() ? "" : ", ") + std::string(NomDe(sort));
        handler->PSendSysMessage("Techniques équipées : {}.", noms);
        return true;
    }
};

void AddSC_solazeroth_v3_kit()
{
    new solazeroth_v3_kit_unites();
    new solazeroth_v3_kit_joueur();
    new solazeroth_v3_kit_monde();
    new solazeroth_v3_kit_commandes();
    RegisterSpellScript(spell_solazeroth_v3_rempart);
    RegisterSpellScript(spell_solazeroth_v3_frappe_bouclier);
    RegisterSpellScript(spell_solazeroth_v3_riposte);
    RegisterSpellScript(spell_solazeroth_v3_second_souffle);
    RegisterSpellScript(spell_solazeroth_v3_ravage);
    RegisterSpellScript(spell_solazeroth_v3_vengeance);
    RegisterSpellScript(spell_solazeroth_v3_dernier_rempart);
}
