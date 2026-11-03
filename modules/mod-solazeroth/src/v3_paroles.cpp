// Audit du jeu, lot 6b (02/11/2026, C8 ; choix de l'utilisateur : « chefs + 3 scènes », et la fenêtre jamais en
// combat) : l'histoire se joue.
// - Les chefs de l'histoire crient une réplique en engageant le combat : une bulle au-dessus d'eux (Yell), pas de
//   fenêtre.
// - Trois scènes au rendu des quêtes clés (D07 Yarrog, D12 Benedict, D30 Taragaman) : le serveur envoie
//   « SCENE;quête » (préfixe SOLPAROLE), le client les joue dans sa fenêtre de paroles (SolUI_Paroles.lua), hors combat.
// - Lot T2 des Tarides (03/11/2026) : plus rien d'écrit en dur pour Durotar. Les cris sont dans la table
//   solazeroth_v3_cris (créature, zone, texte ; migration 139), lue au démarrage ; le serveur annonce chaque quête rendue
//   et le client ne joue que les scènes qu'il connaît (Durotar : D07, D12, D30 ; les Tarides : T08, T27, T36).

#include "SolAzeroth.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <string>
#include <unordered_map>

namespace
{
    std::unordered_map<uint32, std::string> cris;   // créature -> son cri (solazeroth_v3_cris)

    struct Crie : DataMap::Base { };
}

class solazeroth_v3_paroles_unites : public UnitScript
{
public:
    solazeroth_v3_paroles_unites() : UnitScript("solazeroth_v3_paroles_unites", true, { UNITHOOK_ON_UNIT_ENTER_COMBAT }) { }

    void OnUnitEnterCombat(Unit* unite, Unit* cible) override
    {
        Creature* creature = unite ? unite->ToCreature() : nullptr;
        if (!creature || !cible || !cible->GetCharmerOrOwnerPlayerOrPlayerItself())
            return;
        auto it = cris.find(creature->GetEntry());
        if (it == cris.end() || creature->CustomData.Get<Crie>("solazeroth_v3_paroles"))
            return;
        creature->CustomData.GetDefault<Crie>("solazeroth_v3_paroles");   // une fois par apparition
        creature->Yell(it->second, LANG_UNIVERSAL);
    }
};

class solazeroth_v3_paroles_monde : public WorldScript
{
public:
    solazeroth_v3_paroles_monde() : WorldScript("solazeroth_v3_paroles_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        cris.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT creature, texte FROM solazeroth_v3_cris"))
            do
                cris[(*r)[0].Get<uint32>()] = (*r)[1].Get<std::string>();
            while (r->NextRow());
        LOG_INFO("module", "Sol'Azeroth v3 : {} cris de chefs", cris.size());
    }
};

// Récompense d'une quête (appelé à la fin de Player::RewardQuest) : la scène, si le client en a une pour elle.
// Signalement 29 (03/11/2026) : le calcul de l'expérience, utilisé jusque-là, a lieu aussi à l'affichage de la
// quête, avant de l'accepter.
class solazeroth_v3_paroles_joueur : public PlayerScript
{
public:
    solazeroth_v3_paroles_joueur() : PlayerScript("solazeroth_v3_paroles_joueur", { PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST }) { }

    void OnPlayerCompleteQuest(Player* player, Quest const* quete) override
    {
        if (quete)
            SolAzeroth::EnvoyerAddon(player, "SOLPAROLE", Acore::StringFormat("SCENE;{}", quete->GetQuestId()));
    }
};

void AddSC_solazeroth_v3_paroles()
{
    new solazeroth_v3_paroles_monde();
    new solazeroth_v3_paroles_unites();
    new solazeroth_v3_paroles_joueur();
}
