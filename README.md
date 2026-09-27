# Perfect World Offline Server

**English** | [Українська](README.uk.md) | [Русский](README.ru.md)

Play Perfect World 1.7.6, the newest version the community has, offline on your own computer. The server runs in Docker, the client runs on the same machine, and the fixes this server needs to start at all are already applied.

| | Status |
|---|---|
| macOS on Apple Silicon (M1-M4) | Tested. Server through Rosetta, client through CrossOver |
| Windows (x64) | Not tested yet. Should work with Docker Desktop and the native client |
| Linux (x64) | Not tested yet. The server part is the same, the client runs in Wine |
| Russian client (1.7.6 build 4311) | Tested |
| English client | Not supported yet, see [Language](#language) |

The repository holds scripts, configuration and documentation only. There are no game files in it, you download the server and the client yourself.

## Contents

- [How it works](#how-it-works)
- [Requirements](#requirements)
- [1. Get the game files](#1-get-the-game-files)
- [2. Set up the server and the client](#2-set-up-the-server-and-the-client)
- [3. Play](#3-play)
- [Everyday use](#everyday-use)
- [What was fixed](#what-was-fixed)
- [Troubleshooting](#troubleshooting)
- [Language](#language)
- [Disclaimer](#disclaimer)
- [Support the project](#support-the-project)

## How it works

```
your computer
├── Docker container "pw-server" (Debian 12, x86-64)
│   ├── MariaDB (accounts, license)
│   └── 10 PW daemons + the game world, listening on 127.0.0.1:29000
└── PW client (Windows app, native or in CrossOver/Wine)
```

All game data (server files, database, client) lives in the `game/` folder of this repository. It is ignored by git.

## Requirements

- 16 GB of RAM. The game world takes about 3 GB and the client another 2-3 GB.
- About 75 GB of free disk space: 30 GB of downloads, 35 GB after unpacking, plus the database.
- 7-Zip. On macOS `brew install sevenzip`, on Windows from [7-zip.org](https://www.7-zip.org/).
- Docker. On macOS [OrbStack](https://orbstack.dev/) (what I tested with) or Docker Desktop with Rosetta turned on. On Windows [Docker Desktop](https://www.docker.com/products/docker-desktop/) with WSL 2.
- On macOS also [CrossOver](https://www.codeweavers.com/crossover), to run the Windows client.

## 1. Get the game files

Download these files and put them into the `game/` folder (create it next to this README):

| File | Size | What it is |
|---|---|---|
| `PWServer176.7z` | 2.2 GB | Server 1.7.6 build 4311 with SQL dumps and control scripts |
| `PerfectWorld-176.7z` | 25.5 GB | Russian client 1.7.6 build 4311, already patched for this server |
| `Patch-client-1.7.6-ru.7z` | 22 MB | Optional. Only needed if you use a different, unpatched 1.7.6 build 4311 client |

The server and the patch are linked on Google Drive from the release author's manual "Установка PW v1.7.6 Build 4311 сервера, IWEB, PWAdmin". The site that hosted it is down, but the [Web Archive copy](https://web.archive.org/web/20260512052954/https://www.habrhub.ru/Servers/PerfectWorld/PW-v176+IWEB+PWAdmin/pw-v176+iweb+pwadmin) still has the links.

The client comes from the RuTracker release "Perfect World + Server v1.7.6 Build 4311 [amd64] [RUS] [Wine]". Select only `PerfectWorld-176.7z` in your torrent client. The other file in that release, `PWSERVER-1.7.6.7z`, is a VirtualBox image of the same server and you don't need it.

The RaGEZONE thread "1.7.6 server + client" in Perfect World Releases has more background and mirrors.

The result should look like this:

```
perfect-world-offline-server/
└── game/
    ├── PWServer176.7z
    └── PerfectWorld-176.7z
```

## 2. Set up the server and the client

### macOS

```bash
scripts/macos/setup.sh                     # unpacks everything into game/ (takes a while)
docker compose up -d --build               # first start imports the database, about a minute
scripts/macos/create-account.sh admin admin
```

Then set up CrossOver:

1. **Bottle → New Bottle**, name `Perfect World`, type **Windows 10 64-bit**.
2. In that bottle **Install Software** and install:
   - **Microsoft DirectX for Modern Games**
   - **Microsoft Visual C++ 2005 SP1, 2008, 2010 Redistributable**, the 32-bit versions without "(64-bit)"
   - **Nvidia PhysX Legacy (2012)**, optional
3. Apply the icon fix to the bottle:

   ```bash
   scripts/macos/crossover-bottle.sh "Perfect World"
   ```

### Windows (not tested yet)

In PowerShell, from the repository folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1
docker compose up -d --build
powershell -ExecutionPolicy Bypass -File scripts\windows\create-account.ps1 admin admin
```

If the client asks for missing libraries, install [DirectX End-User Runtime (June 2010)](https://www.microsoft.com/download/details.aspx?id=8109) and the 32-bit Visual C++ 2005/2008/2010 Redistributables.

### Linux (not tested yet)

Run the server the same way as on macOS (`docker compose up -d --build`). The account script works as is. The client is a Wine build, the release itself ships a Wine launcher (`start.sh`). Point `serverlist.txt` at `127.0.0.1` as `setup.sh` does.

## 3. Play

Start the 32-bit client with these arguments:

```
game\element\elementclient.exe game:cpw nocheck startbypatcher console:1
```

The full path is `game/client/PerfectWorld-176/game_info/data/element/elementclient.exe`.

On macOS open the `Perfect World` bottle in CrossOver, click Run Command, pick the file, add the arguments and tick "Save command as a launcher" so you don't have to do it again. On Windows make a shortcut to `elementclient.exe` and put the arguments at the end of its target.

Log in with the account you created, for example `admin` / `admin`. The server shows up as ServerPW, and the account has GM rights.

The 64-bit client (`element\x64\elementclient_64.exe`) doesn't start in CrossOver. It might on Windows, I haven't tried.

## Everyday use

| Action | Command |
|---|---|
| Start the server | `docker compose up -d` (ready in about a minute) |
| Stop the server | `docker compose stop` |
| Server logs | `docker logs -f pw-server` |
| Status of all daemons | `docker exec pw-server /root/server status` |
| Create another account | `scripts/macos/create-account.sh <login> <password>` |

Always stop the server with `docker compose stop`. It shuts the game down and then MariaDB, so nothing gets lost. Do not kill Docker or unplug the drive while the server is running.

By default only the main world (`gs01`) and one instance (`is61`) are started to save memory. More maps: `docker exec pw-server /root/server start-map <map id>`, the list of ids is in `game/server/root/pwserver/maps`.

## What was fixed

Out of the box this server doesn't start, or starts and breaks in the client. These are the reasons, all handled by the container and the scripts:

| Problem | Symptom | Fix |
|---|---|---|
| License end date 2090, but `UNIX_TIMESTAMP()` in MariaDB 10.11 stops at 2038 | `licenseservice.log`: *license time out*, all daemons quit, "server stops at 30%" | `entrypoint.sh` sets the date to 2037-12-31 on every start |
| Daemons send `SIGUSR1` to their parent on startup | The control script dies after the first daemon, the rest never start | The control script runs inside a bash that traps `USR1` |
| `docker stop` killed MariaDB without a clean shutdown | Container exit code 137, risk of database corruption | `SIGTERM` trap: `server stop`, then `mariadb-admin shutdown` |
| `serverlist.txt` points at the author's VirtualBox IP `192.168.0.195` | Client cannot find the server | Rewritten with `127.0.0.1`, keeping UTF-16 LE with BOM |
| Pack files use Chinese (GBK) file names | In CrossOver/Wine: `?` instead of item and skill icons, missing effects | Bottle runs with `LANG=zh_CN.UTF-8`, the game text stays Russian |
| Server binaries are x86-64 | Do not run on Apple Silicon natively | `platform: linux/amd64`, Rosetta runs them |

## Troubleshooting

**Client says the version is wrong.** Server and client must be the same build (4311) with the same `elements.data` and `tasks.data`. Use the client from the release above or apply `Patch-client-1.7.6-ru.7z`.

**`?` instead of icons (macOS).** Run `scripts/macos/crossover-bottle.sh`, then quit CrossOver completely and start the game again.

**Server does not start.** Check `docker logs pw-server` and `game/server/root/pwserver/logs/licenseservice.log`. If it says *license time out*, the license date fix did not apply, check that the `licenseservice` database exists.

**Want to start over.** `docker compose down`, then delete `game/mysql`. The next start imports a fresh database. All characters are lost.

## Language

Only the Russian client is supported. The server files, `elements.data` (items, NPCs) and `tasks.data` (quests) are the Russian 1.7.6 build 4311 versions. The English client (PWI 1.7.6 build 4727-pwi-1292) has different data and a different client version: users on RaGEZONE report a version error at login with exactly this server.

English support needs an English 1.7.6 server build with matching data. If you have a working English server + client pair, contributions are welcome. The Docker part and all fixes stay the same.

## Disclaimer

Perfect World is a trademark of Perfect World Entertainment and its licensors. This project is not affiliated with them. The repository contains no game code or assets, only scripts written for this project. It is meant for playing offline, for education and for preservation of a game version that is no longer available. Do not use it to run a public or commercial server.

## Support the project

Getting this to run took a lot of trial and error. If it saved you that, you can chip in:

[![Donate via Monobank](https://img.shields.io/badge/Donate-Monobank-000000?style=for-the-badge)](https://send.monobank.ua/jar/4KTyhPctPn)

Or send to the card directly: `4874 1000 3356 1112`
