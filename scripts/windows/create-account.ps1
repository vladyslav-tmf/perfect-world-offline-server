# Creates a game account with GM rights on the running server.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\windows\create-account.ps1 <login> <password>

param(
    [Parameter(Mandatory = $true)][string]$Login,
    [Parameter(Mandatory = $true)][string]$Password
)

$ErrorActionPreference = "Stop"

# Both values go into SQL, so allow only characters the game client accepts anyway
if ($Login -notmatch '^[A-Za-z0-9_]{3,32}$' -or $Password -notmatch '^[A-Za-z0-9_]{3,32}$') {
    Write-Error "Login and password: 3-32 characters, letters, digits and _ only"
}

function Invoke-Sql([string]$Query) {
    docker exec pw-server mariadb -N -uroot -p123456 pw176 -e $Query
}

# gauthd is configured with hash = 3, which means base64(md5(login + password))
$Hash = "TO_BASE64(UNHEX(MD5(CONCAT('$Login','$Password'))))"

Invoke-Sql "CALL adduser('$Login', $Hash, '', '', '', '', '', '', '', '', '', '', '', 0, '', '', $Hash);"

$UserId = Invoke-Sql "SELECT ID FROM users WHERE name='$Login';"
$Privs = Invoke-Sql "SELECT COUNT(*) FROM auth WHERE userid=$UserId;"

if ($Privs -eq "0") {
    Invoke-Sql "CALL addGM($UserId, 1);"
}

Write-Host "Account $Login created (ID $UserId) with GM rights."
