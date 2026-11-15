<#
.SYNOPSIS
  Tests and packages Krool World Forever into dist\KroolWorldForever-<version>.zip, and every
  standalone addon (standalone\addons.json, built by tools\standalone\build.js) into
  dist\<Folder>-<version>.zip.

.DESCRIPTION
  Runs the fengari suites and the Forever API lint (tools\test, npm test), regenerates the
  README settings tables (tools\settings-doc.js), then zips the KroolWorldForever folder plus
  CHANGELOG.md. The zip has KroolWorldForever\ at its root, which is what CurseForge, Wago and
  manual installs expect. Version comes from the TOC unless -Version is given.

  -Ref <commit or tag> packages that commit instead of the working tree (git archive), so the zip
  holds exactly what was committed: several sessions share this tree, and another session's
  unfinished edits must never ship. It runs no tests and writes no docs (the tree is not what is
  being packaged); the standalones are generated from that commit too (its standalone\ folder and
  tools\standalone\build.js). release.ps1 uses it. -CheckOnly runs the tests and the docs step and
  stops.

  Output: the standalone zip paths first, the bundle's zip last. Every zip carries the same
  version (the TOC being packaged).
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
$srcStage = Join-Path $dist "src" # what the standalone generator reads
$standaloneStage = Join-Path $dist "standalone-stage"
foreach ($d in $stage, $srcStage, $standaloneStage) {
	if (Test-Path $d) { Remove-Item -Recurse -Force $d }
}
New-Item -ItemType Directory -Force (Join-Path $stage "KroolWorldForever") | Out-Null
if ($Ref) {
	# The commit's files, not the tree's. A tar file on disk: PowerShell 5.1 corrupts binary pipes.
	$tar = Join-Path $dist "stage.tar"
	Native $repo { git archive --format=tar -o $tar $Ref KroolWorldForever CHANGELOG.md } "git archive $Ref"
	Native $repo { tar.exe -xf $tar -C $stage } "tar"
	Remove-Item -Force $tar
	Move-Item -Force (Join-Path $stage "CHANGELOG.md") (Join-Path $stage "KroolWorldForever\CHANGELOG.md")
	# The standalone generator and its inputs, from the same commit.
	New-Item -ItemType Directory -Force $srcStage | Out-Null
	$tar = Join-Path $dist "src.tar"
	Native $repo { git archive --format=tar -o $tar $Ref KroolWorldForever standalone tools/standalone/build.js } "git archive $Ref (standalone sources)"
	Native $repo { tar.exe -xf $tar -C $srcStage } "tar"
	Remove-Item -Force $tar
} else {
	$srcStage = $repo
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

# Not Compress-Archive: on PowerShell 5.1 it writes backslash entry names, which the zip spec
# forbids and some extractors and upload sites mishandle. The folder sits at the zip's root.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
function New-AddonZip([string] $parent, [string] $folder, [string] $zip) {
	if (Test-Path $zip) { Remove-Item -Force $zip }
	$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
	try {
		Get-ChildItem -Recurse -File (Join-Path $parent $folder) | ForEach-Object {
			$entry = $_.FullName.Substring($parent.Length + 1).Replace("\", "/")
			[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
		}
	} finally {
		$archive.Dispose()
	}
	Write-Host "Built $zip ($([math]::Round((Get-Item $zip).Length / 1KB)) KB)"
}

# The standalones, generated from the same source and version (tools\standalone\build.js).
$generator = Join-Path $srcStage "tools\standalone\build.js"
Native $repo { node $generator --src $srcStage --out $standaloneStage --version $Version } "standalone build" | Out-Host
$zips = @()
foreach ($folder in (Get-ChildItem -Directory $standaloneStage | Sort-Object Name | ForEach-Object { $_.Name })) {
	$standaloneZip = Join-Path $dist "$folder-$Version.zip"
	New-AddonZip $standaloneStage $folder $standaloneZip
	$zips += $standaloneZip
}
Remove-Item -Recurse -Force $standaloneStage
if ($Ref) { Remove-Item -Recurse -Force $srcStage }

$zip = Join-Path $dist "KroolWorldForever-$Version.zip"
New-AddonZip $stage "KroolWorldForever" $zip
Remove-Item -Recurse -Force $stage
$zips
$zip
