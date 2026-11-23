# Prints the manual to PDF with headless Chrome (or Edge).
# The template's dark palette is keyed off prefers-color-scheme, so the page is
# rendered from a temporary copy pinned to data-theme="light" -- a PDF should be
# black on white whatever the desktop theme is.
param(
    [string]$Html = "dist/manual.html",
    [string]$Pdf = "dist/manual.pdf"
)
$ErrorActionPreference = "Stop"

$candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
)
$browser = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $browser) {
    Write-Warning "no Chrome or Edge found, skipping $Pdf"
    exit 1
}

$html = [IO.File]::ReadAllText((Resolve-Path $Html))
$html = $html -replace '<html lang="en">', '<html lang="en" data-theme="light">'
$tmp = Join-Path ([IO.Path]::GetTempPath()) "defuse64-manual.html"
[IO.File]::WriteAllText($tmp, $html, (New-Object Text.UTF8Encoding($false)))

$out = [IO.Path]::GetFullPath($Pdf)
if (Test-Path $out) { Remove-Item $out }
$uri = "file:///" + ($tmp -replace '\\', '/')

# --virtual-time-budget lets the web fonts settle before the page is painted.
# Chrome chatters on stderr (extension registry noise), so stop treating native
# error output as fatal for the duration of the call.
$ErrorActionPreference = "Continue"
& $browser --headless=new --disable-gpu --no-pdf-header-footer `
    --virtual-time-budget=10000 --print-to-pdf="$out" $uri 2>$null | Out-Null
$ErrorActionPreference = "Stop"
if (-not (Test-Path $out) -or (Get-Item $out).Length -lt 10000) {
    throw "Chrome did not produce $Pdf"
}
Write-Host ("wrote {0} ({1:N0} kB)" -f $Pdf, ((Get-Item $out).Length / 1kB))
