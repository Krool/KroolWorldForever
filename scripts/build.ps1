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

# Native tools write notices to stderr; under "Stop" PowerShell 5.1 turns those into terminating
# errors. Judge them by exit code instead.
function Native([string] $dir, [scriptblock] $cmd, [string] $what) {
	$prev = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	Push-Location $dir
	try { & $cmd 2>&1 | ForEach-Object { "$_" } } finally { Pop-Location; $ErrorActionPreference = $prev }
	if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)." }
}

$test = Join-Path $repo "tools\test"
if (-not $SkipTests) {
	if (-not (Test-Path (Join-Path $test "node_modules"))) {
		Native $test { npm install --silent --no-audit --no-fund } "npm install"
	}
	Native $test { npm test } "Tests"
}

Native $repo { node tools\settings-doc.js } "settings-doc"

$dist = Join-Path $repo "dist"
$stage = Join-Path $dist "stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force (Join-Path $stage "KroolWorldForever") | Out-Null
Copy-Item -Recurse -Force (Join-Path $addon "*") (Join-Path $stage "KroolWorldForever")
Copy-Item -Force (Join-Path $repo "CHANGELOG.md") (Join-Path $stage "KroolWorldForever\CHANGELOG.md")

$zip = Join-Path $dist "KroolWorldForever-$Version.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
# Not Compress-Archive: on PowerShell 5.1 it writes backslash entry names, which the zip spec
# forbids and some extractors and upload sites mishandle.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
	Get-ChildItem -Recurse -File $stage | ForEach-Object {
		$entry = $_.FullName.Substring($stage.Length + 1).Replace("\", "/")
		[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
	}
} finally {
	$archive.Dispose()
}
Remove-Item -Recurse -Force $stage
Write-Host "Built $zip ($([math]::Round((Get-Item $zip).Length / 1KB)) KB)"
$zip
