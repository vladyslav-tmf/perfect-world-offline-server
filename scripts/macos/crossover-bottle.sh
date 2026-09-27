#!/bin/bash
# Fixes the "?" icons in CrossOver: PW packs store file names in GBK (codepage 936),
# and the client finds them only under a Chinese locale. The game text stays Russian
# because the UI strings are Unicode.
# Usage: crossover-bottle.sh ["Bottle Name"]   (default: "Perfect World")
set -euo pipefail

BOTTLE="${1:-Perfect World}"
CONF="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE/cxbottle.conf"

if [ ! -f "$CONF" ]; then
    echo "Bottle \"$BOTTLE\" not found. Create it in CrossOver first (Windows 10 64-bit)."
    exit 1
fi

if grep -q '^"LANG"' "$CONF"; then
    echo "Bottle \"$BOTTLE\" already has LANG set, nothing to do."
    exit 0
fi

# [EnvironmentVariables] is the last section of a CrossOver bottle config,
# so appending puts the variables inside it
cat >> "$CONF" <<'EOF'
;; PW packs store file names in GBK (codepage 936), a Chinese locale lets the client find them
"LANG" = "zh_CN.UTF-8"
"LC_ALL" = "zh_CN.UTF-8"
EOF

echo "Done. Quit CrossOver completely and start the game again."
