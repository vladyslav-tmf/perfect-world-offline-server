# Unpacks the server and client archives the user downloaded into game\
# and applies the client-side fixes. Safe to run again.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\windows\setup.ps1

param(
    [string]$ServerArchive,
    [string]$ClientArchive
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\.."
$Game = Join-Path $Root "game"

if (-not $ServerArchive) { $ServerArchive = Join-Path $Game "PWServer176.7z" }
if (-not $ClientArchive) { $ClientArchive = Join-Path $Game "PerfectWorld-176.7z" }

$PatchArchive = Join-Path $Game "Patch-client-1.7.6-ru.7z"
$ClientDir = Join-Path $Game "client\PerfectWorld-176"
$ServerList = Join-Path $ClientDir "game_info\data\patcher\server\serverlist.txt"

$SevenZip = @(
    (Get-Command 7z -ErrorAction SilentlyContinue).Source,
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $SevenZip) {
    Write-Error "7-Zip not found. Install it from https://www.7-zip.org/"
}

foreach ($Archive in @($ServerArchive, $ClientArchive)) {
    if (-not (Test-Path $Archive)) {
        Write-Error "Missing $Archive. Download it as described in README.md and put it into $Game\"
    }
}

# The server archive is meant to be unpacked into / of a Linux box. The container
# mounts only root/ (server, SQL dumps, control scripts) and home/ (license client
# config), the few MB of other files next to them are left unused.
Write-Host "Unpacking server (about 7 GB)..."
New-Item -ItemType Directory -Force -Path (Join-Path $Game "server"), (Join-Path $Game "mysql") | Out-Null
& $SevenZip x $ServerArchive "-o$(Join-Path $Game 'server')" -aoa -bso0 -bsp0

Write-Host "Unpacking client (about 27 GB)..."
New-Item -ItemType Directory -Force -Path (Join-Path $Game "client") | Out-Null
& $SevenZip x $ClientArchive "-o$(Join-Path $Game 'client')" -aoa -bso0 -bsp0

# The client from the release is already patched. Apply the patch only if the user
# brought a different client and put the patch next to it.
if (Test-Path $PatchArchive) {
    Write-Host "Applying client patch..."
    $Tmp = Join-Path $env:TEMP "pw-patch"
    & $SevenZip x $PatchArchive "-o$Tmp" -aoa -bso0 -bsp0
    Copy-Item -Recurse -Force "$Tmp\Patch-client-1.7.6-ru\element\*" (Join-Path $ClientDir "game_info\data\element")
    Remove-Item -Recurse -Force $Tmp
}

# serverlist.txt must stay UTF-16 LE with a BOM and CRLF, otherwise the client ignores it.
# The shipped one points at the release author's VirtualBox IP (192.168.0.195).
Write-Host "Pointing the client at 127.0.0.1..."
[System.IO.File]::WriteAllText($ServerList, "RUPW`r`nServerPW`t29000:127.0.0.1`t2`r`n", [System.Text.Encoding]::Unicode)

Write-Host ""
Write-Host "Done. Next steps:"
Write-Host "  1. docker compose up -d"
Write-Host "  2. scripts\windows\create-account.ps1 <login> <password>"
Write-Host "  3. Run $ClientDir\game_info\data\element\elementclient.exe"
Write-Host "     with arguments: game:cpw nocheck startbypatcher console:1"
