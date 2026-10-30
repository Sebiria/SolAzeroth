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
    }
    else
        AddSC_solazeroth_v3_niveau();
    AddSC_solazeroth_reinitialisation();
    AddSC_solazeroth_butin();
    AddSC_solazeroth_journal();
    AddSC_solazeroth_pistage();
    AddSC_solazeroth_marques();
    AddSC_solazeroth_bonus();
    AddSC_solazeroth_defis_boss();
    AddSC_solazeroth_metiers();
    AddSC_solazeroth_intendant();
    AddSC_solazeroth_contrats();
    AddSC_solazeroth_malchance();
    AddSC_solazeroth_hauts_faits();
    AddSC_solazeroth_codex();
    AddSC_solazeroth_renom();
    AddSC_solazeroth_journal_collection();
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
