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

param(
    [string]$Binary
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\.."
if (-not $Binary) {
    $Binary = Join-Path $Root "game\server\root\pwserver\licenseservice\licenseservice"
}

$Offset = 0x12a16       # first byte of GLicenseServer::HeartBear()
$OrigByte = 0x55        # push %rbp
$PatchedByte = 0xc3     # ret

if (-not (Test-Path $Binary)) {
    Write-Error "licenseservice not found at: $Binary`nRun setup first so the server archive is unpacked."
}

$bytes = [System.IO.File]::ReadAllBytes($Binary)
$cur = $bytes[$Offset]

if ($cur -eq $PatchedByte) {
    Write-Host "licenseservice already patched."
    return
}

if ($cur -ne $OrigByte) {
    Write-Error ("Unexpected byte 0x{0:x2} at offset {1} (expected 0x{2:x2}). This is a different licenseservice build; not patching." -f $cur, $Offset, $OrigByte)
}

if (-not (Test-Path "$Binary.orig")) {
    Copy-Item $Binary "$Binary.orig"
}

$bytes[$Offset] = $PatchedByte
[System.IO.File]::WriteAllBytes($Binary, $bytes)

$check = [System.IO.File]::ReadAllBytes($Binary)[$Offset]
if ($check -ne $PatchedByte) {
    Copy-Item "$Binary.orig" $Binary -Force
    Write-Error ("Patch failed: byte is 0x{0:x2}, restored original." -f $check)
}

Write-Host "licenseservice patched (startup crash fixed). Original kept as $Binary.orig"
