[CmdletBinding()]
param(
    [Parameter()]
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$excludedDirectories = @('.git', 'node_modules', 'bin', 'obj', 'tests')
$markdownFiles = Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter '*.md' |
    Where-Object {
        $relativePath = $_.FullName.Substring($resolvedRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        -not ($relativePath -split '[\\/]' | Where-Object { $_ -in $excludedDirectories })
    }

$linkPattern = [regex]'(?<!!)(?<!\\)\[[^\]]*\]\((?<destination><[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)'
$failures = [System.Collections.Generic.List[string]]::new()
$checkedLinks = 0

foreach ($file in $markdownFiles) {
    $fenceCharacter = $null
    $fenceLength = 0
    $lineNumber = 0

    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber++
        $fenceMatch = [regex]::Match($line, '^\s*(?<fence>`{3,}|~{3,})')
        if ($fenceMatch.Success) {
            $currentFence = $fenceMatch.Groups['fence'].Value
            if ($null -eq $fenceCharacter) {
                $fenceCharacter = $currentFence[0]
                $fenceLength = $currentFence.Length
            }
            elseif ($currentFence[0] -eq $fenceCharacter -and $currentFence.Length -ge $fenceLength) {
                $fenceCharacter = $null
                $fenceLength = 0
            }

            continue
        }

        if ($null -ne $fenceCharacter) {
            continue
        }

        foreach ($match in $linkPattern.Matches($line)) {
            $destination = $match.Groups['destination'].Value.Trim('<', '>')
            if ([string]::IsNullOrWhiteSpace($destination) -or
                $destination.StartsWith('#') -or
                $destination -match '^(?i:https?|mailto|tel|ftp):' -or
                $destination.StartsWith('//')) {
                continue
            }

            $checkedLinks++
            $pathPart = ($destination -split '[?#]', 2)[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) {
                continue
            }

            $decodedPath = [System.Uri]::UnescapeDataString($pathPart)
            $candidate = if ($decodedPath.StartsWith('/')) {
                Join-Path $resolvedRoot $decodedPath.TrimStart('/')
            }
            else {
                Join-Path $file.DirectoryName $decodedPath
            }

            if (-not (Test-Path -LiteralPath $candidate)) {
                $relativeFile = $file.FullName.Substring($resolvedRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
                $failures.Add("${relativeFile}:$lineNumber -> $destination")
            }
        }
    }
}

if ($failures.Count -gt 0) {
    $details = $failures -join [Environment]::NewLine
    throw "Found $($failures.Count) broken repository-relative Markdown link(s):$([Environment]::NewLine)$details"
}

Write-Output "Validated $checkedLinks repository-relative Markdown link(s) in $($markdownFiles.Count) Markdown file(s)."
