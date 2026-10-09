#!/bin/bash
# licenseservice (the license-check daemon) segfaults at random during server start.
# Its license-timer thread walks the session map in GLicenseServer::HeartBear() without
# a lock, while OnDelSession() erases from the same map when a daemon disconnects. At
# startup daemons connect and disconnect in quick succession, so the two races, the
# iterator dangles, and the process dies. Every licensed daemon then quits and the
# client shows "Соединение с сервером было разорвано".
#
# HeartBear() only force-closes timed-out license sessions, which never happens on an
# offline server (sessions exist only briefly at startup). Turning its first byte into
# a `ret` (0x55 push rbp -> 0xc3 ret) makes it a no-op, the timer thread stops touching
# the map, and the race is gone. Everything else in licenseservice is untouched.
#
# Offset 0x12a16 is both the virtual address and the file offset: the executable LOAD
# segment maps at off 0xd000 = vaddr 0xd000, so there is no bias in .text.
# Safe to run again: it checks the current byte and does nothing if already patched.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${1:-$ROOT/game/server/root/pwserver/licenseservice/licenseservice}"

OFFSET=76310        # 0x12a16, first byte of GLicenseServer::HeartBear()
ORIG_BYTE=55        # push %rbp
PATCHED_BYTE=c3     # ret

if [ ! -f "$BIN" ]; then
    echo "licenseservice not found at: $BIN"
    echo "Run setup first so the server archive is unpacked."
    exit 1
fi

cur="$(dd if="$BIN" bs=1 skip="$OFFSET" count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"

if [ "$cur" = "$PATCHED_BYTE" ]; then
    echo "licenseservice already patched."
    exit 0
fi

if [ "$cur" != "$ORIG_BYTE" ]; then
    echo "Unexpected byte 0x$cur at offset $OFFSET (expected 0x$ORIG_BYTE)."
    echo "This is a different licenseservice build; not patching."
    exit 1
fi

cp -n "$BIN" "$BIN.orig"
printf "\xc3" | dd of="$BIN" bs=1 seek="$OFFSET" count=1 conv=notrunc 2>/dev/null

new="$(dd if="$BIN" bs=1 skip="$OFFSET" count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"

if [ "$new" != "$PATCHED_BYTE" ]; then
    echo "Patch failed: byte is 0x$new, restoring original."
    cp "$BIN.orig" "$BIN"
    exit 1
fi

echo "licenseservice patched (startup crash fixed). Original kept as $BIN.orig"
