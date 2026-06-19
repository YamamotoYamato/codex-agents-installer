Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'AGENTS.md'
if (-not (Test-Path -LiteralPath $source)) {
    throw "AGENTS.md was not found next to install.ps1."
}

$homeDir = if ($env:CODEX_AGENTS_HOME) { $env:CODEX_AGENTS_HOME } else { $HOME }
$targets = Get-ChildItem -LiteralPath $homeDir -Directory -Force |
    Where-Object { $_.Name -like '.codex*' } |
    Sort-Object Name

if ($targets.Count -eq 0) {
    throw "No .codex* directories were found in $homeDir."
}

Write-Host 'Select install target:'
for ($i = 0; $i -lt $targets.Count; $i++) {
    Write-Host ("[{0}] {1}" -f ($i + 1), $targets[$i].FullName)
}

$selected = if ($env:CODEX_AGENTS_SELECT) { $env:CODEX_AGENTS_SELECT } else { Read-Host 'Number' }
$index = 0
if (-not [int]::TryParse($selected, [ref]$index) -or $index -lt 1 -or $index -gt $targets.Count) {
    throw "Invalid selection: $selected"
}

$destination = Join-Path $targets[$index - 1].FullName 'AGENTS.md'
Copy-Item -LiteralPath $source -Destination $destination -Force
Write-Host "Installed: $destination"
