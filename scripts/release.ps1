<#
.SYNOPSIS
  Releases Krool World Forever: changelog gate, tests, version sync, commit, tag, zip of the
  tagged commit, push, GitHub release, and with -Publish an upload to CurseForge and Wago.

.EXAMPLE
  .\scripts\release.ps1 -Version 0.1.1
  .\scripts\release.ps1 -Version 0.2.0 -Publish

.NOTES
  - Write the "## x.y.z" CHANGELOG.md section first; the script refuses without it.
  - Bump patch for fixes and tweaks, minor for a new feature. Never reuse a version.
  - Commit the addon changes first. The script refuses while KroolWorldForever\ has uncommitted
    or untracked files: the zip is built from the tagged commit, and the tests must have run on
    the same files.
  - Several sessions share this tree. The release commit names its three paths (TOC, CHANGELOG,
    README), so whatever another session has staged stays out of it.
  - A failure before the commit puts the TOC back. A failed push leaves the commit and the tag in
    place and prints the commands that finish the release by hand.
  - -Publish needs the project ids in the TOC (## X-Curse-Project-ID, ## X-Wago-ID) and the
    tokens as user environment variables CF_API_KEY and WAGO_API_TOKEN (set them with setx in
    your own terminal; this script never writes or prints them). A missing id or token skips
    that site with a message.
#>
param(
	[Parameter(Mandatory)] [string] $Version,
	[switch] $Publish
)

$ErrorActionPreference = "Stop"
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must be x.y.z" }

$repo = Split-Path -Parent $PSScriptRoot
$tocRel = "KroolWorldForever/KroolWorldForever_Forever.toc"
$toc = Join-Path $repo $tocRel
$changelog = Join-Path $repo "CHANGELOG.md"
$utf8 = New-Object Text.UTF8Encoding $false
$build = Join-Path $PSScriptRoot "build.ps1"

# git writes notices to stderr; under "Stop" PowerShell 5.1 turns those into errors. Judge by exit code.
function Invoke-Git {
	$prev = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try { & git.exe @args 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $prev }
	if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE)" }
}

Push-Location $repo
try {
	$tag = "v$Version"
	$hasRemote = [bool](git remote)
	$branch = (git branch --show-current)
	if ($branch -ne "main") { throw "Releases come from main; this is '$branch'." }
	if (git tag --list $tag) { throw "Tag $tag already exists. Pick a new version." }
	if ($hasRemote -and (Invoke-Git ls-remote --tags origin "refs/tags/$tag")) {
		throw "Tag $tag already exists on origin. Pick a new version."
	}
	$old = ((Select-String -Path $toc -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value).Trim()
	if ([version]$Version -le [version]$old) { throw "Version $Version is not newer than the TOC's $old." }

	$log = [IO.File]::ReadAllText($changelog)
	# Single-quoted pieces: inside double quotes PowerShell would run "$(...)" as a subexpression.
	$m = [regex]::Match($log, '(?ms)^## ' + [regex]::Escape($Version) + '\s*$(.*?)(?=^## |\z)')
	if (-not $m.Success -or -not $m.Groups[1].Value.Trim()) {
		throw "CHANGELOG.md has no '## $Version' section with content. Write it first."
	}
	$first = [regex]::Match($log, '(?m)^## (\S+)')
	if ($first.Groups[1].Value -ne $Version) {
		throw "The top CHANGELOG.md section is $($first.Groups[1].Value), not $Version."
	}
	$notes = $m.Groups[1].Value.Trim()

	# What is tested must be what is committed, and what is committed is what gets zipped.
	$dirty = @(git status --porcelain -- KroolWorldForever | Where-Object { $_ -and $_.Substring(3) -ne $tocRel })
	if ($dirty.Count -gt 0) {
		throw "KroolWorldForever\ has uncommitted changes (yours or another session's). Commit them first:`n$($dirty -join "`n")"
	}

	# Version sync: the TOC is the single source of truth. Put it back if the gate fails.
	$tocBefore = [IO.File]::ReadAllText($toc)
	$committed = $false
	try {
		$t = [regex]::Replace($tocBefore, '(?m)^## Version:.*$', "## Version: $Version")
		[IO.File]::WriteAllText($toc, $t, $utf8)
		& $build -CheckOnly | Out-Host

		$msgFile = Join-Path $env:TEMP "kwf-release-msg.txt"
		[IO.File]::WriteAllText($msgFile, "Release $Version`n`n$notes`n", $utf8)
		$notesFile = Join-Path $env:TEMP "kwf-release-notes.txt"
		[IO.File]::WriteAllText($notesFile, "$notes`n", $utf8)
		# Paths after "--": only these three go in, whatever else is staged in the shared index.
		Invoke-Git commit -q -F $msgFile -- $tocRel CHANGELOG.md README.md
		$committed = $true
	} finally {
		if (-not $committed) {
			[IO.File]::WriteAllText($toc, $tocBefore, $utf8)
			Write-Host "Not released: the TOC version is back to $old."
		}
	}
	Invoke-Git tag -a $tag -F $msgFile

	$zip = & $build -Version $Version -Ref $tag | Select-Object -Last 1

	if ($hasRemote) {
		try {
			Invoke-Git push -q origin main
			Invoke-Git push -q origin $tag
		} catch {
			throw "$_`nThe commit and tag $tag exist locally and the zip is built. Finish by hand:`n  git push origin main`n  git push origin $tag`n  gh release create $tag `"$zip`" --title $Version --notes-file `"$notesFile`""
		}
		Write-Host "Pushed main and $tag"
		if (Get-Command gh -ErrorAction SilentlyContinue) {
			$prev = $ErrorActionPreference
			$ErrorActionPreference = "Continue"
			try { & gh release create $tag $zip --title $Version --notes-file $notesFile 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $prev }
			if ($LASTEXITCODE -ne 0) {
				throw "gh release create failed (exit $LASTEXITCODE). The tag is pushed; retry:`n  gh release create $tag `"$zip`" --title $Version --notes-file `"$notesFile`""
			}
		} else {
			Write-Host "gh not found: create the GitHub release by hand and attach $zip"
		}
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
