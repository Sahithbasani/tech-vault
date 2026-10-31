[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptUnderTest = Join-Path $repositoryRoot 'scripts/Test-MarkdownLinks.ps1'
$fixturesRoot = Join-Path $PSScriptRoot 'fixtures'

$validOutput = & $scriptUnderTest -Root (Join-Path $fixturesRoot 'valid') | Out-String
if ($validOutput -notmatch 'Validated 1 repository-relative Markdown link') {
    throw "The valid fixture did not report the expected link count. Output: $validOutput"
}

$failureMessage = $null
try {
    & $scriptUnderTest -Root (Join-Path $fixturesRoot 'broken') | Out-Null
}
catch {
    $failureMessage = $_.Exception.Message
}

if ($null -eq $failureMessage) {
    throw 'The broken-link fixture unexpectedly passed validation.'
}

if ($failureMessage -notmatch 'README.md:3 -> docs/missing.md') {
    throw "The broken-link error was not actionable. Message: $failureMessage"
}

Write-Host 'Markdown link verifier regression tests passed.'
