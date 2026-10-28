# Sol'Azeroth

**A 100 % solo, offline World of Warcraft: Wrath of the Lich King (3.3.5a) experience, built on [AzerothCore](https://www.azerothcore.org/).**

No bots, no group finder, no auction house: every dungeon and raid is tuned so one player can clear it, and a long-term progression (threat ranks, contracts, collections, three endings) replaces the MMO loop.

> 🇫🇷 The game texts (NPCs, menus, addons, messages) are **in French** for now, and so is the design document. A French version of this page is in [LISEZMOI.md](LISEZMOI.md).

> ⚠️ Work in progress. Several features are built but not yet tested in game; see `docs/` for the roadmap.

## Features

**Character and account**
- All races with all classes (mod-arac).
- Universal spellbook: buy spells, weapon and armor skills from other classes; every class gets the resources it needs (rage, energy, runic power…).
- Talents from another class: spend points in one tree of a second class.
- Five specializations per character, each with its own talents and glyphs.
- Professions shared across the account, account bonuses, account-wide bank.
- Leagues: Hardcore, Destiny and Legend modes.

**Dungeons and raids**
- Solo scaling of every dungeon and raid (mod-autobalance, tuned).
- **Threat rank** per account (rank 0 to 5+), with Fortified / Tyrannical, mechanic affixes and point-based affixes.
- Boss challenges with bonus rewards, choice of loot from dungeon bosses, bad-luck protection.
- Every Northrend raid studied boss by boss; mechanics that need a group are adapted for one player (Naxxramas, Ulduar, Trial of the Crusader, Icecrown Citadel). A strategy guide is in `docs/`.
- Gear gap: being under-geared or well-geared for a fight changes the damage you deal and take.

**Game loops**
- Daily contract board (hunts and dungeons) with an account reserve, zone bounties, a weekly theme.
- Outdoor challenge mode (harder open world for better rewards).
- A 16-chapter story chain to the Lich King, with credits for the "Story" ending.
- Codex, Renown, collection journal, 50 account achievements, travelers' Marks as currency, quartermasters.
- Ambient NPCs bringing Stormwind to life.

**Comfort**
- One-click launcher: MySQL → auth → world → client, automatic and manual backups, versioned SQL migrations with rollback.
- About twenty addons (bags, nameplates, spellbook, talents, contracts, collection journal…), gathered behind one minimap button. A unified, redesigned interface is in progress.

## What is in this repository

| Folder | Content |
| --- | --- |
| `modules/mod-solazeroth` | The C++ AzerothCore module (most of the gameplay) |
| `lua_scripts` | ALE (Lua) scripts |
| `sql/migrations` | Versioned database changes (`NNN_name.up.sql` / `.down.sql`) |
| `addons` | Client addons (copied into the client by the launcher) |
| `scripts` | Launcher, migrations, backups, server configuration (PowerShell) |
| `outils` | Python tools to read and write MPQ and DBC files and build the client patch |
| `patches` | Local fix for mod-challenge-modes |
| `docs` | Design document and solo raid guide (French) |

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

   Modules go in `azerothcore\modules\`. Apply `patches\mod-challenge-modes.patch` inside mod-challenge-modes (`git apply`). Link our module: `mklink /J C:\SolAzeroth\azerothcore\modules\mod-solazeroth C:\SolAzeroth\modules\mod-solazeroth`.
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
