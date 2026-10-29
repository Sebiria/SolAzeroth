// Équilibrage solo par spécialisation (section 3.5 du document de conception)
// La spécialisation est l'arbre de talents de sa propre classe qui a le plus de points : les talents pris dans l'arbre
// d'une autre classe (talents_etrangers.cpp) ne comptent pas (calibrage final, 29/10/2026 ; avant, ils comptaient pour
// l'arbre de même position et donnaient par exemple le bonus des soigneurs à un chaman 51 points en Vindicte).
// Réglage par arbre dans mod_solazeroth.conf : SolAzeroth.Solo.<Classe>.<Arbre> = "dégâts soins réduction"
// (trois pourcentages : dégâts infligés en plus, soins reçus en plus, dégâts subis en moins).

#include "SolAzeroth.h"
#include "Config.h"
#include "DBCStores.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <array>
#include <sstream>

namespace
{
    struct Bonus
    {
        float degats = 0.0f;
        float soins = 0.0f;
        float reduction = 0.0f;
    };

    // Index : classe (1 à 11), puis arbre (0 à 2, dans l'ordre de l'interface des talents).
    std::array<std::array<Bonus, 3>, 12> bonus;

    struct Arbres
    {
        uint8 classe;
        char const* nom;
        char const* arbres[3];
    };

    Arbres const CLASSES[] =
    {
        { CLASS_WARRIOR,      "Guerrier",      { "Armes", "Fureur", "Protection" } },
        { CLASS_PALADIN,      "Paladin",       { "Sacre", "Protection", "Vindicte" } },
        { CLASS_HUNTER,       "Chasseur",      { "Betes", "Precision", "Survie" } },
        { CLASS_ROGUE,        "Voleur",        { "Assassinat", "Combat", "Finesse" } },
        { CLASS_PRIEST,       "Pretre",        { "Discipline", "Sacre", "Ombre" } },
        { CLASS_DEATH_KNIGHT, "ChevalierMort", { "Sang", "Givre", "Impie" } },
        { CLASS_SHAMAN,       "Chaman",        { "Elementaire", "Amelioration", "Restauration" } },
        { CLASS_MAGE,         "Mage",          { "Arcanes", "Feu", "Givre" } },
        { CLASS_WARLOCK,      "Demoniste",     { "Affliction", "Demonologie", "Destruction" } },
        { CLASS_DRUID,        "Druide",        { "Equilibre", "Farouche", "Restauration" } },
    };

    // Arbre de sa classe qui a le plus de points (comme Player::GetMostPointsTalentTree, sans les arbres étrangers) ;
    // 3 si aucun point n'est dépensé dans ses propres arbres.
    uint8 ArbrePrincipal(Player const* player)
    {
        std::array<uint32, 3> points = { 0, 0, 0 };
        for (auto const& [sort, talent] : player->GetTalentMap())
            if (talent->State != PLAYERSPELL_REMOVED && talent->IsInSpec(player->GetActiveSpec()))
                if (TalentEntry const* t = sTalentStore.LookupEntry(talent->talentID))
                    if (TalentTabEntry const* onglet = sTalentTabStore.LookupEntry(t->TalentTab))
                        if (onglet->tabpage < 3 && (onglet->ClassMask & player->getClassMask()))
                            for (uint8 rang = 0; rang < MAX_TALENT_RANK; ++rang)
                                if (t->RankID[rang] == sort)
                                {
                                    points[onglet->tabpage] += rang + 1;
                                    break;
                                }
        uint8 arbre = 0;
        for (uint8 i = 1; i < 3; ++i)
            if (points[i] > points[arbre])
                arbre = i;
        return points[arbre] ? arbre : 3;
    }

    Bonus const* BonusDe(Unit const* unite)
    {
        Player const* player = unite ? unite->ToPlayer() : nullptr;
        if (!player || player->getClass() >= bonus.size())
            return nullptr;
        uint8 arbre = ArbrePrincipal(player);
        if (arbre > 2)
            return nullptr;
        return &bonus[player->getClass()][arbre];
    }
}

class solazeroth_bonus_solo : public UnitScript
{
public:
    solazeroth_bonus_solo() : UnitScript("solazeroth_bonus_solo", true, {
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK,
        UNITHOOK_MODIFY_HEAL_RECEIVED }) { }

    template <typename T>
    static void Appliquer(Unit* cible, Unit* attaquant, T& degats)
    {
        if (cible == attaquant)
            return;
        if (Bonus const* b = BonusDe(attaquant); b && b->degats)
            degats = T(degats * (1.0f + b->degats / 100.0f));
        if (Bonus const* b = BonusDe(cible); b && b->reduction)
            degats = T(degats * (1.0f - b->reduction / 100.0f));
    }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override { Appliquer(cible, attaquant, degats); }
    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* /*sort*/) override { Appliquer(cible, attaquant, degats); }
    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* /*sort*/) override { Appliquer(cible, attaquant, degats); }

    void ModifyHealReceived(Unit* cible, Unit* /*soigneur*/, uint32& soins, SpellInfo const* /*sort*/) override
    {
        if (Bonus const* b = BonusDe(cible); b && b->soins)
            soins = uint32(soins * (1.0f + b->soins / 100.0f));
    }
};

class solazeroth_bonus_solo_config : public WorldScript
{
public:
    solazeroth_bonus_solo_config() : WorldScript("solazeroth_bonus_solo_config", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        for (Arbres const& c : CLASSES)
        {
            for (uint8 arbre = 0; arbre < 3; ++arbre)
            {
                std::string cle = std::string("SolAzeroth.Solo.") + c.nom + "." + c.arbres[arbre];
                std::istringstream valeurs(sConfigMgr->GetOption<std::string>(cle, "0 0 0", false));
                Bonus& b = bonus[c.classe][arbre];
                b = Bonus();
                valeurs >> b.degats >> b.soins >> b.reduction;
            }
        }
    }
};

void AddSC_solazeroth_bonus_solo()
{
    new solazeroth_bonus_solo();
    new solazeroth_bonus_solo_config();
}
