# จัดระเบียบอนิเมชันผู้เล่น
# โครงสร้าง: animation/player/{job}/{gender}/{folder}/000.png, 001.png, ...
# รัน: powershell -ExecutionPolicy Bypass -File tools/migrate_player_animations.ps1

$ErrorActionPreference = "Stop"
$base = Join-Path $PSScriptRoot "..\animation\player"
$jobs = @("novice", "sword", "mage", "thief", "acolyte", "hunter")
$genders = @("male", "female")
$folders = @(
    "idle", "walk_side", "walk_down", "walk_down_right",
    "walk_up", "walk_upright", "attack", "hurt", "dying"
)

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
}

function Remove-Import($pngPath) {
    $import = "$pngPath.import"
    if (Test-Path $import) { Remove-Item -Force $import }
}

function Rename-ToIndexed($dir) {
    if (-not (Test-Path $dir)) { return 0 }
    $files = Get-ChildItem -Path $dir -Filter "*.png" | Where-Object { $_.Name -notmatch '^\d{3}\.png$' } | Sort-Object {
        if ($_.Name -match '(\d+)') { [int]$matches[1] } else { 0 }
    }
    if ($files.Count -eq 0) { return 0 }
    $i = 0
    foreach ($f in $files) {
        $tmp = Join-Path $dir ("__tmp_{0:D3}.png" -f $i)
        Move-Item -Force $f.FullName $tmp
        Remove-Import $f.FullName
        $i++
    }
    $existing = @(Get-ChildItem $dir -Filter "*.png" | Where-Object { $_.Name -match '^\d{3}\.png$' })
    $start = $existing.Count
    for ($j = 0; $j -lt $i; $j++) {
        $tmp = Join-Path $dir ("__tmp_{0:D3}.png" -f $j)
        $dst = Join-Path $dir ("{0:D3}.png" -f ($start + $j))
        Move-Item -Force $tmp $dst
    }
    return ($start + $i)
}

function Consolidate-LegacyIdle($gender) {
    $legacy = Join-Path $base "novice\$gender\PNG\PNG Sequences\Idle"
    $dest = Join-Path $base "novice\$gender\idle"
    if (-not (Test-Path $legacy)) { return }
    $legacyFiles = @(Get-ChildItem $legacy -Filter "*.png" -ErrorAction SilentlyContinue)
    if ($legacyFiles.Count -eq 0) { return }
    Ensure-Dir $dest
    $sorted = $legacyFiles | Sort-Object {
        if ($_.BaseName -match '^(\d+)$') { [int]$matches[1] } else { 0 }
    }
    $i = 0
    foreach ($f in $sorted) {
        $target = Join-Path $dest ("{0:D3}.png" -f $i)
        Move-Item -Force $f.FullName $target
        Remove-Import $f.FullName
        $i++
    }
    Write-Host "  idle: moved $i frames (novice/$gender)"
}

function Move-WalkDiagonal($gender) {
    $src = Join-Path $base "novice\$gender\walk"
    $dst = Join-Path $base "novice\$gender\walk_down_right"
    if (-not (Test-Path $src)) { return }
    Ensure-Dir $dst
    $files = Get-ChildItem -Path $src -Filter "frame_*.png" | Sort-Object {
        if ($_.Name -match 'frame_(\d+)') { [int]$matches[1] } else { 0 }
    }
    $start = @(Get-ChildItem $dst -Filter "*.png" -ErrorAction SilentlyContinue).Count
    $i = 0
    foreach ($f in $files) {
        $target = Join-Path $dst ("{0:D3}.png" -f ($start + $i))
        Move-Item -Force $f.FullName $target
        Remove-Import $f.FullName
        $i++
    }
    if ($i -gt 0) { Write-Host "  walk_down_right: moved $i frames (novice/$gender)" }
    if ((Get-ChildItem $src -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
        Remove-Item -Force -Recurse $src -ErrorAction SilentlyContinue
    }
}

function Remove-EmptyLegacy($path) {
    if (-not (Test-Path $path)) { return }
    Get-ChildItem $path -Recurse -File -Filter "*.import" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem $path -Recurse -Directory -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if ((Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
                Remove-Item -Force $_.FullName -ErrorAction SilentlyContinue
            }
        }
    if ((Get-ChildItem $path -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
        Remove-Item -Force -Recurse $path -ErrorAction SilentlyContinue
    }
}

Write-Host "=== Player animation migration ==="

foreach ($gender in $genders) {
    Write-Host "novice/$gender"
    Consolidate-LegacyIdle $gender
    Move-WalkDiagonal $gender
}

foreach ($job in $jobs) {
    foreach ($gender in $genders) {
        $root = Join-Path $base "$job\$gender"
        foreach ($folder in $folders) {
            Ensure-Dir (Join-Path $root $folder)
            $renamed = Rename-ToIndexed (Join-Path $root $folder)
            if ($renamed -gt 0) { Write-Host "  $job/$gender/$folder : renamed $renamed" }
        }
        Remove-EmptyLegacy (Join-Path $root "PNG")
    }
}

Write-Host ""
Write-Host "Done."
Write-Host "Path: animation/player/{job}/{gender}/{folder}/000.png"
Write-Host "Loader: scripts/characters/player_sprite_loader.gd"
