$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$version='4.7.2-stable'
$base="https://github.com/godotengine/godot/releases/download/$version"
New-Item -ItemType Directory -Force .tools/godot,.downloads | Out-Null
function Fetch([string]$url,[string]$target){
    if(-not(Test-Path -LiteralPath $target)){
        & curl.exe -L --fail --silent --show-error $url -o $target
        if($LASTEXITCODE -ne 0){throw "Download failed: $url"}
    }
}
Fetch "$base/Godot_v${version}_win64.exe.zip" '.downloads/godot.zip'
Fetch "$base/Godot_v${version}_export_templates.tpz" '.downloads/templates.zip'
Fetch "$base/SHA512-SUMS.txt" '.downloads/godot-SHA512-SUMS.txt'
$sums=Get-Content -Raw .downloads/godot-SHA512-SUMS.txt
foreach($pair in @(@('.downloads/godot.zip',"Godot_v${version}_win64.exe.zip"),@('.downloads/templates.zip',"Godot_v${version}_export_templates.tpz"))){
    $actual=(Get-FileHash -LiteralPath $pair[0] -Algorithm SHA512).Hash.ToLowerInvariant()
    $line=($sums -split "`n" | Where-Object {$_ -match [regex]::Escape($pair[1])})
    if(-not $line -or -not $line.StartsWith($actual)){throw "Checksum mismatch: $($pair[0])"}
}
Expand-Archive .downloads/godot.zip .tools/godot -Force
# Portable mode keeps the development toolchain under this workspace.
New-Item -ItemType File -Force .tools/godot/_sc_ | Out-Null
if(-not(Test-Path .tools/export/templates)) {Expand-Archive .downloads/templates.zip .tools/export -Force}
$templateDir='.tools/godot/editor_data/export_templates/4.7.2.stable'
New-Item -ItemType Directory -Force $templateDir | Out-Null
foreach($name in @('web_nothreads_debug.zip','web_nothreads_release.zip','windows_debug_x86_64.exe','windows_release_x86_64.exe','windows_debug_x86_64_console.exe','windows_release_x86_64_console.exe')){
    Copy-Item -LiteralPath (Join-Path .tools/export/templates $name) -Destination $templateDir
}
& .tools/godot/Godot_v4.7.2-stable_win64_console.exe --version
Write-Host 'Portable Godot is ready. Run tools/build.ps1 to test and package.'
