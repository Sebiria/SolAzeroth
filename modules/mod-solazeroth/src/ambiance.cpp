// PNJ d'ambiance (section 6.5, V5 ; décisions de l'utilisateur du 30/10/2026 : Hurlevent d'abord, ville animée,
// voyageurs sur les routes plus tard ; objectif du 28/10/2026 : à terme, tout le monde).
// Des silhouettes aux apparences de joueurs peuplent les capitales, Shattrath et Dalaran autour du joueur (lieux de
// solazeroth_ambiance_lieux, migration 051 ; Hurlevent sert de modèle). Ce ne sont pas des bots : un PNJ ordinaire
// (900110, migration 042), ni ciblable ni attaquable, avec une apparence de son camp et des armes tirées au sort.
// - Passants (environ 3 silhouettes sur 4) : ils suivent un bout de trajet des patrouilles du lieu (waypoint_data),
//   puis le suivant ; six sur dix courent, les autres marchent.
// - Groupes de 2 à 4 : debout face à face, ils « discutent » par gestes (parler, rire, montrer, saluer…), sans aucun mot ;
//   un groupe sur cinq est assis, au repos.
// - Cavaliers (40, à toute heure) : en selle sur une monture terrestre de joueur, à l'extérieur seulement. 25 se
//   déplacent sur les trajets (au pas ou au galop, à la vitesse d'une monture épique), les autres restent immobiles.
// Nombre selon l'heure locale (provisoire, mod_solazeroth.conf) : 240 le soir (18 h - minuit), 90 le jour (8 h - 18 h),
// 30 la nuit, multiplié par la densité du lieu. Ils apparaissent entre 40 et 130 m du joueur et disparaissent au-delà
// de 170 m, ou quand plus aucun joueur n'est dans le lieu depuis 30 s.

#include "SolAzeroth.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Map.h"
#include "MoveSpline.h"
#include "MoveSplineInit.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "TemporarySummon.h"
#include "Timer.h"
#include <array>
#include <ctime>
#include <string>
#include <vector>

namespace
{
    uint32 const SILHOUETTE = 900110;

    std::array<uint32, 11> const GESTES = { EMOTE_ONESHOT_TALK, EMOTE_ONESHOT_TALK, EMOTE_ONESHOT_TALK, EMOTE_ONESHOT_LAUGH,
        EMOTE_ONESHOT_POINT, EMOTE_ONESHOT_BOW, EMOTE_ONESHOT_QUESTION, EMOTE_ONESHOT_EXCLAMATION, EMOTE_ONESHOT_YES,
        EMOTE_ONESHOT_NO, EMOTE_ONESHOT_CHEER };

    struct Reglages
    {
        bool actif = true;
        uint32 soir = 80, jour = 30, nuit = 10;
        uint32 montures = 40;
        uint32 monturesMobiles = 25;
    } reglages;

    struct Armes { uint32 droite, gauche, distance; };

    std::array<std::vector<uint32>, 2> apparences;   // par camp : 0 Alliance, 1 Horde
    std::vector<Armes> armes;
    std::vector<uint32> montures;   // modèles des montures terrestres de joueur (migration 044)

    enum Role : uint8 { MARCHEUR, BAVARD, CAVALIER };

    struct Silhouette
    {
        ObjectGuid guid;
        Role role;
        int32 restant;        // durée de vie, en ms
        int32 geste = 0;      // prochain geste (bavards), en ms
        uint32 chemin = 0;    // marcheurs : trajet suivi, point atteint et sens
        int32 point = 0;
        int32 sens = 1;
        bool monte = false;   // marcheur en selle (compté avec les cavaliers)
    };

    // Un lieu animé. La liste est remplie au démarrage puis ne change plus : chaque carte n'est mise à jour que par un
    // fil à la fois et ne touche que ses propres lieux.
    struct Lieu
    {
        uint32 carte = 0, zone = 0;
        std::string nom;
        uint8 camp = 0;       // 0 Alliance, 1 Horde, 2 les deux
        float densite = 1.0f;
        std::vector<std::vector<G3D::Vector3>> chemins;   // trajets des patrouilles du lieu
        std::vector<Silhouette> silhouettes;
        uint32 attente = 0;
        uint32 absence = 0;
    };

    std::vector<Lieu> lieux;

    uint32 Selon(Lieu const& lieu, uint32 nombre)
    {
        return uint32(nombre * lieu.densite + 0.5f);
    }

    uint32 Cible(Lieu const& lieu)
    {
        std::tm t = Acore::Time::TimeBreakdown(time(nullptr));
        if (t.tm_hour >= 18)
            return Selon(lieu, reglages.soir);
        if (t.tm_hour >= 8)
            return Selon(lieu, reglages.jour);
        return Selon(lieu, reglages.nuit);
    }

    float Distance2D(G3D::Vector3 const& p, Player const* player)
    {
        float dx = p.x - player->GetPositionX(), dy = p.y - player->GetPositionY();
        return std::sqrt(dx * dx + dy * dy);
    }

    // Point de trajet entre 40 et 130 m d'un joueur (au hasard), ou faux après 15 essais.
    bool ChoisirPoint(Lieu const& lieu, std::vector<Player*> const& joueurs, uint32& chemin, int32& point)
    {
        for (uint8 essai = 0; essai < 15; ++essai)
        {
            chemin = urand(0, lieu.chemins.size() - 1);
            point = urand(0, lieu.chemins[chemin].size() - 1);
            float d = Distance2D(lieu.chemins[chemin][point], Acore::Containers::SelectRandomContainerElement(joueurs));
            if (d >= 40.0f && d <= 130.0f)
                return true;
        }
        return false;
    }

    // Apparences du camp du lieu ; dans une ville des deux camps, un camp au hasard.
    std::vector<uint32> const& Apparences(Lieu const& lieu)
    {
        uint8 camp = lieu.camp < 2 ? lieu.camp : uint8(urand(0, 1));
        return apparences[camp].empty() ? apparences[0] : apparences[camp];
    }

    Creature* Habiller(Map* map, Lieu const& lieu, Position const& position, int32 duree)
    {
        TempSummon* c = map->SummonCreature(SILHOUETTE, position, nullptr, duree + 5000);
        if (!c)
            return nullptr;
        uint32 apparence = Acore::Containers::SelectRandomContainerElement(Apparences(lieu));
        c->SetDisplayId(apparence);
        c->SetNativeDisplayId(apparence);
        if (!armes.empty() && urand(0, 1))
        {
            Armes const& a = Acore::Containers::SelectRandomContainerElement(armes);
            c->SetVirtualItem(0, a.droite);
            c->SetVirtualItem(1, a.gauche);
            c->SetVirtualItem(2, a.distance);
        }
        else
            for (uint8 emplacement = 0; emplacement < 3; ++emplacement)
                c->SetVirtualItem(emplacement, 0);
        c->SetWalk(true);
        return c;
    }

    bool Dehors(Map* map, G3D::Vector3 const& p)
    {
        PositionFullTerrainStatus etat;
        map->GetFullTerrainStatusForPosition(PHASEMASK_NORMAL, p.x, p.y, p.z, 2.0f, etat);
        return etat.outdoors;
    }

    // Lance un marcheur sur 8 à 15 points de son trajet ; faux au bout du trajet. Un cavalier s'arrête avant le premier
    // point en intérieur, puis fait demi-tour : il entrait à cheval dans les bâtiments (retour de l'utilisateur, 29/10/2026).
    bool Marcher(Lieu const& lieu, Creature* c, Silhouette& s)
    {
        std::vector<G3D::Vector3> const& trajet = lieu.chemins[s.chemin];
        Movement::PointsArray points;
        points.emplace_back(c->GetPositionX(), c->GetPositionY(), c->GetPositionZ());
        int32 etapes = urand(8, 15);
        for (int32 i = 1; i <= etapes; ++i)
        {
            int32 suivant = s.point + s.sens;
            if (suivant < 0 || suivant >= int32(trajet.size()))
                break;
            if (s.monte && !Dehors(c->GetMap(), trajet[suivant]))
                break;
            s.point = suivant;
            points.push_back(trajet[s.point]);
        }
        if (points.size() < 2)
            return false;
        c->GetMotionMaster()->MoveSplinePath(&points);
        return true;
    }

    void FairePopulation(Map* map, Lieu& endroit, std::vector<Player*> const& joueurs, uint32 manque)
    {
        if (endroit.chemins.empty() || apparences[0].empty())
            return;
        uint32 chemin;
        int32 point;
        if (!ChoisirPoint(endroit, joueurs, chemin, point))
            return;
        G3D::Vector3 const& lieu = endroit.chemins[chemin][point];

        // Neuf fois sur dix un passant (environ 3 silhouettes sur 4 bougent) ; sinon un groupe de 2 à 4.
        if (manque < 2 || urand(0, 9))
        {
            Silhouette s{ ObjectGuid::Empty, MARCHEUR, int32(urand(3, 6) * MINUTE * IN_MILLISECONDS) };
            s.chemin = chemin;
            s.point = point;
            s.sens = urand(0, 1) ? 1 : -1;
            if (Creature* c = Habiller(map, endroit, Position(lieu.x, lieu.y, lieu.z, frand(0.0f, 2 * float(M_PI))), s.restant))
            {
                s.guid = c->GetGUID();
                if (urand(0, 99) < 60)   // six passants sur dix courent
                    c->SetWalk(false);
                Marcher(endroit, c, s);
                endroit.silhouettes.push_back(s);
            }
            return;
        }

        uint32 nombre = std::min<uint32>(manque, urand(2, 4));
        bool assis = urand(0, 4) == 0;
        int32 duree = int32(urand(2, 6) * MINUTE * IN_MILLISECONDS);
        float depart = frand(0.0f, 2 * float(M_PI));
        for (uint32 i = 0; i < nombre; ++i)
        {
            float angle = depart + 2 * float(M_PI) * i / nombre;
            float rayon = frand(1.2f, 1.8f);
            float x = lieu.x + rayon * std::cos(angle), y = lieu.y + rayon * std::sin(angle);
            float sol = map->GetHeight(PHASEMASK_NORMAL, x, y, lieu.z + 2.0f);
            Position position(x, y, std::fabs(sol - lieu.z) < 3.0f ? sol : lieu.z,
                Position::NormalizeOrientation(angle + float(M_PI)));   // face au centre du groupe
            Creature* c = Habiller(map, endroit, position, duree);
            if (!c)
                continue;
            c->SetFacingTo(position.GetOrientation());
            if (assis)
                c->SetStandState(UNIT_STAND_STATE_SIT);
            Silhouette s{ c->GetGUID(), BAVARD, duree };
            s.geste = int32(urand(1000, 8000));
            endroit.silhouettes.push_back(s);
        }
    }

    // Un cavalier, à l'extérieur seulement : mobile sur le trajet, ou immobile à 2-5 m.
    void PlacerCavalier(Map* map, Lieu& endroit, std::vector<Player*> const& joueurs, bool mobile)
    {
        if (endroit.chemins.empty() || apparences[0].empty() || montures.empty())
            return;
        uint32 chemin;
        int32 point;
        if (!ChoisirPoint(endroit, joueurs, chemin, point))
            return;
        G3D::Vector3 const& lieu = endroit.chemins[chemin][point];
        float angle = frand(0.0f, 2 * float(M_PI)), ecart = mobile ? 0.0f : frand(2.0f, 5.0f);
        float x = lieu.x + ecart * std::cos(angle), y = lieu.y + ecart * std::sin(angle);
        float sol = map->GetHeight(PHASEMASK_NORMAL, x, y, lieu.z + 2.0f);
        if (std::fabs(sol - lieu.z) >= 3.0f)
            return;
        int32 duree = int32(urand(3, 8) * MINUTE * IN_MILLISECONDS);
        Creature* c = Habiller(map, endroit, Position(x, y, sol, frand(0.0f, 2 * float(M_PI))), duree);
        if (!c)
            return;
        if (!c->IsOutdoors())
        {
            c->DespawnOrUnsummon();
            return;
        }
        c->Mount(Acore::Containers::SelectRandomContainerElement(montures));
        if (!mobile)
        {
            endroit.silhouettes.push_back({ c->GetGUID(), CAVALIER, duree });
            return;
        }
        // Au galop une fois sur deux, à la vitesse d'une monture épique (2 fois la course à pied).
        if (urand(0, 1))
        {
            c->SetWalk(false);
            c->SetSpeed(MOVE_RUN, 2.0f);
        }
        Silhouette m{ c->GetGUID(), MARCHEUR, duree };
        m.chemin = chemin;
        m.point = point;
        m.sens = urand(0, 1) ? 1 : -1;
        m.monte = true;
        Marcher(endroit, c, m);
        endroit.silhouettes.push_back(m);
    }

    void ToutRetirer(Map* map, Lieu& lieu)
    {
        for (Silhouette const& s : lieu.silhouettes)
            if (Creature* c = map->GetCreature(s.guid))
                c->DespawnOrUnsummon();
        lieu.silhouettes.clear();
    }

    void Animer(Map* map, Lieu& lieu, uint32 ecoule)
    {
        lieu.attente += ecoule;
        if (lieu.attente < IN_MILLISECONDS)
            return;
        uint32 pas = lieu.attente;
        lieu.attente = 0;

        std::vector<Player*> joueurs;
        for (auto const& ref : map->GetPlayers())
            if (Player* player = ref.GetSource(); player && player->IsInWorld() && player->GetZoneId() == lieu.zone)
                joueurs.push_back(player);

        std::vector<Silhouette>& silhouettes = lieu.silhouettes;
        if (joueurs.empty())
        {
            lieu.absence += pas;
            if (lieu.absence >= 30 * IN_MILLISECONDS && !silhouettes.empty())
                ToutRetirer(map, lieu);
            return;
        }
        lieu.absence = 0;

        // Vie des silhouettes : disparues, trop loin, au bout de leur temps ; gestes et marche.
        for (auto it = silhouettes.begin(); it != silhouettes.end();)
        {
            Silhouette& s = *it;
            Creature* c = map->GetCreature(s.guid);
            s.restant -= int32(pas);
            bool loin = c && std::all_of(joueurs.begin(), joueurs.end(), [&](Player* p) { return c->GetExactDist2d(p) > 170.0f; });
            if (!c || !c->IsInWorld() || s.restant <= 0 || loin)
            {
                if (c)
                    c->DespawnOrUnsummon();
                it = silhouettes.erase(it);
                continue;
            }
            if (s.role == BAVARD)
            {
                s.geste -= int32(pas);
                if (s.geste <= 0)
                {
                    if (c->IsStandState())
                        c->HandleEmoteCommand(Acore::Containers::SelectRandomContainerElement(GESTES));
                    s.geste = int32(urand(4000, 9000));
                }
            }
            else if (s.role == MARCHEUR && c->movespline->Finalized() && !Marcher(lieu, c, s))
            {
                // Bout du trajet : demi-tour.
                s.sens = -s.sens;
                Marcher(lieu, c, s);
            }
            ++it;
        }

        // Population : jusqu'à 10 apparitions (marcheur ou groupe) par seconde vers le nombre voulu, une disparition par
        // seconde au-delà. Les cavaliers sont comptés à part (5 essais par seconde).
        auto Cavaliers = [&]() { return uint32(std::count_if(silhouettes.begin(), silhouettes.end(),
            [](Silhouette const& s) { return s.role == CAVALIER || s.monte; })); };
        auto Mobiles = [&]() { return uint32(std::count_if(silhouettes.begin(), silhouettes.end(),
            [](Silhouette const& s) { return s.monte; })); };
        uint32 cible = Cible(lieu);
        for (uint8 i = 0; i < 10 && silhouettes.size() - Cavaliers() < cible; ++i)
            FairePopulation(map, lieu, joueurs, cible - (silhouettes.size() - Cavaliers()));
        if (silhouettes.size() - Cavaliers() > cible)
        {
            auto it = std::find_if(silhouettes.begin(), silhouettes.end(), [](Silhouette const& s) { return s.role != CAVALIER && !s.monte; });
            if (Creature* c = map->GetCreature(it->guid))
                c->DespawnOrUnsummon();
            silhouettes.erase(it);
        }
        uint32 cavaliers = Selon(lieu, reglages.montures), mobiles = Selon(lieu, reglages.monturesMobiles);
        for (uint8 i = 0; i < 5 && Cavaliers() < cavaliers; ++i)
            PlacerCavalier(map, lieu, joueurs, Mobiles() < mobiles);
    }
}

class solazeroth_ambiance_carte : public AllMapScript
{
public:
    solazeroth_ambiance_carte() : AllMapScript("solazeroth_ambiance_carte", { ALLMAPHOOK_ON_MAP_UPDATE }) { }

    void OnMapUpdate(Map* map, uint32 ecoule) override
    {
        if (!reglages.actif)
            return;
        for (Lieu& lieu : lieux)
            if (lieu.carte == map->GetId())
                Animer(map, lieu, ecoule);
    }
};

class solazeroth_ambiance_monde : public WorldScript
{
public:
    solazeroth_ambiance_monde() : WorldScript("solazeroth_ambiance_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.actif = sConfigMgr->GetOption<bool>("SolAzeroth.Ambiance.Enable", true);
        reglages.soir = sConfigMgr->GetOption<uint32>("SolAzeroth.Ambiance.Soir", 80);
        reglages.jour = sConfigMgr->GetOption<uint32>("SolAzeroth.Ambiance.Jour", 30);
        reglages.nuit = sConfigMgr->GetOption<uint32>("SolAzeroth.Ambiance.Nuit", 10);
        reglages.montures = sConfigMgr->GetOption<uint32>("SolAzeroth.Ambiance.Montures", 40);
        reglages.monturesMobiles = sConfigMgr->GetOption<uint32>("SolAzeroth.Ambiance.MonturesMobiles", 25);
    }

    void OnStartup() override
    {
        if (QueryResult r = WorldDatabase.Query("SELECT display, camp FROM solazeroth_ambiance_apparences"))
            do
                if (uint8 camp = (*r)[1].Get<uint8>(); camp < 2)
                    apparences[camp].push_back((*r)[0].Get<uint32>());
            while (r->NextRow());
        if (QueryResult r = WorldDatabase.Query("SELECT display FROM solazeroth_ambiance_montures"))
            do
                montures.push_back((*r)[0].Get<uint32>());
            while (r->NextRow());
        if (QueryResult r = WorldDatabase.Query("SELECT main_droite, main_gauche, distance FROM solazeroth_ambiance_armes"))
            do
                armes.push_back({ (*r)[0].Get<uint32>(), (*r)[1].Get<uint32>(), (*r)[2].Get<uint32>() });
            while (r->NextRow());
        if (QueryResult r = WorldDatabase.Query("SELECT carte, zone, nom, camp, densite FROM solazeroth_ambiance_lieux"))
            do
            {
                Field* f = r->Fetch();
                Lieu lieu;
                lieu.carte = f[0].Get<uint32>();
                lieu.zone = f[1].Get<uint32>();
                lieu.nom = f[2].Get<std::string>();
                lieu.camp = f[3].Get<uint8>();
                lieu.densite = f[4].Get<float>();
                lieux.push_back(std::move(lieu));
            } while (r->NextRow());

        // Trajets des patrouilles et passants de chaque lieu (8 points au moins).
        uint32 trajets = 0;
        for (Lieu& lieu : lieux)
        {
            QueryResult r = WorldDatabase.Query(
                "SELECT w.id, w.position_x, w.position_y, w.position_z FROM waypoint_data w WHERE w.id IN ("
                "SELECT ca.path_id FROM creature c JOIN creature_addon ca ON ca.guid = c.guid "
                "WHERE c.map = {} AND c.zoneId = {} AND ca.path_id > 0) ORDER BY w.id, w.point", lieu.carte, lieu.zone);
            if (!r)
                continue;
            uint32 dernier = 0;
            std::vector<G3D::Vector3> trajet;
            auto Garder = [&]() { if (trajet.size() >= 8) lieu.chemins.push_back(trajet); trajet.clear(); };
            do
            {
                Field* f = r->Fetch();
                if (f[0].Get<uint32>() != dernier)
                {
                    Garder();
                    dernier = f[0].Get<uint32>();
                }
                trajet.emplace_back(f[1].Get<float>(), f[2].Get<float>(), f[3].Get<float>());
            } while (r->NextRow());
            Garder();
            trajets += lieu.chemins.size();
        }
        LOG_INFO("module", "Sol'Azeroth ambiance : {} apparences Alliance, {} Horde, {} jeux d'armes, {} montures, {} lieux, {} trajets",
            apparences[0].size(), apparences[1].size(), armes.size(), montures.size(), lieux.size(), trajets);
    }
};

void AddSC_solazeroth_ambiance()
{
    new solazeroth_ambiance_carte();
    new solazeroth_ambiance_monde();
}
