<#
.SYNOPSIS
  Releases Krool World Forever: version sync, changelog gate, build, commit, tag, push,
  and with -Publish an upload to CurseForge and Wago.

.EXAMPLE
  .\scripts\release.ps1 -Version 0.1.1
  .\scripts\release.ps1 -Version 0.2.0 -Publish

.NOTES
  - Write the "## x.y.z" CHANGELOG.md section first; the script refuses without it.
  - Bump patch for fixes and tweaks, minor for a new feature. Never reuse a version.
  - -Publish needs the project ids in the TOC (## X-Curse-Project-ID, ## X-Wago-ID) and the
    tokens as user environment variables CF_API_KEY and WAGO_API_TOKEN (set them with setx in
    your own terminal; this script never writes or prints them). A missing id or token skips
    that site with a message.
  - Stages only the files it changes (TOC, CHANGELOG, README): other sessions share this tree.
#>
param(
	[Parameter(Mandatory)] [string] $Version,
	[switch] $Publish
)

$ErrorActionPreference = "Stop"
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must be x.y.z" }

$repo = Split-Path -Parent $PSScriptRoot
$toc = Join-Path $repo "KroolWorldForever\KroolWorldForever_Forever.toc"
$changelog = Join-Path $repo "CHANGELOG.md"
$readme = Join-Path $repo "README.md"
$utf8 = New-Object Text.UTF8Encoding $false

Push-Location $repo
try {
	if (git tag --list "v$Version") { throw "Tag v$Version already exists. Pick a new version." }

	$log = [IO.File]::ReadAllText($changelog)
	# Single-quoted pieces: inside double quotes PowerShell would run "$(...)" as a subexpression.
	$m = [regex]::Match($log, '(?ms)^## ' + [regex]::Escape($Version) + '\s*$(.*?)(?=^## |\z)')
	if (-not $m.Success -or -not $m.Groups[1].Value.Trim()) {
		throw "CHANGELOG.md has no '## $Version' section with content. Write it first."
	}
	$notes = $m.Groups[1].Value.Trim()

	# Version sync: the TOC is the single source of truth.
	$t = [IO.File]::ReadAllText($toc)
	$t = [regex]::Replace($t, '(?m)^## Version:.*$', "## Version: $Version")
	[IO.File]::WriteAllText($toc, $t, $utf8)

	$zip = & (Join-Path $PSScriptRoot "build.ps1") -Version $Version | Select-Object -Last 1

	# git writes notices to stderr; under "Stop" PowerShell 5.1 turns those into errors. Judge by exit code.
	function Invoke-Git {
		$prev = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		try { & git.exe @args 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $prev }
		if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE)" }
	}

	Invoke-Git add -- $toc $changelog $readme
	$msgFile = Join-Path $env:TEMP "kwf-release-msg.txt"
	[IO.File]::WriteAllText($msgFile, "Release $Version`n`n$notes`n", $utf8)
	Invoke-Git commit -q -F $msgFile
	Invoke-Git tag -a "v$Version" -F $msgFile
	if (git remote) {
		Invoke-Git push -q
		Invoke-Git push -q origin "v$Version"
		Write-Host "Pushed main and v$Version"
	} else {
		Write-Host "No git remote; committed and tagged locally only."
	}

	if ($Publish) {
		& (Join-Path $PSScriptRoot "publish.ps1") -Zip $zip -Version $Version -Notes $notes
	}
	Write-Host "Released $Version -> $zip"
} finally {
	Pop-Location
}
