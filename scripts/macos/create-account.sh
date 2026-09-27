#!/bin/bash
# Creates a game account with GM rights on the running server.
# Usage: create-account.sh <login> <password>
set -euo pipefail

LOGIN="${1:-}"
PASS="${2:-}"

if [ -z "$LOGIN" ] || [ -z "$PASS" ]; then
    echo "Usage: $0 <login> <password>"
    exit 1
fi

# Both values go into SQL, so allow only characters the game client accepts anyway
if [[ ! "$LOGIN" =~ ^[A-Za-z0-9_]{3,32}$ ]] || [[ ! "$PASS" =~ ^[A-Za-z0-9_]{3,32}$ ]]; then
    echo "Login and password: 3-32 characters, letters, digits and _ only"
    exit 1
fi

SQL="docker exec pw-server mariadb -N -uroot -p123456 pw176 -e"

# gauthd is configured with hash = 3, which means base64(md5(login + password))
HASH="TO_BASE64(UNHEX(MD5(CONCAT('$LOGIN','$PASS'))))"

$SQL "CALL adduser('$LOGIN', $HASH, '', '', '', '', '', '', '', '', '', '', '', 0, '', '', $HASH);"

USER_ID="$($SQL "SELECT ID FROM users WHERE name='$LOGIN';")"
PRIVS="$($SQL "SELECT COUNT(*) FROM auth WHERE userid=$USER_ID;")"

if [ "$PRIVS" = "0" ]; then
    $SQL "CALL addGM($USER_ID, 1);"
fi

echo "Account $LOGIN created (ID $USER_ID) with GM rights."
