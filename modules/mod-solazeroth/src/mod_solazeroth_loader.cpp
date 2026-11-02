#include "SolAzeroth.h"
#include "Config.h"
#include "Define.h"

void Addmod_solazerothScripts()
{
    // SolAzeroth.Version = 3 (refonte v3 du 30/10/2026) : les systèmes bâtis sur les niveaux, les ressources et les
    // talents de la v2 ne sont plus chargés. Les réglages des modules sont lus avant le chargement des scripts.
    bool const v3 = sConfigMgr->GetOption<int32>("SolAzeroth.Version", 3) >= 3;
    if (!v3)
    {
        AddSC_solazeroth_menace();
        AddSC_solazeroth_bonus_solo();
        AddSC_solazeroth_formation();
        AddSC_solazeroth_banque();
        AddSC_solazeroth_specialisations();
        AddSC_solazeroth_defi_exterieur();
        AddSC_solazeroth_ressources();
        AddSC_solazeroth_familiers();
        AddSC_solazeroth_talents_etrangers();
        AddSC_solazeroth_bonus_hauts_faits();
        AddSC_solazeroth_ecart();
        AddSC_solazeroth_affixes_mecanique();
        AddSC_solazeroth_histoire();
        AddSC_solazeroth_echelle();
        AddSC_solazeroth_ligues();
        AddSC_solazeroth_metiers();         // métiers partagés : en v3, plus de niveau de métier
        AddSC_solazeroth_hauts_faits();     // hauts faits v2 (points de talent, Marques) : retirés en v3 le 31/10/2026
        AddSC_solazeroth_butin();           // choix du butin des boss : en v3, les chefs ne laissent que des composants (F6)
        AddSC_solazeroth_renom();           // Renom : en v3, le rang d'aventurier le remplace (v3_aventurier.cpp)
        // Audit du jeu, lot 1 (02/11/2026, « Audit du jeu\10_consensus.md », C3) : ces systèmes v2 payaient encore en
        // v3 sans interface. Leurs fonctions restent dans le module (la v3 donne et retire les Marques avec celles de
        // marques.cpp), mais leurs scripts ne tournent plus.
        AddSC_solazeroth_marques();         // 3 Marques par quête rendue, Marques des boss selon la menace, jetons dus
        AddSC_solazeroth_bonus();           // enchantement de bonus des boss et .solameliorer (+Endurance par rang)
        AddSC_solazeroth_defis_boss();      // défis de boss tirés au sort (à réécrire en v3, visibles)
        AddSC_solazeroth_intendant();       // butin bleu des boss contre des Marques
        AddSC_solazeroth_contrats();        // tableau de contrats et .solcontrat (les contrats v3 sont des quêtes)
        AddSC_solazeroth_malchance();       // protection contre la malchance et Éclats de raid
        AddSC_solazeroth_codex();           // Codex : en v3, le pourcentage de zone et le rang d'aventurier
        AddSC_solazeroth_journal_collection();  // journal de collection des boss : en v3, la Collection
    }
    else
    {
        AddSC_solazeroth_v3_niveau();
        AddSC_solazeroth_v3_combat();
        AddSC_solazeroth_v3_kit();
        AddSC_solazeroth_v3_fournisseur();
        AddSC_solazeroth_v3_semaine();
        AddSC_solazeroth_v3_paroles();
        AddSC_solazeroth_v3_rares_secrets();
        AddSC_solazeroth_v3_filons();
        AddSC_solazeroth_v3_journal();
        AddSC_solazeroth_v3_mort();
        AddSC_solazeroth_v3_bivouac();
        AddSC_solazeroth_v3_collection();
        AddSC_solazeroth_v3_carte();
        AddSC_solazeroth_v3_zone();
        AddSC_solazeroth_v3_annexes();
        AddSC_solazeroth_v3_gouffre();
        AddSC_solazeroth_v3_equipement();
        AddSC_solazeroth_v3_cuisine();
        AddSC_solazeroth_v3_ame();
        AddSC_solazeroth_v3_modes();
        AddSC_solazeroth_v3_aventurier();
        AddSC_solazeroth_v3_donjons();
        AddSC_solazeroth_v3_passifs();
        AddSC_solazeroth_v3_inventaire();
        AddSC_solazeroth_v3_signalement();
    }
    AddSC_solazeroth_reinitialisation();
    AddSC_solazeroth_journal();
    AddSC_solazeroth_pistage();
    AddSC_solazeroth_hardcore();
    AddSC_solazeroth_ambiance();
    AddSC_solazeroth_citadelle();
    AddSC_solazeroth_naxxramas();
    AddSC_solazeroth_ulduar();
    AddSC_solazeroth_croise();
    AddSC_solazeroth_raids();
    AddSC_solazeroth_addon();
    AddSC_solazeroth_raids_anciens();
}
