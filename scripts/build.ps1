<#
.SYNOPSIS
  Tests and packages Krool World Forever into dist\KroolWorldForever-<version>.zip.

.DESCRIPTION
  Runs the fengari suites and the Forever API lint (tools\test, npm test), regenerates the
  README settings tables (tools\settings-doc.js), then zips the KroolWorldForever folder plus
  CHANGELOG.md. The zip has KroolWorldForever\ at its root, which is what CurseForge, Wago and
  manual installs expect. Version comes from the TOC unless -Version is given.

  -Ref <commit or tag> packages that commit instead of the working tree (git archive), so the zip
  holds exactly what was committed: several sessions share this tree, and another session's
  unfinished edits must never ship. It runs no tests and writes no docs (the tree is not what is
  being packaged). release.ps1 uses it. -CheckOnly runs the tests and the docs step and stops.
#>
param(
	[string] $Version,
	[switch] $SkipTests,
	[string] $Ref,
	[switch] $CheckOnly
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $repo "KroolWorldForever"
$toc = Join-Path $addon "KroolWorldForever_Forever.toc"

# Native tools write notices to stderr; under "Stop" PowerShell 5.1 turns those into terminating
# errors. Judge them by exit code instead.
function Native([string] $dir, [scriptblock] $cmd, [string] $what) {
	$prev = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	Push-Location $dir
	try { & $cmd 2>&1 | ForEach-Object { "$_" } } finally { Pop-Location; $ErrorActionPreference = $prev }
	if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)." }
}

function TocVersion([string] $path) {
	return ((Select-String -Path $path -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value).Trim()
}

if (-not $Ref) {
	$test = Join-Path $repo "tools\test"
	if (-not $SkipTests) {
		if (-not (Test-Path (Join-Path $test "node_modules"))) {
			Native $test { npm install --silent --no-audit --no-fund } "npm install"
		}
		Native $test { npm test } "Tests"
	}
	Native $repo { node tools\settings-doc.js } "settings-doc"
}
if ($CheckOnly) { return }

$dist = Join-Path $repo "dist"
$stage = Join-Path $dist "stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force (Join-Path $stage "KroolWorldForever") | Out-Null
if ($Ref) {
	# The commit's files, not the tree's. A tar file on disk: PowerShell 5.1 corrupts binary pipes.
	$tar = Join-Path $dist "stage.tar"
	Native $repo { git archive --format=tar -o $tar $Ref KroolWorldForever CHANGELOG.md } "git archive $Ref"
	Native $repo { tar.exe -xf $tar -C $stage } "tar"
	Remove-Item -Force $tar
	Move-Item -Force (Join-Path $stage "CHANGELOG.md") (Join-Path $stage "KroolWorldForever\CHANGELOG.md")
} else {
	Copy-Item -Recurse -Force (Join-Path $addon "*") (Join-Path $stage "KroolWorldForever")
	Copy-Item -Force (Join-Path $repo "CHANGELOG.md") (Join-Path $stage "KroolWorldForever\CHANGELOG.md")
}

# The zip is named for the version inside it. A name that disagrees with its TOC is two builds
# under one version waiting to happen.
$inside = TocVersion (Join-Path $stage "KroolWorldForever\KroolWorldForever_Forever.toc")
if (-not $Version) { $Version = $inside }
if ($Version -ne $inside) {
	Remove-Item -Recurse -Force $stage
	throw "Asked for version $Version but the TOC being packaged says $inside."
}

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
