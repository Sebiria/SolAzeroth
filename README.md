# Sol'Azeroth

**A 100 % solo, offline World of Warcraft: Wrath of the Lich King (3.3.5a) experience, built on [AzerothCore](https://www.azerothcore.org/).**

No bots, no group finder, no auction house. Since version 3, Sol'Azeroth is less a set of solo tweaks than a different game on the same world: no visible levels, no resources, no healer, and a progression measured in **power**.

**Few keys, demanding goals.** At most eight techniques and a camp, nothing more to press: the challenge is not in a rotation but in the objectives. Zones are reworked around a few hubs where their quests are gathered, and they take time: **Durotar alone asks for many hours** of quests, bounties, contracts, challenges, relics and crafting before you are ready for its dungeon.

> 🇫🇷 The game texts (NPCs, menus, interface, messages) are **in French** for now, and so is the design document. A French version of this page is in [LISEZMOI.md](LISEZMOI.md).

> ⚠️ Work in progress. The first zone, Durotar, and its dungeon are playable; many systems are built but not yet tested in game. The previous version (v2: universal spellbook, leagues, scaled raids…) is kept at the tag [`v2-final`](../../tree/v2-final).

## The idea

- **Hidden, fixed level.** Every character and every monster stays at level 80 behind the scenes; the player never sees a level. A monster keeps the strength of its original level, which becomes its **power**.
- **Power comes from gear.** A character's power is the average item level of what they wear, raised by upgrade ranks. Facing a monster stronger than you, your damage drops by 2 % per missing point.
- **Combat without resources.** No rage, mana or energy: four techniques on cooldowns at first, up to eight equipped as your power grows, and one identity passive per specialization. Every hit lands; armor is a flat reduction per hit; there is no threat, monsters only have you to hit.
- **Each zone stands on its own, and is reworked.** Its quests are rewritten and gathered around a few hubs; quests that send you to another zone are gone. A zone has its own story, side activities and dungeon, and a completion percentage. 60 % opens the dungeon; 100 % means you go in with the gear to be at ease.
- **Long zones.** Story quests are only half of a zone: the other half is bounties, daily contracts, places to clear, timed challenges, waves and hidden relics, and the gear to face them is crafted and ranked up from what you gather there.
- **Hard, but fair.** Healing comes only from the camp fire, a single upgradable potion and out-of-combat regeneration: no food, bandages or Blizzard potions. Every number is tuned by combat simulation.

## What you can play today

**Durotar (power 1 to 11)**
- A rewritten story of 30 quests, from the Valley of Trials to Razor Hill, Sen'jin, the Echo Isles and the Burning Blade, down into Ragefire Chasm.
- Side activities worth half the zone: places to clear (with reinforced chiefs), bounties, daily contracts, timed challenges with bronze, silver and gold medals, a wave trial with a record, and 16 hidden relics (a map that reveals them can be bought).
- **Ragefire Chasm**, open at 60 %: difficulties 1 to 5, a dungeon component (Ember of the Chasm) and 31 blue pieces to craft with it.

**Warrior tank**, the first specialization with a full kit: the **Bulwark** passive (part of every hit taken becomes a shield that techniques can spend) and its techniques.

## Systems

| System | In short |
| --- | --- |
| Gear | Crafting from collected materials, ranks 1 to 5 (+10 % each), disenchanting and enchanting, a reinvented jewelcrafting for ranks 4 and 5 |
| Collection | An unlimited, exhaustive inventory of every collectible (materials, components, relics), beside a 50-slot bag |
| Camp | Camp fire (rest buff, regeneration) and potion, both upgraded with shopping lists |
| Death and soul | Death sends you back to your hearthstone without loss, but costs soul points; a soul at zero ends the character |
| Adventurer rank | Account rank fed by everything you do: titles, faster hearthstone, mounts (from 60 % to 150 % speed), zone modes, dungeon difficulties |
| Dungeon reputation | Account reputation across all instances, unlocking passives to choose before each dungeon; outdoor passives too |
| Currency | Three, each with its role: Traveler's Marks (bounties, challenges, camp, mounts), gold (crafting, item ranks, repairs) and corpse shards (item ranks, soul) |

## Interface v3

The interface is rewritten **inside the game's own files** (FrameXML and GlueXML, shipped in the client patch), not as addons: this code keeps Blizzard's rights in combat. It brings its own character and target frames, quest log, tracker and dialogue window, map and minimap pins (quests, repeatable quests, bounties, relics), a zone tracker, and six notebooks that gather every window. Sources are in `interface-v3`; `outils/interface_v3.py` and `outils/construire_patch.py` build the patch.

## Balancing

Fights are logged on the server (`journaux/combat`), and the Python tools replay a logged character against any monster: `outils/simulation_combat.py` and the tools built on it (camp, dungeons, modes, soul, Ragefire Chasm, bounties). Calibration scripts write their own SQL migrations, so every number can be traced back to a simulation.

## What is in this repository

| Folder | Content |
| --- | --- |
| `modules/mod-solazeroth` | The C++ AzerothCore module: v3 systems (`v3_*.cpp`) and the v2 systems still in use |
| `interface-v3` | The rewritten game interface (FrameXML / GlueXML) |
| `sql/migrations` | Versioned database changes (`NNN_name.up.sql` / `.down.sql`) |
| `outils` | Python tools: quest, zone and item generators, combat simulations, MPQ / DBC reading and writing, client patch |
| `scripts` | Launcher, migrations, backups, server configuration (PowerShell) |
| `patches` | Local fixes: mod-challenge-modes, and v3 combat hooks added to the AzerothCore engine |
| `addons` | Client addons still copied into the game by the launcher (the v2 ones are removed) |
| `lua_scripts` | ALE (Lua) scripts |
| `docs` | Design documents (v3, and v2 for history) and the solo raid guide, in French |

Nothing from Blizzard is included: you need your own 3.3.5a client (build 12340).

## Installation (Windows)

The scripts expect everything in **`C:\SolAzeroth`**. Clone this repository there.

1. **Prerequisites** — follow the [AzerothCore Windows guide](https://www.azerothcore.org/wiki/windows-requirements): Visual Studio 2022 (C++ desktop), CMake, MySQL 8.4 (service named `MySQL84`), OpenSSL 3, Boost 1.81. Also install Git and Python 3, then `py -m pip install mpyq`.
2. **AzerothCore and modules** — clone into `C:\SolAzeroth\azerothcore` (versions this project was built with):

   | Repository | Commit |
   | --- | --- |
   | [azerothcore-wotlk](https://github.com/azerothcore/azerothcore-wotlk) | `e6d767b` |
   | [mod-ale](https://github.com/azerothcore/mod-ale) | `84b85cc` |
   | [mod-arac](https://github.com/azerothcore/mod-arac) | `3f605e0` |
   | [mod-autobalance](https://github.com/azerothcore/mod-autobalance) | `1d707cb` |
   | [mod-challenge-modes](https://github.com/ZhengPeiRu21/mod-challenge-modes) | `1930525` |
   | [mod-individual-xp](https://github.com/azerothcore/mod-individual-xp) | `503471f` |
   | [mod-transmog](https://github.com/azerothcore/mod-transmog) | `327753a` |

   Modules go in `azerothcore\modules\`. Apply `patches\mod-challenge-modes.patch` inside mod-challenge-modes and `patches\azerothcore-v3-combat.patch` inside azerothcore (`git apply`). Link our module: `mklink /J C:\SolAzeroth\azerothcore\modules\mod-solazeroth C:\SolAzeroth\modules\mod-solazeroth`.
3. **Build** — configure with CMake into `C:\SolAzeroth\build`, then build `RelWithDebInfo`.
4. **Client data** — extract dbc, maps, vmaps and mmaps from your client into `C:\SolAzeroth\data`, then copy the three DBC files from `mod-arac\patch-contents\DBFilesContent` into `C:\SolAzeroth\data\dbc`.
5. **Database** — create the AzerothCore databases as in the AzerothCore guide (the world server fills them on its first start). Copy `config\mysql-acore.cnf.example` to `config\mysql-acore.cnf` and put your MySQL login in it.
6. **Configuration** — run `powershell -NoProfile -File scripts\configurer.ps1`. It creates the `.conf` files and applies the Sol'Azeroth settings (database logins in `worldserver.conf` / `authserver.conf` stay yours to set).
7. **Client patch** — copy the same three mod-arac DBC files into `patch-client\fichiers\DBFilesClient`, then run `py outils\construire_patch.py`.
8. **Client path** — copy `config\client.txt.example` to `config\client.txt` and write the folder that contains your `Wow.exe`.
9. **Account** — start `build\bin\RelWithDebInfo\worldserver.exe` once, type `account create <name> <password>` and `account set gmlevel <name> 3 -1`, then `server shutdown 1`.
10. **Play** — double-click `Jouer.bat`. It applies the SQL migrations, starts everything, copies the addons and the patch into the client, and backs up your characters when you quit. `Restaurer.bat` restores the latest backup.

## Contributing

Forks, fixes and translations are welcome. The design document (`docs/`) explains every system and the decisions behind it.

## License

[GPL-2.0](LICENSE), like AzerothCore. World of Warcraft is a trademark of Blizzard Entertainment; this project is not affiliated with Blizzard and ships none of its files.
