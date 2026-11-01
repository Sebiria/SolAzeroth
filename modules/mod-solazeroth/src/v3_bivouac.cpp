// v3 (31/10/2026) : potion et feu de camp, rang de départ (document v3, F7). Deux boutons à droite des techniques
// (SolUI_Bivouac.lua), pour ne plus attendre que la vie remonte seule entre deux combats.
// - Potion de soins (100029) : rend SoinPotion % de la vie maximale. Charges() charge(s), gardée(s) en base ; elles
//   reviennent toutes avec le Repos au coin du feu, et en zone de repos (auberge, ville).
// - Feu de camp (100030) : pose un feu pour 2 minutes (objet 29784, comme le Feu de camp simple de Blizzard), sans le
//   Feu douillet de Blizzard (+4 esprit, piège lié au feu). Le personnage s'assoit aussitôt ; se lever, entrer en
//   combat ou mourir éteint le feu (31/10/2026, demande de l'utilisateur). Assis : REGEN_FEU % de la vie toutes les
//   2 s, et au bout de 60 s le Repos au coin du feu (100031, vie maximale +5 % pendant 30 minutes) et les potions.
// - Repos au coin du feu : hors combat, RegenRepos % de la vie maximale par seconde (demande du 31/10/2026 ;
//   2 % au nœud 2 du camp, F7).
// - Arbre du camp (31/10/2026, proposition de l'utilisateur ; la suite de l'arbre reste à débattre) : premier nœud,
//   NOEUD_FEU_1 Marques (.camp acheter), le Repos au coin du feu donne en plus +10 % de dégâts (sort 100032, lancé à
//   la place de 100031). Rang gardé dans solazeroth_v3_bivouac.rang_feu.
// - F7 (01/11/2026, chiffres de l'utilisateur ; listes de courses dans solazeroth_v3_camp_couts, migration 089,
//   écrites par outils\bivouac_v3.py) : achetables partout, sans condition de contenu.
//   - Potion (.camp potion) : rang 1, 2 charges et 35 % ; rang 2, en plus la Potion revigorante (100034, 1 % de la vie
//     par seconde pendant 10 s).
//   - Arbre du camp (.camp acheter) : nœud 2, Repos 100033, 100035 ou 100036 (vie +5 %, dégâts +10 %, +5 Force, Agilité ou Intelligence selon la
//     spécialisation) et 2 % de la vie par
//     seconde hors combat ; nœud 3, le même Repos pendant 40 minutes.
// L'interface reçoit « ETAT;charges;max;secondes avant le Repos;rang du feu;plat;rang de la potion » (préfixe SOLBIV) :
// compte à rebours du feu, arbre du camp, et plat du bouton de repas (31/10/2026, demande de l'utilisateur : gardé
// d'une session à l'autre, .camp repas <plat>, migration 082).
// Les sorts sont générés par outils\bivouac_v3.py (migration 067).

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuras.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "StringFormat.h"
#include <cmath>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLBIV";
    uint32 const POTION = 100029;
    uint32 const FEU = 100030;
    uint32 const REPOS = 100031;
    uint32 const REPOS_FLAMME = 100032;     // Repos avec +10 % de dégâts : premier nœud de l'arbre du camp
    uint32 const REPOS_BRAISES = 100033;    // nœuds 2 et 3 : vie, dégâts, Force (Agilité, Intelligence : les deux suivants)
    uint32 const REPOS_BRAISES_AGILITE = 100035;
    uint32 const REPOS_BRAISES_INTELLIGENCE = 100036;
    uint32 const TOUS_LES_REPOS[] = { REPOS, REPOS_FLAMME, REPOS_BRAISES, REPOS_BRAISES_AGILITE, REPOS_BRAISES_INTELLIGENCE };
    uint32 const REVIGORANTE = 100034;      // potion de rang 2 : 1 % de la vie par seconde pendant 10 s
    uint8 const RANG_POTION_MAX = 2, RANG_FEU_MAX = 3;
    int32 const DUREE_REPOS_BIVOUAC = 40 * MINUTE * IN_MILLISECONDS;   // nœud 3
    uint32 const NOEUD_FEU_1 = 15;          // Marques
    uint32 const FEU_DOUILLET = 7353;       // aura du piège lié au feu de Blizzard
    uint32 const OBJET_FEU = 29784;
    uint32 const TICK = 2000;
    uint32 const TICK_FEU = 250;            // se lever éteint le feu presque aussitôt
    uint32 const RECHERCHE_FEU = 3000;      // délai pour trouver le feu après l'incantation
    uint32 const RENVOI = 10000;            // l'état repart au moins toutes les 10 s : l'interface le retrouve après un /reload
    uint32 const ASSIS_POUR_REPOS = 60000;
    float const PORTEE_FEU = 10.0f;
    float const REGEN_FEU = 6.0f;

    struct Bivouac : DataMap::Base
    {
        uint8 charges = 1;
        uint8 rangPotion = 0;
        uint8 rangFeu = 0;
        uint32 repas = 0;
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

    uint8 Charges(Bivouac const* b) { return b->rangPotion >= 1 ? 2 : 1; }
    float SoinPotion(Bivouac const* b) { return b->rangPotion >= 1 ? 35.0f : 30.0f; }
    bool EnRepos(Player* player)
    {
        for (uint32 repos : TOUS_LES_REPOS)
            if (player->HasAura(repos))
                return true;
        return false;
    }

    float RegenRepos(Player* player)   // % par seconde
    {
        return player->HasAura(REPOS_BRAISES) || player->HasAura(REPOS_BRAISES_AGILITE)
            || player->HasAura(REPOS_BRAISES_INTELLIGENCE) ? 2.0f : 1.0f;
    }

    // Repos des nœuds 2 et 3 : celui de la caractéristique principale de la spécialisation (v3_kit.cpp).
    uint32 ReposBraises(Player* player)
    {
        switch (SolAzeroth::CaracteristiquePrincipale(player))
        {
            case STAT_AGILITY: return REPOS_BRAISES_AGILITE;
            case STAT_INTELLECT: return REPOS_BRAISES_INTELLIGENCE;
            default: return REPOS_BRAISES;
        }
    }

    void Sauver(Player* player)
    {
        Bivouac* b = BivouacDe(player);
        CharacterDatabase.Execute("INSERT INTO solazeroth_v3_bivouac (guid, charges, rang_potion, rang_feu, repas) "
            "VALUES ({}, {}, {}, {}, {}) ON DUPLICATE KEY UPDATE charges = VALUES(charges), rang_potion = VALUES(rang_potion), "
            "rang_feu = VALUES(rang_feu), repas = VALUES(repas)",
            player->GetGUID().GetCounter(), b->charges, b->rangPotion, b->rangFeu, b->repas);
    }

    void Envoyer(Player* player, bool force = false)
    {
        Bivouac* b = BivouacDe(player);
        // Dernier champ : secondes avant le Repos au coin du feu (0 hors du feu), pour le compte à rebours de l'interface.
        uint32 restant = b->allume && b->feu && b->assis < ASSIS_POUR_REPOS ? (ASSIS_POUR_REPOS - b->assis) / 1000 : 0;
        std::string message = Acore::StringFormat("ETAT;{};{};{};{};{};{}", b->charges, Charges(b), restant, b->rangFeu,
            b->repas, b->rangPotion);
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
        if (Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr)
        {
            SetHitHeal(int32(std::lround(joueur->GetMaxHealth() * SoinPotion(BivouacDe(joueur)) / 100.0f)));
            if (BivouacDe(joueur)->rangPotion >= 2)
                joueur->CastSpell(joueur, REVIGORANTE, true);
        }
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
        if (QueryResult r = CharacterDatabase.Query("SELECT charges, rang_feu, repas, rang_potion FROM solazeroth_v3_bivouac "
            "WHERE guid = {}", player->GetGUID().GetCounter()))
        {
            b->rangFeu = (*r)[1].Get<uint8>();
            b->repas = (*r)[2].Get<uint32>();
            b->rangPotion = std::min((*r)[3].Get<uint8>(), RANG_POTION_MAX);
            b->charges = std::min((*r)[0].Get<uint8>(), Charges(b));
        }
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
            FixerCharges(player, Charges(b));

        if (b->allume && b->feu && player->IsSitState())
        {
            bool avant = b->assis < ASSIS_POUR_REPOS;
            b->assis += TICK;
            player->ModifyHealth(int32(std::lround(player->GetMaxHealth() * REGEN_FEU / 100.0f)));
            if (avant && b->assis >= ASSIS_POUR_REPOS)
            {
                for (uint32 repos : TOUS_LES_REPOS)
                    player->RemoveAurasDueToSpell(repos);
                uint32 repos = b->rangFeu >= 2 ? ReposBraises(player) : b->rangFeu >= 1 ? REPOS_FLAMME : REPOS;
                player->CastSpell(player, repos, true);
                if (b->rangFeu >= 3)
                    if (Aura* aura = player->GetAura(repos))
                    {
                        aura->SetMaxDuration(DUREE_REPOS_BIVOUAC);
                        aura->SetDuration(DUREE_REPOS_BIVOUAC);
                    }
                FixerCharges(player, Charges(b));
            }
        }

        if (EnRepos(player) && !player->IsInCombat() && player->IsAlive() && !player->IsFullHealth())
            player->ModifyHealth(int32(std::lround(player->GetMaxHealth() * RegenRepos(player) * TICK / 1000 / 100.0f)));

        Envoyer(player, b->depuisEnvoi >= RENVOI);
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_bivouac WHERE guid = {}", guid.GetCounter());
    }
};

class solazeroth_v3_bivouac_commandes : public CommandScript
{
public:
    solazeroth_v3_bivouac_commandes() : CommandScript("solazeroth_v3_bivouac_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable camp =
        {
            { "acheter", HandleAcheter, SEC_PLAYER, Console::No },
            { "potion",  HandlePotion,  SEC_PLAYER, Console::No },
            { "repas",   HandleRepas,   SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "camp", camp },
        };
        return commandes;
    }

    // .camp repas <plat> : plat du bouton de repas, envoyé par l'interface quand on y en glisse un (0 : aucun).
    static bool HandleRepas(ChatHandler* handler, uint32 plat)
    {
        Player* player = handler->GetPlayer();
        if (plat && !WorldDatabase.Query("SELECT 1 FROM solazeroth_v3_plats WHERE objet = {}", plat))
        {
            handler->SendErrorMessage("Ce n'est pas un plat de la cuisine.");
            return false;
        }
        Bivouac* b = BivouacDe(player);
        b->repas = plat;
        Sauver(player);
        Envoyer(player, true);
        return true;
    }

    // Liste de courses (solazeroth_v3_camp_couts ; objet 0 = or) : vérifie tout, puis prend tout. Faux s'il manque
    // quelque chose (le message dit quoi).
    static bool Payer(ChatHandler* handler, Player* player, uint8 genre, uint8 rang)
    {
        std::vector<std::pair<uint32, uint32>> couts;
        if (QueryResult r = WorldDatabase.Query("SELECT objet, nombre FROM solazeroth_v3_camp_couts WHERE genre = {} AND "
            "rang = {}", genre, rang))
        {
            do
                couts.emplace_back((*r)[0].Get<uint32>(), (*r)[1].Get<uint32>());
            while (r->NextRow());
        }
        if (couts.empty())
            return false;
        auto possede = [player](uint32 objet)
        {
            return SolAzeroth::NombreEnCollection(player, objet) + player->GetItemCount(objet);
        };
        for (auto const& [objet, nombre] : couts)
        {
            if (!objet ? !player->HasEnoughMoney(nombre) : possede(objet) < nombre)
            {
                ItemTemplate const* modele = objet ? sObjectMgr->GetItemTemplate(objet) : nullptr;
                handler->SendErrorMessage("Camp : il manque {}.", !objet ? "de l'or" : Acore::StringFormat("{} × {}",
                    nombre - possede(objet), modele ? modele->Name1 : std::to_string(objet)));
                return false;
            }
        }
        for (auto const& [objet, nombre] : couts)
        {
            if (!objet)
            {
                player->ModifyMoney(-int32(nombre));
                continue;
            }
            uint32 range = std::min(nombre, SolAzeroth::NombreEnCollection(player, objet));
            if (range)
                SolAzeroth::RetirerDeCollection(player, objet, range);
            if (nombre > range)
                player->DestroyItemCount(objet, nombre - range, true);
        }
        return true;
    }

    // .camp potion : achète le rang suivant de la potion.
    static bool HandlePotion(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Bivouac* b = BivouacDe(player);
        if (b->rangPotion >= RANG_POTION_MAX)
        {
            handler->SendSysMessage("Potion : déjà au rang maximal.");
            return true;
        }
        if (!Payer(handler, player, 1, b->rangPotion + 1))
            return true;
        ++b->rangPotion;
        b->charges = Charges(b);
        Sauver(player);
        Envoyer(player, true);
        handler->SendSysMessage(b->rangPotion == 1 ? "Potion de Durotar : 2 charges, 35 % de la vie."
            : "Potion revigorante : en plus, 1 % de la vie par seconde pendant 10 s.");
        return true;
    }

    // .camp acheter : achète le nœud suivant de l'arbre du camp.
    static bool HandleAcheter(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Bivouac* b = BivouacDe(player);
        if (b->rangFeu >= RANG_FEU_MAX)
        {
            handler->SendSysMessage("Camp : tout l'arbre est acquis.");
            return true;
        }
        if (b->rangFeu >= 1)
        {
            if (!Payer(handler, player, 2, b->rangFeu + 1))
                return true;
            ++b->rangFeu;
            Sauver(player);
            Envoyer(player, true);
            handler->SendSysMessage(b->rangFeu == 2 ? "Braises tenaces : le Repos donne +5 Force et rend 2 % de la vie par "
                "seconde, au prochain feu." : "Feu de bivouac : le Repos dure 40 minutes, au prochain feu.");
            return true;
        }
        if (SolAzeroth::Marques(player) < NOEUD_FEU_1 || !SolAzeroth::RetirerMarques(player, NOEUD_FEU_1))
        {
            handler->PSendSysMessage("Camp : il faut {} Marques du voyageur (tu en as {}).", NOEUD_FEU_1,
                SolAzeroth::Marques(player));
            return true;
        }
        b->rangFeu = 1;
        Sauver(player);
        Envoyer(player, true);
        handler->SendSysMessage("Camp : le Repos au coin du feu donne maintenant aussi +10 % de dégâts.");
        return true;
    }
};

void AddSC_solazeroth_v3_bivouac()
{
    new solazeroth_v3_bivouac_joueur();
    new solazeroth_v3_bivouac_commandes();
    RegisterSpellScript(spell_solazeroth_v3_potion);
    RegisterSpellScript(spell_solazeroth_v3_feu);
}
