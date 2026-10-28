// Talents d'une autre classe (section 3.10, V3c).
// Le personnage peut placer des points dans UN arbre de talents d'une autre classe, sans limite de points dans cet
// arbre (décision de l'utilisateur). Changer d'arbre étranger = réinitialiser ses talents.
// La fonction d'apprentissage du jeu (Player::LearnTalent) refuse un talent d'une autre classe : ApprendreTalent
// en reprend les règles (points libres, 5 points par rangée dans l'arbre, prérequis, rangs) sans cette vérification.
// Le chargement des talents à la connexion ne vérifie pas la classe : les talents étrangers sont conservés.
// Addon SolAzerothTalents (préfixe SOLTAL) :
//   « .soltalent arbre <onglet> » -> « T;talent;rangée;colonne;sort1,sort2,…;prérequis;rang_prérequis;rang_actuel » pour
//   chaque talent, puis « ETAT;onglet;onglet_étranger;points_libres;points_dans_l_arbre ».
//   « .soltalent apprendre <talent> » place un point (rang suivant), puis renvoie l'arbre.
//   « .soltalent onglets <classe> » -> « O;classe;onglet_page0;onglet_page1;onglet_page2;onglet_étranger ».
//   « .soltalent prix » -> « PRIX;prix_po;prix_suivant_po;réinitialisations_comptées ».
//   « .soltalent reinitialiser » réinitialise les talents contre de l'or (prix croissant), puis « REINIT » et « PRIX ».

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringFormat.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLTAL";

    std::map<uint32, std::vector<TalentEntry const*>> talentsParOnglet;

    bool OngletDeLaClasse(Player const* player, uint32 onglet)
    {
        TalentTabEntry const* t = sTalentTabStore.LookupEntry(onglet);
        return t && (t->ClassMask & player->getClassMask());
    }

    // Rang actuel d'un talent (0 = aucun point) dans la spécialisation active.
    uint8 RangActuel(Player const* player, TalentEntry const* talent)
    {
        for (uint8 rang = MAX_TALENT_RANK; rang > 0; --rang)
            if (talent->RankID[rang - 1] && player->HasTalent(talent->RankID[rang - 1], player->GetActiveSpec()))
                return rang;
        return 0;
    }

    uint32 PointsDansOnglet(Player const* player, uint32 onglet)
    {
        uint32 points = 0;
        for (auto const& [sort, info] : player->GetTalentMap())
        {
            if (info->State == PLAYERSPELL_REMOVED || !info->IsInSpec(player->GetActiveSpec()))
                continue;
            if (TalentSpellPos const* pos = GetTalentSpellPos(sort))
                if (TalentEntry const* t = sTalentStore.LookupEntry(pos->talent_id))
                    if (t->TalentTab == onglet)
                        points += pos->rank + 1;
        }
        return points;
    }

    // Arbre étranger déjà utilisé par la spécialisation active (0 si aucun).
    uint32 OngletEtranger(Player const* player)
    {
        for (auto const& [sort, info] : player->GetTalentMap())
        {
            if (info->State == PLAYERSPELL_REMOVED || !info->IsInSpec(player->GetActiveSpec()))
                continue;
            if (TalentSpellPos const* pos = GetTalentSpellPos(sort))
                if (TalentEntry const* t = sTalentStore.LookupEntry(pos->talent_id))
                    if (!OngletDeLaClasse(player, t->TalentTab))
                        return t->TalentTab;
        }
        return 0;
    }

    void EnvoyerArbre(Player* player, uint32 onglet)
    {
        auto it = talentsParOnglet.find(onglet);
        if (it == talentsParOnglet.end())
            return;
        for (TalentEntry const* t : it->second)
        {
            std::string sorts;
            for (uint8 r = 0; r < MAX_TALENT_RANK && t->RankID[r]; ++r)
                sorts += (r ? "," : "") + std::to_string(t->RankID[r]);
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("T;{};{};{};{};{};{};{}",
                t->TalentID, t->Row, t->Col, sorts, t->DependsOn, t->DependsOnRank, RangActuel(player, t)));
        }
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("ETAT;{};{};{};{}",
            onglet, OngletEtranger(player), player->GetFreeTalentPoints(), PointsDansOnglet(player, onglet)));
    }

    // Réinitialisation payante des talents (pas d'entraîneur) : prix = niveau × or par niveau × multiplicateur^n,
    // n = réinitialisations déjà faites par le personnage, moins une par période sans réinitialisation.
    struct
    {
        uint32 orParNiveau = 1;
        float multiplicateur = 2.0f;
        uint32 baisseJours = 7;
    } reinit;

    uint32 ReinitialisationsComptees(uint32 guid)
    {
        QueryResult r = CharacterDatabase.Query("SELECT nombre, derniere FROM solazeroth_reinit_talents WHERE guid = {}", guid);
        if (!r)
            return 0;
        uint32 nombre = (*r)[0].Get<uint32>();
        uint64 derniere = (*r)[1].Get<uint64>();
        uint64 maintenant = GameTime::GetGameTime().count();
        if (reinit.baisseJours && maintenant > derniere)
        {
            uint64 baisse = (maintenant - derniere) / (uint64(reinit.baisseJours) * DAY);
            nombre = baisse >= nombre ? 0 : nombre - uint32(baisse);
        }
        return nombre;
    }

    // En pièces de cuivre, arrondi à la pièce d'or.
    uint32 PrixReinitialisation(Player const* player, uint32 comptees)
    {
        double po = std::round(double(player->GetLevel()) * reinit.orParNiveau * std::pow(double(reinit.multiplicateur), double(comptees)));
        return uint32(std::min<double>(po * double(GOLD), double(MAX_MONEY_AMOUNT)));
    }

    void EnvoyerPrix(Player* player)
    {
        uint32 comptees = ReinitialisationsComptees(player->GetGUID().GetCounter());
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("PRIX;{};{};{}",
            PrixReinitialisation(player, comptees) / GOLD, PrixReinitialisation(player, comptees + 1) / GOLD, comptees));
    }
}

// Apprend un talent jusqu'au rang « rang » (0 = premier rang). Talent de sa classe : fonction du jeu.
// Talent d'une autre classe : mêmes règles, sans la vérification de classe, et un seul arbre étranger.
// Renvoie un message d'erreur, vide si le talent est appris.
std::string SolAzeroth::ApprendreTalent(Player* player, unsigned int talentId, unsigned char rang)
{
    TalentEntry const* talent = sTalentStore.LookupEntry(talentId);
    if (!talent || rang >= MAX_TALENT_RANK || !talent->RankID[rang])
        return "Talent inconnu.";
    TalentTabEntry const* onglet = sTalentTabStore.LookupEntry(talent->TalentTab);
    if (!onglet || !onglet->ClassMask)
        return "Talent inconnu.";

    if (OngletDeLaClasse(player, talent->TalentTab))
    {
        player->LearnTalent(talentId, rang);
        return "";
    }

    uint32 etranger = OngletEtranger(player);
    if (etranger && etranger != talent->TalentTab)
        return "Tu as déjà des points dans un autre arbre d'une autre classe. Réinitialise tes talents pour en changer.";

    uint8 actuel = RangActuel(player, talent);
    if (actuel >= rang + 1)
        return "";
    uint32 cout = rang + 1 - actuel;
    uint32 libres = player->GetFreeTalentPoints();
    if (libres < cout)
        return "Plus assez de points de talent.";

    if (talent->DependsOn > 0)
        if (TalentEntry const* requis = sTalentStore.LookupEntry(talent->DependsOn))
            if (RangActuel(player, requis) < talent->DependsOnRank + 1)
                return "Il faut d'abord le talent prérequis.";

    if (PointsDansOnglet(player, talent->TalentTab) < talent->Row * MAX_TALENT_RANK)
        return Acore::StringFormat("Il faut {} points dans cet arbre pour cette rangée.", talent->Row * MAX_TALENT_RANK);

    uint32 sort = talent->RankID[rang];
    SpellInfo const* info = sSpellMgr->GetSpellInfo(sort);
    if (!info)
        return "Talent inconnu.";

    // Comme Player::LearnTalent : sort ajouté au grimoire si le talent le demande, sorts additionnels, puis le talent.
    bool appris = false;
    if (talent->addToSpellBook && !info->HasAttribute(SPELL_ATTR0_PASSIVE) && !info->HasEffect(SPELL_EFFECT_LEARN_SPELL))
    {
        player->learnSpell(sort);
        appris = true;
    }
    if (!appris)
        player->SendLearnPacket(sort, true);
    for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
        if (info->Effects[i].Effect == SPELL_EFFECT_LEARN_SPELL && sSpellMgr->IsAdditionalTalentSpell(info->Effects[i].TriggerSpell))
            player->learnSpell(info->Effects[i].TriggerSpell);

    player->addTalent(sort, player->GetActiveSpecMask(), actuel);
    player->SetFreeTalentPoints(libres - cout);
    return "";
}

class solazeroth_talents_commandes : public CommandScript
{
public:
    solazeroth_talents_commandes() : CommandScript("solazeroth_talents_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "onglets",   HandleOnglets,   SEC_PLAYER, Console::No },
            { "arbre",     HandleArbre,     SEC_PLAYER, Console::No },
            { "apprendre", HandleApprendre, SEC_PLAYER, Console::No },
            { "prix",      HandlePrix,      SEC_PLAYER, Console::No },
            { "reinitialiser", HandleReinitialiser, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "soltalent", sousCommandes },
        };
        return commandes;
    }

    // Les trois arbres d'une classe, dans l'ordre de leurs pages.
    static bool HandleOnglets(ChatHandler* handler, uint8 classe)
    {
        Player* player = handler->GetPlayer();
        if (classe == 0 || classe >= MAX_CLASSES)
            return true;
        std::array<uint32, 3> pages = { 0, 0, 0 };
        for (auto const& [onglet, talents] : talentsParOnglet)
            if (TalentTabEntry const* t = sTalentTabStore.LookupEntry(onglet))
                if ((t->ClassMask & (1 << (classe - 1))) && t->tabpage < 3)
                    pages[t->tabpage] = onglet;
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("O;{};{};{};{};{}",
            classe, pages[0], pages[1], pages[2], OngletEtranger(player)));
        return true;
    }

    static bool HandleArbre(ChatHandler* handler, uint32 onglet)
    {
        EnvoyerArbre(handler->GetPlayer(), onglet);
        return true;
    }

    static bool HandleApprendre(ChatHandler* handler, uint32 talentId)
    {
        Player* player = handler->GetPlayer();
        TalentEntry const* talent = sTalentStore.LookupEntry(talentId);
        if (!talent)
            return true;
        if (player->IsInCombat())
        {
            handler->SendSysMessage("Impossible en combat.");
            return true;
        }
        if (!OngletDeLaClasse(player, talent->TalentTab) && SolAzeroth::EstDestin(player))
        {
            handler->SendSysMessage("|cffff0000Ligue Destin : pas de talents d'une autre classe.|r");
            EnvoyerArbre(player, talent->TalentTab);
            return true;
        }
        uint8 actuel = RangActuel(player, talent);
        std::string erreur = SolAzeroth::ApprendreTalent(player, talentId, actuel);
        if (!erreur.empty())
            handler->SendSysMessage("|cffff0000" + erreur + "|r");
        else
            player->SendTalentsInfoData(false);
        EnvoyerArbre(player, talent->TalentTab);
        return true;
    }

    static bool HandlePrix(ChatHandler* handler)
    {
        EnvoyerPrix(handler->GetPlayer());
        return true;
    }

    static bool HandleReinitialiser(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (player->IsInCombat())
        {
            handler->SendSysMessage("Impossible en combat.");
            return true;
        }
        uint32 guid = player->GetGUID().GetCounter();
        uint32 comptees = ReinitialisationsComptees(guid);
        uint32 prix = PrixReinitialisation(player, comptees);
        if (!player->HasEnoughMoney(prix))
        {
            handler->SendSysMessage(Acore::StringFormat("|cffff0000Il faut {} po pour réinitialiser tes talents.|r", prix / GOLD));
            return true;
        }
        if (player->IsNonMeleeSpellCast(false))
            player->InterruptNonMeleeSpells(false);
        // Sans frais côté jeu : le prix est celui du module.
        if (!player->resetTalents(true))
        {
            handler->SendSysMessage("Aucun point de talent à réinitialiser.");
            return true;
        }
        player->ModifyMoney(-int32(prix));
        CharacterDatabase.Execute("REPLACE INTO solazeroth_reinit_talents (guid, nombre, derniere) VALUES ({}, {}, {})",
            guid, comptees + 1, GameTime::GetGameTime().count());
        player->SendTalentsInfoData(false);
        handler->SendSysMessage(Acore::StringFormat("Talents réinitialisés pour {} po. Prochaine réinitialisation : {} po.",
            prix / GOLD, PrixReinitialisation(player, comptees + 1) / GOLD));
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "REINIT");
        EnvoyerPrix(player);
        return true;
    }
};

class solazeroth_talents_monde : public WorldScript
{
public:
    solazeroth_talents_monde() : WorldScript("solazeroth_talents_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reinit.orParNiveau = sConfigMgr->GetOption<uint32>("SolAzeroth.Talents.ReinitOrParNiveau", 1);
        reinit.multiplicateur = sConfigMgr->GetOption<float>("SolAzeroth.Talents.ReinitMultiplicateur", 2.0f);
        reinit.baisseJours = sConfigMgr->GetOption<uint32>("SolAzeroth.Talents.ReinitBaisseJours", 7);
    }

    // Arbres des classes (pas ceux des familiers), talents par onglet.
    void OnStartup() override
    {
        for (uint32 i = 0; i < sTalentStore.GetNumRows(); ++i)
        {
            TalentEntry const* t = sTalentStore.LookupEntry(i);
            if (!t)
                continue;
            TalentTabEntry const* onglet = sTalentTabStore.LookupEntry(t->TalentTab);
            if (onglet && onglet->ClassMask)
                talentsParOnglet[t->TalentTab].push_back(t);
        }
        LOG_INFO("module", "Sol'Azeroth talents : {} arbres de classe", talentsParOnglet.size());
    }
};

void AddSC_solazeroth_talents_etrangers()
{
    new solazeroth_talents_commandes();
    new solazeroth_talents_monde();
}
