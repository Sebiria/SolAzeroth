// Audit du jeu, lot 4a (02/11/2026, C4 du consensus, choix de l'utilisateur : « Oui, dans le 4a ») : boucle de la
// semaine. La semaine commence le lundi à 0 h (heure du serveur, UTC).
// - Affixe de la semaine : une technique de donjon (Enragé, Renforçant, Volcanique, Explosif, à tour de rôle), toujours
//   présente dans les donjons à difficulté (le Gouffre de Ragefeu), même en difficulté 1 où elle ne change pas la
//   puissance des monstres (v3_donjons.cpp, v3_modes.cpp). Les difficultés au-dessus en ajoutent d'autres.
// - Objectif de la semaine, au compte (table solazeroth_v3_semaine, migration 114), à tour de rôle : terminer un donjon
//   (son dernier boss), payer 3 défis plein tarif, abattre 5 élites ou rares de ta puissance (2 de moins au plus).
//   Récompense une fois par semaine et par compte : 1 composant de donjon (lot T7 des Tarides : celui du dernier donjon
//   terminé, la Braise du Gouffre tant qu'aucun) et 1 pierre taillée dans la Collection (lot T10 : du même donjon),
//   et 60 points de rang d'aventurier (v3_aventurier.cpp).
// - Interface (préfixe SOLSEMAINE, fenêtre des objectifs) : « SEMAINE;affixe;objectif;progrès;but;payé;composant ».

#include "SolAzeroth.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <unordered_map>

namespace
{
    char const* const PREFIXE = "SOLSEMAINE";
    uint8 const AFFIXES[] = { 1, 2, 4, 8 };      // Enragé, Renforçant, Volcanique, Explosif (v3_modes.cpp)
    uint32 const BUTS[] = { 0, 1, 3, 5 };          // indexés par SolAzeroth::ObjectifSemaine

    struct Progres
    {
        uint32 semaine = 0, progres = 0;
        bool paye = false;
    };
    std::unordered_map<uint32, Progres> comptes;

    uint32 Semaine()
    {
        return uint32((time(nullptr) - 4 * DAY) / WEEK);   // le 05/01/1970 était un lundi
    }

    uint8 ObjectifDe(uint32 semaine)
    {
        return uint8(1 + semaine % 3);
    }

    Progres& ProgresDe(Player* player)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        auto it = comptes.find(compte);
        if (it == comptes.end())
        {
            it = comptes.emplace(compte, Progres()).first;
            if (QueryResult r = CharacterDatabase.Query("SELECT semaine, progres, paye FROM solazeroth_v3_semaine WHERE compte = {}",
                compte))
                it->second = { (*r)[0].Get<uint32>(), (*r)[1].Get<uint32>(), (*r)[2].Get<uint8>() != 0 };
        }
        if (it->second.semaine != Semaine())
            it->second = { Semaine(), 0, false };
        return it->second;
    }

    void Envoyer(Player* player)
    {
        Progres const& p = ProgresDe(player);
        uint8 objectif = ObjectifDe(p.semaine);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("SEMAINE;{};{};{};{};{}", uint32(SolAzeroth::AffixeSemaine()),
            uint32(objectif), p.progres, BUTS[objectif], p.paye ? 1 : 0) + Acore::StringFormat(";{}",
            SolAzeroth::ComposantDernierDonjon(player)));
    }
}

unsigned char SolAzeroth::AffixeSemaine()
{
    return AFFIXES[Semaine() % std::size(AFFIXES)];
}

void SolAzeroth::ProgresSemaine(Player* player, unsigned char objectif)
{
    Progres& p = ProgresDe(player);
    if (p.paye || ObjectifDe(p.semaine) != objectif)
        return;
    ++p.progres;
    if (p.progres >= BUTS[objectif])
    {
        p.paye = true;
        uint32 composant = ComposantDernierDonjon(player);
        AjouterACollection(player, composant, 1);
        AjouterACollection(player, PierreDernierDonjon(player), 1);
        ItemTemplate const* objet = sObjectMgr->GetItemTemplate(composant);
        ChatHandler(player->GetSession()).PSendSysMessage("|cffffd100Objectif de la semaine rempli : {} et une pierre taillée "
            "sont rangés dans la Collection.|r", objet ? objet->Name1 : "un composant de donjon");
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", "ALERTE;Objectif de la semaine rempli");
        PointsSemaine(player, p.semaine);
    }
    CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_semaine (compte, semaine, progres, paye) VALUES ({}, {}, {}, {})",
        player->GetSession()->GetAccountId(), p.semaine, p.progres, p.paye ? 1 : 0);
    Envoyer(player);
}

class solazeroth_v3_semaine_joueur : public PlayerScript
{
public:
    solazeroth_v3_semaine_joueur() : PlayerScript("solazeroth_v3_semaine_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_CREATURE_KILL }) { }

    void OnPlayerLogin(Player* player) override
    {
        Envoyer(player);
    }

    // Élite ou rare de ta puissance (pas plus de 2 de moins que ta puissance de base).
    void OnPlayerCreatureKill(Player* player, Creature* creature) override
    {
        if (creature->GetCharmerOrOwnerPlayerOrPlayerItself() || creature->IsSummon()
            || creature->GetCreatureTemplate()->rank == CREATURE_ELITE_NORMAL)
            return;
        if (SolAzeroth::PuissanceCreature(creature) + 2 < SolAzeroth::PuissanceDeBase(player))
            return;
        SolAzeroth::ProgresSemaine(player, SolAzeroth::SEMAINE_ELITES);
    }
};

void AddSC_solazeroth_v3_semaine()
{
    new solazeroth_v3_semaine_joueur();
}
