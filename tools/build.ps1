param([switch]$DebugWeb, [switch]$SkipTests)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$godot=Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if(-not(Test-Path -LiteralPath $godot)){throw 'Run tools/bootstrap.ps1 first.'}
New-Item -ItemType Directory -Force -Path build/web,build/windows,build/qa-web,build/releases | Out-Null
& $godot --headless --editor --path $projectRoot --import
if($LASTEXITCODE -ne 0){throw 'Godot import failed.'}
& $godot --headless --audio-driver Dummy --path $projectRoot --script tools/bake-world.gd -- --bake-world --qa-silent
if($LASTEXITCODE -ne 0){throw 'World geometry bake failed.'}
& $godot --headless --audio-driver Dummy --editor --path $projectRoot --import
if($LASTEXITCODE -ne 0){throw 'Baked geometry import failed.'}
if(-not $SkipTests){
    & $godot --headless --audio-driver Dummy --path $projectRoot -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -c --ignoreHeadlessMode -rd build/unit-results -- --qa-silent --qa-test
    if($LASTEXITCODE -ne 0){throw 'Unit/integration tests failed.'}
}
if($DebugWeb){
    & $godot --headless --path $projectRoot --export-debug Web build/qa-web/index.html
    if($LASTEXITCODE -ne 0){throw 'Debug web export failed.'}
    Write-Host 'Serve QA with: node tools/serve.mjs build/qa-web 8061'
    exit 0
}
& $godot --headless --path $projectRoot --export-release Web build/web/index.html
if($LASTEXITCODE -ne 0){throw 'Web export failed.'}
& $godot --headless --path $projectRoot --export-release Windows build/windows/BulongSaBahay.exe
if($LASTEXITCODE -ne 0){throw 'Windows export failed.'}
Copy-Item -LiteralPath docs/PLAYER-README.txt -Destination build/windows/README.txt
Copy-Item -LiteralPath docs/CREDITS.txt -Destination build/windows/CREDITS.txt
New-Item -ItemType Directory -Force build/windows/licenses | Out-Null
Copy-Item assets/licenses/* build/windows/licenses
Copy-Item -LiteralPath docs/CREDITS.txt -Destination build/web/CREDITS.txt
New-Item -ItemType Directory -Force build/web/licenses | Out-Null
Copy-Item assets/licenses/* build/web/licenses
Compress-Archive -Path build/web/* -DestinationPath build/releases/BulongSaBahay-0.2.0-web.zip -Force
Compress-Archive -Path build/windows/* -DestinationPath build/releases/BulongSaBahay-0.2.0-windows.zip -Force
Get-ChildItem build/releases | Select-Object Name,@{n='MB';e={[math]::Round($_.Length/1MB,2)}}
