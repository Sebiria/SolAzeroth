// Cinq spécialisations (section 3.8, V2)
// Le jeu n'en gère que deux. Ici, chaque personnage a jusqu'à 5 emplacements (le 1er offert, les autres achetés).
// L'emplacement actif vit dans les tables normales du jeu (talents, glyphes, barres d'action de la spé active).
// Changer d'emplacement : on recopie l'actif dans nos tables, on réinitialise les talents gratuitement, puis on
// réapprend les talents, glyphes et barres d'action de l'emplacement choisi. Hors combat seulement.
// Addon SolAzerothSpes : messages « SPE;actif;possédés;prix_suivant_po;nom|a/b/c;… » (préfixe SOLSPE).

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <algorithm>
#include <array>
#include <sstream>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLSPE";
    uint8 const EMPLACEMENTS = 5;

    // Prix des emplacements 2 à 5, en pièces d'or.
    std::array<uint32, EMPLACEMENTS - 1> prix = { 50, 250, 1000, 2500 };

    struct Etat
    {
        uint8 actif = 1;
        uint8 possedes = 1;
    };

    Etat LireEtat(Player* player)
    {
        Etat etat;
        if (QueryResult r = CharacterDatabase.Query("SELECT actif, possedes FROM solazeroth_spes WHERE guid = {}", player->GetGUID().GetCounter()))
        {
            etat.actif = std::clamp<uint8>((*r)[0].Get<uint8>(), 1, EMPLACEMENTS);
            etat.possedes = std::clamp<uint8>((*r)[1].Get<uint8>(), 1, EMPLACEMENTS);
        }
        return etat;
    }

    void EcrireEtat(Player* player, Etat const& etat)
    {
        CharacterDatabase.DirectExecute("REPLACE INTO solazeroth_spes (guid, actif, possedes) VALUES ({}, {}, {})",
            player->GetGUID().GetCounter(), etat.actif, etat.possedes);
    }

    // Talents de la spé active : (talent, rang), le plus haut rang de chacun.
    std::vector<std::pair<uint32, uint8>> TalentsActifs(Player* player)
    {
        std::vector<std::pair<uint32, uint8>> talents;
        for (auto const& [sort, info] : player->GetTalentMap())
        {
            if (info->State == PLAYERSPELL_REMOVED || !info->IsInSpec(player->GetActiveSpec()))
                continue;
            TalentSpellPos const* pos = GetTalentSpellPos(sort);
            if (!pos)
                continue;
            auto it = std::find_if(talents.begin(), talents.end(), [&](auto const& t) { return t.first == pos->talent_id; });
            if (it == talents.end())
                talents.emplace_back(pos->talent_id, pos->rank);
            else
                it->second = std::max(it->second, pos->rank);
        }
        return talents;
    }

    // Points dépensés dans chacun des 3 arbres de sa classe, ex. « 5/0/51 » (l'arbre d'une autre classe n'y figure pas).
    std::string Repartition(std::vector<std::pair<uint32, uint8>> const& talents, uint32 masqueClasse)
    {
        std::array<uint32, 3> points = { 0, 0, 0 };
        for (auto const& [talent, rang] : talents)
            if (TalentEntry const* t = sTalentStore.LookupEntry(talent))
                if (TalentTabEntry const* onglet = sTalentTabStore.LookupEntry(t->TalentTab))
                    if (onglet->tabpage < 3 && (onglet->ClassMask & masqueClasse))
                        points[onglet->tabpage] += rang + 1;
        return Acore::StringFormat("{}/{}/{}", points[0], points[1], points[2]);
    }

    std::vector<std::pair<uint32, uint8>> TalentsEnregistres(uint32 guid, uint8 slot)
    {
        std::vector<std::pair<uint32, uint8>> talents;
        if (QueryResult r = CharacterDatabase.Query("SELECT talent, rang FROM solazeroth_spes_talents WHERE guid = {} AND slot = {}", guid, slot))
        {
            do
                talents.emplace_back((*r)[0].Get<uint32>(), (*r)[1].Get<uint8>());
            while (r->NextRow());
        }
        return talents;
    }

    void EnvoyerEtat(Player* player)
    {
        uint32 guid = player->GetGUID().GetCounter();
        Etat etat = LireEtat(player);

        std::array<std::string, EMPLACEMENTS> noms;
        for (uint8 i = 0; i < EMPLACEMENTS; ++i)
            noms[i] = Acore::StringFormat("Spécialisation {}", i + 1);
        if (QueryResult r = CharacterDatabase.Query("SELECT slot, nom FROM solazeroth_spes_noms WHERE guid = {}", guid))
        {
            do
            {
                uint8 slot = (*r)[0].Get<uint8>();
                if (slot >= 1 && slot <= EMPLACEMENTS)
                    noms[slot - 1] = (*r)[1].Get<std::string>();
            } while (r->NextRow());
        }

        uint32 suivant = etat.possedes < EMPLACEMENTS ? prix[etat.possedes - 1] : 0;
        std::string message = Acore::StringFormat("SPE;{};{};{}", etat.actif, etat.possedes, suivant);
        for (uint8 slot = 1; slot <= EMPLACEMENTS; ++slot)
        {
            std::string repartition = slot == etat.actif ? Repartition(TalentsActifs(player), player->getClassMask())
                                                         : Repartition(TalentsEnregistres(guid, slot), player->getClassMask());
            message += ";" + noms[slot - 1] + "|" + repartition;
        }
        SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
    }

    // Recopie la spé active (talents, glyphes, barres d'action) dans l'emplacement « slot ».
    void Sauver(Player* player, uint8 slot)
    {
        uint32 guid = player->GetGUID().GetCounter();
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        trans->Append("DELETE FROM solazeroth_spes_talents WHERE guid = {} AND slot = {}", guid, slot);
        trans->Append("DELETE FROM solazeroth_spes_glyphes WHERE guid = {} AND slot = {}", guid, slot);
        trans->Append("DELETE FROM solazeroth_spes_actions WHERE guid = {} AND slot = {}", guid, slot);

        for (auto const& [talent, rang] : TalentsActifs(player))
            trans->Append("INSERT INTO solazeroth_spes_talents (guid, slot, talent, rang) VALUES ({}, {}, {}, {})", guid, slot, talent, rang);

        for (uint8 i = 0; i < MAX_GLYPH_SLOT_INDEX; ++i)
            if (uint32 glyphe = player->GetGlyph(i))
                trans->Append("INSERT INTO solazeroth_spes_glyphes (guid, slot, emplacement, glyphe) VALUES ({}, {}, {}, {})", guid, slot, i, glyphe);

        for (uint8 bouton = 0; bouton < MAX_ACTION_BUTTONS; ++bouton)
            if (ActionButton const* b = player->GetActionButton(bouton))
                trans->Append("INSERT INTO solazeroth_spes_actions (guid, slot, bouton, action, type) VALUES ({}, {}, {}, {}, {})",
                    guid, slot, bouton, b->GetAction(), uint32(b->GetType()));

        CharacterDatabase.DirectCommitTransaction(trans);
    }

    // Remplace la spé active par l'emplacement « slot ». Un emplacement jamais utilisé donne des talents vierges,
    // aucun glyphe, et garde les barres d'action actuelles.
    void Charger(Player* player, uint8 slot)
    {
        uint32 guid = player->GetGUID().GetCounter();

        if (player->IsNonMeleeSpellCast(false))
            player->InterruptNonMeleeSpells(false);

        player->resetTalents(true);

        // Talents dans l'ordre des rangées, pour respecter les points requis par palier et les prérequis.
        std::vector<std::pair<uint32, uint8>> talents = TalentsEnregistres(guid, slot);
        std::sort(talents.begin(), talents.end(), [](auto const& a, auto const& b)
        {
            TalentEntry const* ta = sTalentStore.LookupEntry(a.first);
            TalentEntry const* tb = sTalentStore.LookupEntry(b.first);
            return (ta ? ta->Row : 0) < (tb ? tb->Row : 0);
        });
        // Fonction du module : elle accepte aussi l'arbre d'une autre classe (section 3.10).
        for (auto const& [talent, rang] : talents)
            SolAzeroth::ApprendreTalent(player, talent, rang);
        player->SendTalentsInfoData(false);

        // Glyphes : on retire les anciens et on pose ceux de l'emplacement.
        std::array<uint32, MAX_GLYPH_SLOT_INDEX> glyphes = {};
        if (QueryResult r = CharacterDatabase.Query("SELECT emplacement, glyphe FROM solazeroth_spes_glyphes WHERE guid = {} AND slot = {}", guid, slot))
        {
            do
            {
                uint8 i = (*r)[0].Get<uint8>();
                if (i < MAX_GLYPH_SLOT_INDEX)
                    glyphes[i] = (*r)[1].Get<uint32>();
            } while (r->NextRow());
        }
        for (uint8 i = 0; i < MAX_GLYPH_SLOT_INDEX; ++i)
        {
            if (uint32 ancien = player->GetGlyph(i))
                if (GlyphPropertiesEntry const* g = sGlyphPropertiesStore.LookupEntry(ancien))
                    player->RemoveAurasDueToSpell(g->SpellId);
            player->SetGlyph(i, glyphes[i], true);
            if (glyphes[i])
                if (GlyphPropertiesEntry const* g = sGlyphPropertiesStore.LookupEntry(glyphes[i]))
                    player->CastSpell(player, g->SpellId, true);
        }

        // Barres d'action, seulement si l'emplacement en a déjà enregistré.
        if (QueryResult r = CharacterDatabase.Query("SELECT bouton, action, type FROM solazeroth_spes_actions WHERE guid = {} AND slot = {}", guid, slot))
        {
            for (uint8 bouton = 0; bouton < MAX_ACTION_BUTTONS; ++bouton)
                player->removeActionButton(bouton);
            do
                player->addActionButton((*r)[0].Get<uint8>(), (*r)[1].Get<uint32>(), (*r)[2].Get<uint8>());
            while (r->NextRow());
            player->SendActionButtons(1);
        }
    }

    std::string Nettoyer(std::string nom)
    {
        nom.erase(std::remove_if(nom.begin(), nom.end(), [](char c) { return c == ';' || c == '|'; }), nom.end());
        if (nom.size() > 24)
            nom.resize(24);
        return nom;
    }
}

class solazeroth_specialisations_commandes : public CommandScript
{
public:
    solazeroth_specialisations_commandes() : CommandScript("solazeroth_specialisations_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "etat",    HandleEtat,    SEC_PLAYER, Console::No },
            { "activer", HandleActiver, SEC_PLAYER, Console::No },
            { "acheter", HandleAcheter, SEC_PLAYER, Console::No },
            { "nom",     HandleNom,     SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solspe", sousCommandes },
        };
        return commandes;
    }

    static bool HandleEtat(ChatHandler* handler)
    {
        EnvoyerEtat(handler->GetPlayer());
        return true;
    }

    static bool HandleActiver(ChatHandler* handler, uint8 slot)
    {
        Player* player = handler->GetPlayer();
        Etat etat = LireEtat(player);
        if (slot < 1 || slot > etat.possedes || slot == etat.actif)
            return true;
        if (player->IsInCombat() || !player->IsAlive())
        {
            handler->SendSysMessage("Impossible de changer de spécialisation en combat ou mort.");
            return true;
        }

        Sauver(player, etat.actif);
        Charger(player, slot);
        etat.actif = slot;
        EcrireEtat(player, etat);
        player->SaveToDB(false, false);

        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Spécialisation {} activée.|r", slot));
        EnvoyerEtat(player);
        return true;
    }

    static bool HandleAcheter(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Etat etat = LireEtat(player);
        if (etat.possedes >= EMPLACEMENTS)
            return true;

        uint32 cout = prix[etat.possedes - 1] * GOLD;
        if (!player->HasEnoughMoney(cout))
        {
            handler->SendSysMessage(Acore::StringFormat("Il faut {} po pour la spécialisation {}.", prix[etat.possedes - 1], etat.possedes + 1));
            return true;
        }
        player->ModifyMoney(-int32(cout));
        ++etat.possedes;
        EcrireEtat(player, etat);

        handler->SendSysMessage(Acore::StringFormat("|cff00ff00Emplacement de spécialisation {} acheté.|r", etat.possedes));
        EnvoyerEtat(player);
        return true;
    }

    static bool HandleNom(ChatHandler* handler, uint8 slot, Tail nom)
    {
        Player* player = handler->GetPlayer();
        std::string propre = Nettoyer(std::string(nom));
        if (slot < 1 || slot > EMPLACEMENTS || propre.empty())
            return true;
        CharacterDatabase.DirectExecute("REPLACE INTO solazeroth_spes_noms (guid, slot, nom) VALUES ({}, {}, '{}')",
            player->GetGUID().GetCounter(), slot, [&] { std::string s = propre; CharacterDatabase.EscapeString(s); return s; }());
        EnvoyerEtat(player);
        return true;
    }
};

class solazeroth_specialisations_monde : public WorldScript
{
public:
    solazeroth_specialisations_monde() : WorldScript("solazeroth_specialisations_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        std::istringstream flux(sConfigMgr->GetOption<std::string>("SolAzeroth.Specialisations.Prix", "50 250 1000 2500"));
        for (uint32& p : prix)
            flux >> p;
    }
};

void AddSC_solazeroth_specialisations()
{
    new solazeroth_specialisations_commandes();
    new solazeroth_specialisations_monde();
}
