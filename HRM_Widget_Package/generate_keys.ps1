param(
    [int]$Count = 1,
    [string]$Tag = ""
)

$SecretSalt = "HRM_SPIDER_PRO_SECRET_SALT_2026_ACODEZ"

function Generate-Key([string]$customTag = "") {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    
    $seg1 = ""
    if ($customTag) {
        $seg1 = ($customTag.ToUpper() -replace "[^A-Z0-9]", "").PadRight(4, 'X').Substring(0, 4)
    } else {
        1..4 | ForEach-Object { $seg1 += $chars[(Get-Random -Maximum $chars.Length)] }
    }
    
    $seg2 = ""
    1..4 | ForEach-Object { $seg2 += $chars[(Get-Random -Maximum $chars.Length)] }
    
    $payload = "SPID-$seg1-$seg2"
    $toHash = [System.Text.Encoding]::UTF8.GetBytes("$payload::$SecretSalt")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash($toHash)).Replace("-", "")
    
    $c1 = $hash.Substring(0, 4)
    $c2 = $hash.Substring(4, 4)
    
    return "$payload-$c1-$c2"
}

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "    HRM WIDGET - SPIDER-MAN V2 LICENSE GENERATOR" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

for ($i = 1; $i -le $Count; $i++) {
    $k = Generate-Key $Tag
    Write-Host "[$i] $k" -ForegroundColor Green
}

Write-Host "=======================================================" -ForegroundColor Cyan
