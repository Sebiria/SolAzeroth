// Monnaie « Marque du voyageur » (section 7.5) : objet 37711, rangé dans l'onglet Monnaie (migration 035).
// Sources (valeurs provisoires dans mod_solazeroth.conf) :
//   - boss de donjon : SolAzeroth.Marques.Boss + rang de menace ; dernier boss : + SolAzeroth.Marques.DernierBoss,
//     une seule fois par personnage, boss et rang (les rangs inférieurs pas encore payés sont rattrapés)
//   - quête rendue : 1 + niveau du personnage / SolAzeroth.Marques.QueteNiveaux (section 7.6), soit 1, 2 dès le niveau 40, 3 au 80
//   - défis : les jetons mis de côté dans solazeroth_jetons_dus sont versés à la connexion.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DBCStores.h"
#include "DatabaseEnv.h"
#include "Formulas.h"
#include "Map.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"

namespace
{
    uint32 const MARQUE = 37711;   // jeton de test du jeu, monnaie connue du client (migration 035)

    // Monnaie « connue » : elle s'affiche dans l'onglet Monnaie (Player::AddKnownCurrency est privée).
    void MonnaieConnue(Player* player)
    {
        if (CurrencyTypesEntry const* monnaie = sCurrencyTypesStore.LookupEntry(MARQUE))
            player->SetFlag64(PLAYER_FIELD_KNOWN_CURRENCIES, 1LL << (monnaie->BitIndex - 1));
    }

    struct Reglages
    {
        uint32 boss = 2;
        uint32 dernierBoss = 5;
        uint32 queteNiveaux = 40;
    } reglages;
}

uint32 SolAzeroth::Marques(Player* player)
{
    return player->GetItemCount(MARQUE, true);
}

bool SolAzeroth::DonnerMarques(Player* player, uint32 nombre, std::string const& raison)
{
    if (!nombre)
        return true;
    if (!player->AddItem(MARQUE, nombre))
    {
        ChatHandler(player->GetSession()).SendSysMessage("|cffff0000Sacs pleins : Marques du voyageur perdues.|r");
        return false;
    }
    MonnaieConnue(player);
    ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cffffd100+{} Marque{} du voyageur|r ({}).",
        nombre, nombre > 1 ? "s" : "", raison));
    return true;
}

bool SolAzeroth::RetirerMarques(Player* player, uint32 nombre)
{
    if (Marques(player) < nombre)
        return false;
    player->DestroyItemCount(MARQUE, nombre, true, true);
    return true;
}

class solazeroth_marques_joueur : public PlayerScript
{
public:
    solazeroth_marques_joueur() : PlayerScript("solazeroth_marques_joueur", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST }) { }

    // Jetons gagnés par les défis avant l'existence de la monnaie (et depuis) : versés à la connexion.
    void OnPlayerLogin(Player* player) override
    {
        // La Marque apparaît dans l'onglet Monnaie de la fiche de personnage, même à 0.
        MonnaieConnue(player);
        uint32 compte = player->GetSession()->GetAccountId();
        QueryResult resultat = CharacterDatabase.Query("SELECT jetons FROM solazeroth_jetons_dus WHERE account = {}", compte);
        if (!resultat)
            return;
        uint32 jetons = (*resultat)[0].Get<uint32>();
        if (jetons && SolAzeroth::DonnerMarques(player, jetons, "récompenses de défis en attente"))
            CharacterDatabase.Execute("UPDATE solazeroth_jetons_dus SET jetons = jetons - {} WHERE account = {}", jetons, compte);
    }

    void OnPlayerCompleteQuest(Player* player, Quest const* quete) override
    {
        SolAzeroth::DonnerMarques(player, SolAzeroth::MarquesDefiExterieur(player, quete->GetQuestId(),
            1 + player->GetLevel() / std::max<uint32>(1, reglages.queteNiveaux)), "quête rendue");
    }
};

class solazeroth_marques_boss : public UnitScript
{
public:
    solazeroth_marques_boss() : UnitScript("solazeroth_marques_boss", true, { UNITHOOK_ON_UNIT_DEATH }) { }

    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        Creature* boss = unite->ToCreature();
        if (!boss || !boss->IsDungeonBoss())
            return;
        Map* map = boss->GetMap();
        if (!map->IsDungeon())
            return;
        // Une seule fois par personnage, boss et rang : une victoire à un rang plus haut que le dernier payé paie aussi
        // les rangs inférieurs pas encore payés ; un rang déjà payé (ou plus bas) ne rapporte plus rien (migration 037).
        // Le rang compté est le palier de butin (rang + points des affixes de mécanique, section 4.4).
        int32 rang = SolAzeroth::PalierButin(map);
        uint32 bonusFinal = SolAzeroth::EstBossFinal(boss->GetEntry()) ? reglages.dernierBoss : 0;
        for (auto const& ref : map->GetPlayers())
        {
            Player* player = ref.GetSource();
            if (!player)
                continue;
            // Boss gris pour ce personnage : rien, et le rang n'est pas noté comme payé (il pourra l'être au bon niveau,
            // sur un autre personnage). Calibrage final, 29/10/2026.
            if (boss->GetLevel() <= Acore::XP::GetGrayLevel(player->GetLevel()))
                continue;
            int32 paye = -1;
            if (QueryResult r = CharacterDatabase.Query("SELECT rang FROM solazeroth_marques_boss WHERE guid = {} AND boss = {}",
                player->GetGUID().GetCounter(), boss->GetEntry()))
                paye = (*r)[0].Get<uint8>();
            if (rang <= paye)
                continue;
            uint32 nombre = 0;
            for (int32 k = paye + 1; k <= rang; ++k)
                nombre += reglages.boss + uint32(k) + bonusFinal;
            CharacterDatabase.Execute("REPLACE INTO solazeroth_marques_boss (guid, boss, rang) VALUES ({}, {}, {})",
                player->GetGUID().GetCounter(), boss->GetEntry(), rang);
            SolAzeroth::DonnerMarques(player, nombre, boss->GetName());
        }
    }
};

class solazeroth_marques_config : public WorldScript
{
public:
    solazeroth_marques_config() : WorldScript("solazeroth_marques_config", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.boss = sConfigMgr->GetOption<uint32>("SolAzeroth.Marques.Boss", 2);
        reglages.dernierBoss = sConfigMgr->GetOption<uint32>("SolAzeroth.Marques.DernierBoss", 5);
        reglages.queteNiveaux = sConfigMgr->GetOption<uint32>("SolAzeroth.Marques.QueteNiveaux", 40);
    }
};

void AddSC_solazeroth_marques()
{
    new solazeroth_marques_joueur();
    new solazeroth_marques_boss();
    new solazeroth_marques_config();
}
