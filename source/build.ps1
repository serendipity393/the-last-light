$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$gameRoot = Split-Path $projectDir -Parent
$engine = Join-Path $gameRoot 'tools/godot/Godot_v4.4.1-stable_win64_console.exe'
$outputDir = Join-Path $gameRoot '发布版/最后一盏灯'
$cacheDir = Join-Path $gameRoot 'artifacts'
$env:APPDATA = $cacheDir
$env:LOCALAPPDATA = $cacheDir
$env:TEMP = $cacheDir
$env:TMP = $cacheDir
New-Item -ItemType Directory -Force -Path (Join-Path $outputDir 'data') | Out-Null
Push-Location $projectDir
try {
    & $engine --headless --path $projectDir --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
    & $engine --headless --path $projectDir --export-release 'Windows Desktop'
    if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
    & $engine --headless --path $projectDir --script res://export_licenses.gd
    & node create_icon.js
    & windres launcher.rc -O coff -o (Join-Path $cacheDir 'launcher-res.o')
    if ($LASTEXITCODE -ne 0) { throw 'Icon compilation failed' }
    & gcc launcher.c (Join-Path $cacheDir 'launcher-res.o') -municode -mwindows -static-libgcc -Os -s -o (Join-Path $outputDir '最后一盏灯.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed' }
} finally {
    Pop-Location
}
Write-Host "发布版已生成：$outputDir"
