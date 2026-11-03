// Audit du jeu, lot 6b (02/11/2026, C8 ; choix de l'utilisateur : « chefs + 3 scènes », et la fenêtre jamais en
// combat) : l'histoire se joue.
// - Les chefs de l'histoire crient une réplique en engageant le combat : une bulle au-dessus d'eux (Yell), pas de
//   fenêtre.
// - Trois scènes au rendu des quêtes clés (D07 Yarrog, D12 Benedict, D30 Taragaman) : le serveur envoie
//   « SCENE;quête » (préfixe SOLPAROLE), le client les joue dans sa fenêtre de paroles (SolUI_Paroles.lua), hors combat.

#include "SolAzeroth.h"
#include "Creature.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <unordered_map>
#include <unordered_set>

namespace
{
    std::unordered_map<uint32, char const*> const CRIS = {
        { 3183, "Les recrues de Thrall… La Lame ardente a faim de chair fraîche !" },          // Yarrog Plaie-d'ombre
        { 3192, "Un orc dans mon donjon ? Gardes ! Abattez-le !" },                           // Lieutenant Benedict
        { 5808, "La combe est aux Kolkar ! Tu n'en sortiras pas vivant." },                   // Kolkanis
        { 3205, "Mes enfants, à moi ! Vol'jin paiera pour cette insolence !" },               // Zalazane
        { 3203, "Tu tombes mal : je préparais justement un petit feu…" },                     // Féplouf Sombrorage
        { 3204, "L'Œil m'a montré ta venue. Il m'a aussi montré ta mort." },                  // Gazz'uz
        { 11517, "Intrus ! Les Ragefeu vont t'écraser !" },                                   // Lorgnesilex
        { 11518, "Les ombres répondent à mon appel, pas au tien !" },                         // Jergosh l'Invocateur
        { 11519, "Tu oses descendre dans l'antre de la Lame ?" },                             // Bazzalan
        { 11520, "Encore un cœur à dévorer ! Approche !" },                                   // Taragaman l'Affameur
    };
    std::unordered_set<uint32> const SCENES = { 910007, 910012, 910030 };

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
        auto it = CRIS.find(creature->GetEntry());
        if (it == CRIS.end() || creature->CustomData.Get<Crie>("solazeroth_v3_paroles"))
            return;
        creature->CustomData.GetDefault<Crie>("solazeroth_v3_paroles");   // une fois par apparition
        creature->Yell(it->second, LANG_UNIVERSAL);
    }
};

// Récompense d'une quête (appelé à la fin de Player::RewardQuest) : la scène, s'il y en a une. Signalement 29
// (03/11/2026) : le calcul de l'expérience, utilisé jusque-là, a lieu aussi à l'affichage de la quête, avant de l'accepter.
class solazeroth_v3_paroles_joueur : public PlayerScript
{
public:
    solazeroth_v3_paroles_joueur() : PlayerScript("solazeroth_v3_paroles_joueur", { PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST }) { }

    void OnPlayerCompleteQuest(Player* player, Quest const* quete) override
    {
        if (quete && SCENES.count(quete->GetQuestId()))
            SolAzeroth::EnvoyerAddon(player, "SOLPAROLE", Acore::StringFormat("SCENE;{}", quete->GetQuestId()));
    }
};

void AddSC_solazeroth_v3_paroles()
{
    new solazeroth_v3_paroles_unites();
    new solazeroth_v3_paroles_joueur();
}
