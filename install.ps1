Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$versionDir = Join-Path $PSScriptRoot 'versions'
$versionFiles = @(Get-ChildItem -LiteralPath $versionDir -File -Filter '*.md' |
    Where-Object { $_.BaseName -match '^\d+$' } |
    Sort-Object { [int]$_.BaseName })
if ($versionFiles.Count -eq 0) {
    throw "No numbered AGENTS.md versions were found in $versionDir."
}
$source = $versionFiles[-1].FullName

$homeDir = if ($env:CODEX_AGENTS_HOME) { $env:CODEX_AGENTS_HOME } else { $HOME }
$defaultTarget = if ($env:CODEX_HOME -and (Test-Path -LiteralPath $env:CODEX_HOME -PathType Container)) {
    [System.IO.Path]::GetFullPath($env:CODEX_HOME)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $homeDir '.codex'))
}
$targets = @(Get-ChildItem -LiteralPath $homeDir -Directory -Force |
    Where-Object { $_.Name -like '.codex*' } |
    ForEach-Object { [System.IO.Path]::GetFullPath($_.FullName) })

$targets = @($targets + $defaultTarget | Sort-Object -Unique)
$defaultIndex = [Array]::IndexOf($targets, $defaultTarget) + 1
if ($defaultIndex -lt 1) {
    throw "Default target was not found: $defaultTarget"
}

Write-Host 'Select install target (Enter selects *):'
for ($i = 0; $i -lt $targets.Count; $i++) {
    $marker = if (($i + 1) -eq $defaultIndex) { '*' } else { ' ' }
    Write-Host ("{0} [{1}] {2}" -f $marker, ($i + 1), $targets[$i])
}

$selected = if ($env:CODEX_AGENTS_SELECT) { $env:CODEX_AGENTS_SELECT } else { Read-Host 'Number' }
if (-not $selected) {
    $selected = [string]$defaultIndex
}
$index = 0
if (-not [int]::TryParse($selected, [ref]$index) -or $index -lt 1 -or $index -gt $targets.Count) {
    throw "Invalid selection: $selected"
}

$target = $targets[$index - 1]
New-Item -ItemType Directory -Force -Path $target | Out-Null
$destination = Join-Path $target 'AGENTS.md'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$sourceContent = [System.IO.File]::ReadAllText($source, $utf8)

if (Test-Path -LiteralPath $destination) {
    $existingContent = [System.IO.File]::ReadAllText($destination, $utf8)
    Write-Host "Existing AGENTS.md:"
    Write-Host '---'
    Write-Host $existingContent
    Write-Host '---'

    $matchedVersion = $null
    $matchedContent = $null
    $matchedPath = $null
    $matchedLength = -1
    foreach ($versionFile in $versionFiles) {
        $versionContent = [System.IO.File]::ReadAllText($versionFile.FullName, $utf8)
        if ($versionContent -and $existingContent.Contains($versionContent)) {
            $versionLength = $versionContent.Length
            $versionNumber = [int]$versionFile.BaseName
            $matchedNumber = if ($matchedVersion) { [int][System.IO.Path]::GetFileNameWithoutExtension($matchedVersion) } else { -1 }
            if ($versionLength -gt $matchedLength -or ($versionLength -eq $matchedLength -and $versionNumber -gt $matchedNumber)) {
                $matchedVersion = $versionFile.Name
                $matchedContent = $versionContent
                $matchedPath = $versionFile.FullName
                $matchedLength = $versionLength
            }
        }
    }

    if ($matchedPath -eq $source) {
        Write-Host "Skipped: latest AGENTS.md version is already included in $destination."
        exit 0
    }
    if ($matchedVersion) {
        Write-Host "Current version: $matchedVersion"
        Write-Host ("Install version: {0}" -f (Split-Path -Leaf $source))
        $save = if ($env:CODEX_AGENTS_SAVE) { $env:CODEX_AGENTS_SAVE } else { Read-Host 'Replace matched version? [Y/n]' }
        if ($save -and $save.ToLowerInvariant() -notin @('y', 'yes')) {
            Write-Host "Skipped: $destination"
            exit 0
        }
        $updatedContent = $existingContent.Replace($matchedContent, $sourceContent)
        [System.IO.File]::WriteAllText($destination, $updatedContent, $utf8)
        Write-Host "Replaced matched version: $destination"
    } else {
        $action = if ($env:CODEX_AGENTS_ACTION) { $env:CODEX_AGENTS_ACTION } else { Read-Host 'No known version matched. Action ([O]verwrite / [a]ppend)' }
        if (-not $action) {
            $action = 'overwrite'
        }
        switch ($action.ToLowerInvariant()) {
            { $_ -in @('o', 'overwrite') } {
                [System.IO.File]::WriteAllText($destination, $sourceContent, $utf8)
                Write-Host "Overwritten: $destination"
            }
            { $_ -in @('a', 'append') } {
                [System.IO.File]::AppendAllText($destination, "`r`n`r`n$sourceContent", $utf8)
                Write-Host "Appended: $destination"
            }
            default {
                throw "Invalid action: $action"
            }
        }
    }
} else {
    Copy-Item -LiteralPath $source -Destination $destination
    Write-Host "Installed: $destination"
}
