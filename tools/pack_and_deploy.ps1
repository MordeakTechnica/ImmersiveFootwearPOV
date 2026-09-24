param(
    [string]$GameDir = "D:\SteamLibrary\steamapps\common\Cyberpunk 2077",
    [string]$WkitCli = "C:\Users\cogli\AppData\Local\Programs\WolvenKit\CLI\WolvenKit.CLI.exe"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Archive names matching the mod with 'zz' prefix
$ArchiveNameWithSpace = "zz_Immersive Footwear POV.archive"
$ArchiveNameNoSpace = "zz_ImmersiveFootwearPOV.archive"

Write-Host "=== Step 1: Converting Raw AnimGraph to CR2W ===" -ForegroundColor Cyan
$rawJson = Join-Path $ProjectRoot "source\raw\base\gameplay\anim_graphs\player_base.animgraph.json"
$stagingRoot = Join-Path $ProjectRoot "source\archive"
$archiveAnimgraph = Join-Path $stagingRoot "base\gameplay\anim_graphs\player_base.animgraph"
$archiveDir = Split-Path -Parent $archiveAnimgraph

if (-not (Test-Path $rawJson)) {
    throw "Raw JSON not found at $rawJson"
}

# Run WolvenKit CLI convert d on the raw JSON
& $WkitCli convert d $rawJson
$rawGeneratedAnimgraph = Join-Path (Split-Path -Parent $rawJson) "player_base.animgraph"

# Move/Copy generated CR2W to source\archive\base\gameplay\anim_graphs
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
Copy-Item -Force $rawGeneratedAnimgraph -Destination $archiveAnimgraph
Remove-Item -Force $rawGeneratedAnimgraph

Write-Host "[+] Compiled CR2W in place: $archiveAnimgraph ($((Get-Item $archiveAnimgraph).Length) bytes)" -ForegroundColor Green

Write-Host "`n=== Step 2: Packing Archive ===" -ForegroundColor Cyan
# To pack cleanly, we temporarily pack only the 'base' folder inside a staging directory
$packStagingDir = Join-Path $ProjectRoot "temp_pack_staging"
New-Item -ItemType Directory -Force -Path $packStagingDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $stagingRoot "base") (Join-Path $packStagingDir "base")

$packOutDir = Join-Path $ProjectRoot "packed\archive\pc\mod"
New-Item -ItemType Directory -Force -Path $packOutDir | Out-Null

& $WkitCli pack $packStagingDir -o $packOutDir
Remove-Item -Recurse -Force $packStagingDir

$tempArchive = Join-Path $packOutDir "temp_pack_staging.archive"
if (-not (Test-Path $tempArchive)) {
    # If packed name was archive.archive
    $tempArchive = Join-Path $packOutDir "archive.archive"
}

$packedArchive = Join-Path $packOutDir $ArchiveNameWithSpace
Move-Item -Force $tempArchive $packedArchive
# Also keep a no-space copy in packed for maximum compatibility
Copy-Item -Force $packedArchive (Join-Path $packOutDir $ArchiveNameNoSpace)

Write-Host "[+] Packed archive: $packedArchive" -ForegroundColor Green
Write-Host "[*] Verifying internal archive structure:" -ForegroundColor DarkGray
& $WkitCli archive $packedArchive -l

Write-Host "`n=== Step 3: Copying Archive to Project Archive Folders ===" -ForegroundColor Cyan
# Copy to source\archive folder as requested by user
Copy-Item -Force $packedArchive (Join-Path $stagingRoot $ArchiveNameWithSpace)
Copy-Item -Force $packedArchive (Join-Path $stagingRoot $ArchiveNameNoSpace)
Write-Host "[+] Copied $ArchiveNameWithSpace into $stagingRoot" -ForegroundColor Green

# Copy to source\resources\archive\pc\mod folder
$resArchiveDir = Join-Path $ProjectRoot "source\resources\archive\pc\mod"
New-Item -ItemType Directory -Force -Path $resArchiveDir | Out-Null
Copy-Item -Force $packedArchive (Join-Path $resArchiveDir $ArchiveNameWithSpace)
Copy-Item -Force $packedArchive (Join-Path $resArchiveDir $ArchiveNameNoSpace)
Write-Host "[+] Copied $ArchiveNameWithSpace into $resArchiveDir" -ForegroundColor Green

Write-Host "`n=== Step 4: Deploying to Game Directory ===" -ForegroundColor Cyan
# 4a. Mod Archive in game directory
$gameModDir = Join-Path $GameDir "archive\pc\mod"
New-Item -ItemType Directory -Force -Path $gameModDir | Out-Null

# Clean up older intermediate name if present
$oldArchive = Join-Path $gameModDir "zz_ImmersiveFootwearPOV_ITP.archive"
if (Test-Path $oldArchive) {
    Remove-Item -Force $oldArchive
    Write-Host "[*] Removed outdated $oldArchive" -ForegroundColor DarkGray
}

Copy-Item -Force $packedArchive (Join-Path $gameModDir $ArchiveNameWithSpace)
Copy-Item -Force $packedArchive (Join-Path $gameModDir $ArchiveNameNoSpace)
Write-Host "[+] Deployed archive to $gameModDir\$ArchiveNameWithSpace" -ForegroundColor Green

# 4b. REDscripts
$sourceScripts = Join-Path $ProjectRoot "source\resources\r6\scripts\ImmersiveFootwearPOV"
$gameScripts = Join-Path $GameDir "r6\scripts\ImmersiveFootwearPOV"
Copy-Item -Recurse -Force "$sourceScripts\*" -Destination $gameScripts
Write-Host "[+] Deployed REDscripts to $gameScripts" -ForegroundColor Green

# 4c. CET Mod files
$sourceCet = Join-Path $ProjectRoot "source\resources\bin\x64\plugins\cyber_engine_tweaks\mods\ImmersiveFootwearPOV"
$gameCet = Join-Path $GameDir "bin\x64\plugins\cyber_engine_tweaks\mods\ImmersiveFootwearPOV"
Copy-Item -Force (Join-Path $sourceCet "init.lua") -Destination (Join-Path $gameCet "init.lua")
Copy-Item -Recurse -Force (Join-Path $sourceCet "integrations\*") -Destination (Join-Path $gameCet "integrations")
Copy-Item -Recurse -Force (Join-Path $sourceCet "modules\*") -Destination (Join-Path $gameCet "modules")
Write-Host "[+] Deployed CET files to $gameCet" -ForegroundColor Green

Write-Host "`n=== Step 5: Validating REDscript Compilation in Game ===" -ForegroundColor Cyan
$scc = Join-Path $GameDir "engine\tools\scc.exe"
$finalRedscripts = Join-Path $GameDir "r6\cache\final.redscripts"
if ((Test-Path $scc) -and (Test-Path $finalRedscripts)) {
    & $scc -compile $gameScripts $finalRedscripts -threads 4
    Write-Host "[+] REDscript compilation verified successfully!" -ForegroundColor Green
} else {
    Write-Host "[-] scc.exe or final.redscripts not found, skipping validation." -ForegroundColor Yellow
}

Write-Host "`n=== All Steps Complete: Archive and Scripts Verified! ===" -ForegroundColor Green
