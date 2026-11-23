# Builds DEFUSE 64: generates data + manual, assembles, and makes a .d64
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$kick = $env:KICKASS_JAR
if (-not $kick) { $kick = "C:\Users\joshu\Downloads\T2_C64_Port\tools\kick\KickAss.jar" }

python tools\gen.py
if ($LASTEXITCODE -ne 0) { throw "gen.py failed" }

java -jar $kick src\main.asm -odir ..\build -o build\defuse64.prg -showmem
if ($LASTEXITCODE -ne 0) { throw "assembly failed" }

Copy-Item build\defuse64.prg dist\defuse64.prg -Force
if (Test-Path dist\defuse64.d64) { Remove-Item dist\defuse64.d64 }
c1541 -format "defuse 64,d6" d64 dist\defuse64.d64 -write dist\defuse64.prg "defuse 64" | Out-Null

# Print the manual to PDF with headless Chrome/Edge (skipped with a warning if
# neither is installed).
& (Join-Path $PSScriptRoot "tools\manual_pdf.ps1")
if ($LASTEXITCODE -ne 0) { Write-Warning "dist\manual.pdf was not rebuilt" }

Write-Host "Built dist\defuse64.prg, dist\defuse64.d64, dist\manual.html, dist\manual.pdf"
