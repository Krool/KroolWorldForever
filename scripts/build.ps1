<#
.SYNOPSIS
  Tests and packages Krool World Forever into dist\KroolWorldForever-<version>.zip.

.DESCRIPTION
  Runs the fengari suites and the Forever API lint (tools\test, npm test), regenerates the
  README settings tables (tools\settings-doc.js), then zips the KroolWorldForever folder plus
  CHANGELOG.md. The zip has KroolWorldForever\ at its root, which is what CurseForge, Wago and
  manual installs expect. Version comes from the TOC unless -Version is given.
#>
param(
	[string] $Version,
	[switch] $SkipTests
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $repo "KroolWorldForever"
$toc = Join-Path $addon "KroolWorldForever_Forever.toc"

if (-not $Version) {
	$Version = ((Select-String -Path $toc -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value).Trim()
}

$test = Join-Path $repo "tools\test"
if (-not $SkipTests) {
	if (-not (Test-Path (Join-Path $test "node_modules"))) {
		Push-Location $test; npm install --silent --no-audit --no-fund; Pop-Location
	}
	Push-Location $test
	npm test
	$code = $LASTEXITCODE
	Pop-Location
	if ($code -ne 0) { throw "Tests failed; not packaging." }
}

node (Join-Path $repo "tools\settings-doc.js")
if ($LASTEXITCODE -ne 0) { throw "settings-doc failed." }

$dist = Join-Path $repo "dist"
$stage = Join-Path $dist "stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force (Join-Path $stage "KroolWorldForever") | Out-Null
Copy-Item -Recurse -Force (Join-Path $addon "*") (Join-Path $stage "KroolWorldForever")
Copy-Item -Force (Join-Path $repo "CHANGELOG.md") (Join-Path $stage "KroolWorldForever\CHANGELOG.md")

$zip = Join-Path $dist "KroolWorldForever-$Version.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $stage "KroolWorldForever") -DestinationPath $zip
Remove-Item -Recurse -Force $stage
Write-Host "Built $zip ($([math]::Round((Get-Item $zip).Length / 1KB)) KB)"
$zip
