#!/bin/bash
# Unpacks the server and client archives the user downloaded into game/
# and applies the client-side fixes. Safe to run again.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GAME="$ROOT/game"
SERVER_ARCHIVE="${1:-$GAME/PWServer176.7z}"
CLIENT_ARCHIVE="${2:-$GAME/PerfectWorld-176.7z}"
PATCH_ARCHIVE="$GAME/Patch-client-1.7.6-ru.7z"
CLIENT_DIR="$GAME/client/PerfectWorld-176"
SERVERLIST="$CLIENT_DIR/game_info/data/patcher/server/serverlist.txt"

SEVENZIP="$(command -v 7zz || command -v 7z || true)"

if [ -z "$SEVENZIP" ]; then
    echo "7-Zip not found. Install it with: brew install sevenzip"
    exit 1
fi

for archive in "$SERVER_ARCHIVE" "$CLIENT_ARCHIVE"; do
    if [ ! -f "$archive" ]; then
        echo "Missing $archive"
        echo "Download it as described in README.md and put it into $GAME/"
        exit 1
    fi
done

# The server archive is meant to be unpacked into / of a Linux box. The container
# mounts only root/ (server, SQL dumps, control scripts) and home/ (license client
# config), the few MB of other files next to them are left unused.
echo "Unpacking server (about 7 GB)..."
mkdir -p "$GAME/server" "$GAME/mysql"
"$SEVENZIP" x "$SERVER_ARCHIVE" -o"$GAME/server" -aoa -bso0 -bsp0

echo "Unpacking client (about 27 GB)..."
mkdir -p "$GAME/client"
"$SEVENZIP" x "$CLIENT_ARCHIVE" -o"$GAME/client" -aoa -bso0 -bsp0

# The client from the release is already patched. Apply the patch only if the user
# brought a different client and put the patch next to it.
if [ -f "$PATCH_ARCHIVE" ]; then
    echo "Applying client patch..."
    TMP="$(mktemp -d)"
    "$SEVENZIP" x "$PATCH_ARCHIVE" -o"$TMP" -aoa -bso0 -bsp0
    cp -R "$TMP"/Patch-client-1.7.6-ru/element/ "$CLIENT_DIR/game_info/data/element/"
    rm -rf "$TMP"
fi

# serverlist.txt must stay UTF-16 LE with a BOM and CRLF, otherwise the client ignores it.
# The shipped one points at the release author's VirtualBox IP (192.168.0.195).
echo "Pointing the client at 127.0.0.1..."
printf '\xff\xfe' > "$SERVERLIST"
printf 'RUPW\r\nServerPW\t29000:127.0.0.1\t2\r\n' | iconv -f UTF-8 -t UTF-16LE >> "$SERVERLIST"

echo
echo "Done. Next steps:"
echo "  1. docker compose up -d"
echo "  2. scripts/macos/create-account.sh <login> <password>"
echo "  3. scripts/macos/crossover-bottle.sh   (after creating the CrossOver bottle)"
echo "  4. Run $CLIENT_DIR/game_info/data/element/elementclient.exe in CrossOver"
echo "     with arguments: game:cpw nocheck startbypatcher console:1"
