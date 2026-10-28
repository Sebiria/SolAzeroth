// Ressources pour toutes les classes (section 3.9, V3b).
// Étape 1 : le serveur donne déjà à chaque personnage une jauge de rage, d'énergie et de puissance runique, et
// l'énergie se régénère pour tous. Mais la rage ne se gagne (coups donnés et reçus) que si elle est « active » pour
// le personnage. Ici, une ressource devient active dès que le personnage connaît un sort qui la consomme : un paladin
// qui apprend Frappe héroïque gagne de la rage en combat. Crochet prévu par le core : OnPlayerHasActivePowerType.
// Étape 2 (runes) : tout personnage compte comme chevalier de la mort pour le contexte « capacités »
// (OnPlayerIsClass, CLASS_CONTEXT_ABILITY) : il a donc les 6 runes, leur recharge, leur coût et la puissance
// runique qu'elles donnent. Les runes sont créées au chargement du personnage, avant ses sorts : on ne peut pas les
// réserver aux acheteurs de sorts à runes. Les autres règles du chevalier de la mort (niveau de départ, Achérus,
// reliques, armures, familiers) utilisent d'autres contextes et ne changent pas.
// Le client n'affiche les runes qu'au chevalier de la mort : pour les autres classes qui connaissent un sort à runes,
// le serveur envoie leur état à l'addon SolAzerothRessources à chaque changement :
// « RUNES;type:recharge_ms,… » (6 runes ; type 0 sang, 1 impie, 2 givre, 3 mort ; préfixe SOLRES).

#include "SolAzeroth.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringFormat.h"

namespace
{
    char const* const PREFIXE = "SOLRES";
    char const* const CLE = "solazeroth_ressources";

    uint32 const SURVEILLEES = (1 << POWER_RAGE) | (1 << POWER_ENERGY) | (1 << POWER_RUNIC_POWER);

    struct Actives : DataMap::Base
    {
        uint32 masque = 0;        // bit (1 << Powers) ; POWER_RUNE si un sort coûte des runes
        uint32 attente = 0;       // minuterie de l'envoi des runes
        std::string dernier;      // dernier état des runes envoyé
    };

    void Calculer(Player* player)
    {
        uint32 masque = 0;
        for (auto const& [sort, info] : player->GetSpellMap())
        {
            if (info->State == PLAYERSPELL_REMOVED || !info->Active)
                continue;
            SpellInfo const* sortInfo = sSpellMgr->GetSpellInfo(sort);
            if (!sortInfo)
                continue;
            if (sortInfo->PowerType == POWER_RUNE && sortInfo->RuneCostID)
                masque |= (1 << POWER_RUNE) | (1 << POWER_RUNIC_POWER);
            else if (sortInfo->PowerType < MAX_POWERS && sortInfo->ManaCost + sortInfo->ManaCostPercentage > 0)
                masque |= (1 << sortInfo->PowerType) & SURVEILLEES;
        }
        Actives* actives = player->CustomData.GetDefault<Actives>(CLE);
        actives->masque = masque;
        actives->dernier.clear();
    }

    std::string EtatRunes(Player* player)
    {
        std::string texte;
        for (uint8 i = 0; i < MAX_RUNES; ++i)
            texte += (i ? "," : "") + Acore::StringFormat("{}:{}", uint32(player->GetCurrentRune(i)), player->GetRuneCooldown(i));
        return texte;
    }
}

class solazeroth_ressources : public PlayerScript
{
public:
    solazeroth_ressources() : PlayerScript("solazeroth_ressources", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEARN_SPELL, PLAYERHOOK_ON_PLAYER_HAS_ACTIVE_POWER_TYPE,
        PLAYERHOOK_ON_PLAYER_IS_CLASS, PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Calculer(player);
    }

    void OnPlayerLearnSpell(Player* player, uint32 /*sort*/) override
    {
        Calculer(player);
    }

    bool OnPlayerHasActivePowerType(Player const* player, Powers power) override
    {
        Actives const* actives = player->CustomData.Get<Actives>(CLE);
        return actives && power < MAX_POWERS && (actives->masque & (1 << power));
    }

    Optional<bool> OnPlayerIsClass(Player const* /*player*/, Classes classe, ClassContext contexte) override
    {
        if (classe == CLASS_DEATH_KNIGHT && contexte == CLASS_CONTEXT_ABILITY)
            return true;
        return std::nullopt;
    }

    // Toutes les 200 ms, l'état des runes est envoyé à l'addon s'il a changé (hors chevalier de la mort).
    // Les temps de recharge baissent en continu : on n'envoie que les changements de rune prête ou de type,
    // l'addon fait le décompte lui-même.
    void OnPlayerUpdate(Player* player, uint32 temps) override
    {
        if (player->getClass() == CLASS_DEATH_KNIGHT)
            return;
        Actives* actives = player->CustomData.Get<Actives>(CLE);
        if (!actives || !(actives->masque & (1 << POWER_RUNE)))
            return;
        actives->attente += temps;
        if (actives->attente < 200)
            return;
        actives->attente = 0;

        std::string cle = Acore::StringFormat("{}", uint32(player->GetRunesState()));
        for (uint8 i = 0; i < MAX_RUNES; ++i)
            cle += Acore::StringFormat(":{}", uint32(player->GetCurrentRune(i)));
        if (cle == actives->dernier)
            return;
        actives->dernier = cle;
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "RUNES;" + EtatRunes(player));
    }
};

void AddSC_solazeroth_ressources()
{
    new solazeroth_ressources();
}
