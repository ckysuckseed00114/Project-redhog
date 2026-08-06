# Creates job/gender animation folders and seeds Novice sprites from legacy Fallen Angels packs.
$root = Join-Path $PSScriptRoot "..\..\animation\player"
$jobs = @("novice", "sword", "mage", "thief", "acolyte", "hunter")
$genders = @("male", "female")
$anims = @("Idle", "Walking", "Slashing", "Hurt", "Dying")

foreach ($job in $jobs) {
    foreach ($gender in $genders) {
        foreach ($anim in $anims) {
            $dest = Join-Path $root "$job\$gender\PNG\PNG Sequences\$anim"
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            if ($job -eq "novice") {
                $src = Join-Path $root "$gender\PNG\PNG Sequences\$anim"
                if (Test-Path $src) {
                    Get-ChildItem -Path $src -Filter "*.png" | ForEach-Object {
                        Copy-Item -Path $_.FullName -Destination $dest -Force
                    }
                }
            }
        }
    }
}

Write-Host "Player animation folders ready under $root"
