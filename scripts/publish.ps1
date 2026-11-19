<#
.SYNOPSIS
  Uploads built zips to CurseForge and Wago Addons: the bundle, and each standalone addon that has
  a project. Called by release.ps1 -Publish.

.DESCRIPTION
  The bundle is uploaded on every release. A standalone (standalone\addons.json, entries with a
  curseId) is uploaded only when its built files changed: the hash of its zip's entries, with the
  TOC's "## Version:" line left out, is compared with standalone\published.json (key -> hash and
  version). After the uploads the file is rewritten; release.ps1 commits it. -Force uploads every
  standalone anyway. -DryRun prints what would be uploaded (projects, files, hashes, changelogs)
  and calls no API, needs no token, and writes nothing. -SkipBundle leaves the bundle alone (on
  CurseForge and Wago) and uploads only the standalones: use it to finish a publish that uploaded
  the bundle and then failed on a standalone, so the bundle is not uploaded twice.

  A standalone's changelog is the top-level bullets of the release notes whose bold lead starts
  with the feature's title ("**Quest Trash: ...**", "**One-Button Fishing fixes.**"), or
  "Shared fixes from Krool World Forever <version>." when none does.

.NOTES
  The CurseForge upload follows the BigWigs packager (release.sh) and was checked against the
  live API for the version lookup only; Wago has no project yet and is untested.
    CurseForge  POST https://wow.curseforge.com/api/projects/<id>/upload-file
                header X-Api-Token, multipart "metadata" (JSON) + "file".
                Forever is game version type 88568; the version named for the patch is used.
    Wago        POST https://addons.wago.io/api/projects/<id>/version
                header Authorization: Bearer <token>, multipart label, stability, changelog,
                supported_forever_patches[], file.
  Bundle ids come from its TOC (## X-Curse-Project-ID, ## X-Wago-ID); standalone ids from the
  manifest. Tokens come from the user environment (CF_API_KEY, WAGO_API_TOKEN) and are never
  printed or written.
#>
param(
	[Parameter(Mandatory)] [string] $Zip,
	[Parameter(Mandatory)] [string] $Version,
	[string] $Notes = "",
	[string] $Manifest,
	[string] $Published,
	[string] $DistDir,
	[switch] $DryRun,
	[switch] $Force,
	[switch] $SkipBundle
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http, System.IO.Compression, System.IO.Compression.FileSystem
$repo = Split-Path -Parent $PSScriptRoot
$toc = Join-Path $repo "KroolWorldForever\KroolWorldForever_Forever.toc"
if (-not $Manifest) { $Manifest = Join-Path $repo "standalone\addons.json" }
if (-not $Published) { $Published = Join-Path $repo "standalone\published.json" }
if (-not $DistDir) { $DistDir = Split-Path -Parent $Zip }
$utf8 = New-Object Text.UTF8Encoding $false

function TocField([string] $name) {
	$hit = Select-String -Path $toc -Pattern "^## ${name}:\s*(.+)$"
	if ($hit) { return $hit.Matches[0].Groups[1].Value.Trim() }
	return $null
}
function EnvToken([string] $name) {
	$v = [Environment]::GetEnvironmentVariable($name, "Process")
	if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, "User") }
	return $v
}
function FileContent([string] $path) {
	$c = New-Object System.Net.Http.ByteArrayContent (, [IO.File]::ReadAllBytes($path))
	$c.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
	return $c
}

# SHA-256 over a zip's entries in name order (name, then content), the TOC without its Version line:
# two builds that differ only in the version number hash the same.
function ZipHash([string] $path) {
	$sha = [Security.Cryptography.SHA256]::Create()
	$archive = [IO.Compression.ZipFile]::OpenRead($path)
	try {
		foreach ($e in ($archive.Entries | Where-Object { $_.Name } | Sort-Object { $_.FullName } -CaseSensitive)) {
			$ms = New-Object IO.MemoryStream
			$s = $e.Open()
			try { $s.CopyTo($ms) } finally { $s.Dispose() }
			$bytes = $ms.ToArray()
			if ($e.FullName -like "*.toc") {
				$text = $utf8.GetString($bytes) -replace '(?m)^## Version:[^\r\n]*\r?\n?', ''
				$bytes = $utf8.GetBytes($text)
			}
			$name = $utf8.GetBytes($e.FullName + "`0")
			[void]$sha.TransformBlock($name, 0, $name.Length, $null, 0)
			[void]$sha.TransformBlock($bytes, 0, $bytes.Length, $null, 0)
		}
		[void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
		return ([BitConverter]::ToString($sha.Hash) -replace '-', '').ToLower()
	} finally {
		$archive.Dispose()
	}
}

# The release notes' top-level bullets whose bold lead starts with the feature's title.
function FeatureChangelog([string] $title, [string] $notes, [string] $version) {
	$bullets = @()
	$current = $null
	foreach ($line in ($notes -split "\r?\n")) {
		if ($line -match '^- ') {
			if ($current) { $bullets += , $current }
			$current = New-Object Collections.Generic.List[string]
			$current.Add($line)
		} elseif ($current -and $line -match '^\s+\S') {
			$current.Add($line)
		} else {
			if ($current) { $bullets += , $current }
			$current = $null
		}
	}
	if ($current) { $bullets += , $current }
	$pattern = '^- \*\*' + [regex]::Escape($title)
	$mine = @($bullets | Where-Object { $_[0] -match $pattern } | ForEach-Object { $_ -join "`n" })
	if ($mine.Count -eq 0) { return "Shared fixes from Krool World Forever $version." }
	return ($mine -join "`n")
}

$client = New-Object System.Net.Http.HttpClient
$patch = "1.60.1" # Forever's game version for Interface 16001; update with the client
$interface = TocField "Interface"
$cfToken = EnvToken "CF_API_KEY"
$script:forever = $null

# The game version to tag uploads with: the one named for this patch, else the newest Forever one.
function ForeverVersion {
	if ($script:forever) { return $script:forever }
	$req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Get), "https://wow.curseforge.com/api/game/wow/versions"
	$req.Headers.Add("X-Api-Token", $cfToken)
	$versions = $client.SendAsync($req).Result.Content.ReadAsStringAsync().Result | ConvertFrom-Json
	$all = @($versions | Where-Object { $_.gameVersionTypeID -eq 88568 })
	$hit = $all | Where-Object { $_.name -eq $patch } | Select-Object -First 1
	if (-not $hit) { $hit = $all | Sort-Object id -Descending | Select-Object -First 1 }
	if (-not $hit) { throw "CurseForge: no Forever game version (type 88568) found." }
	$script:forever = $hit
	return $hit
}

function Publish-CurseForge([string] $id, [string] $zip, [string] $displayName, [string] $changelog, $relations) {
	$forever = ForeverVersion
	$meta = @{ changelog = $changelog; changelogType = "markdown"; gameVersions = @($forever.id); releaseType = "release"; displayName = $displayName }
	if (@($relations).Count -gt 0) { $meta.relations = @{ projects = @($relations) } }
	$form = New-Object System.Net.Http.MultipartFormDataContent
	$form.Add((New-Object System.Net.Http.StringContent ($meta | ConvertTo-Json -Compress -Depth 5)), "metadata")
	$form.Add((FileContent $zip), "file", [IO.Path]::GetFileName($zip))
	$req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Post), "https://wow.curseforge.com/api/projects/$id/upload-file"
	$req.Headers.Add("X-Api-Token", $cfToken)
	$req.Content = $form
	$res = $client.SendAsync($req).Result
	if (-not $res.IsSuccessStatusCode) { throw "CurseForge upload of $displayName failed: $([int]$res.StatusCode) $($res.Content.ReadAsStringAsync().Result)" }
	Write-Host "CurseForge: uploaded $displayName for game version $($forever.name) (interface $interface)."
}

function Show-Plan([string] $what, [string] $id, [string] $zip, [string] $hash, [string] $changelog, $relations) {
	Write-Host "DRY RUN  CurseForge project $id  <-  $what"
	Write-Host "  file:       $(Split-Path -Leaf $zip) ($([math]::Round((Get-Item $zip).Length / 1KB)) KB)"
	Write-Host "  hash:       $hash"
	Write-Host "  game:       Forever $patch (looked up when uploading)"
	Write-Host "  relations:  $(if (@($relations).Count) { (@($relations) | ForEach-Object { "$($_.slug) ($($_.type))" }) -join ', ' } else { 'none' })"
	Write-Host "  changelog:  $($changelog -replace "`n", "`n              ")"
}

# ---------------------------------------------------------------- CurseForge: the bundle
$bundleRelations = @(
	@{ slug = "auctionator"; type = "optionalDependency" },
	@{ slug = "questiedb"; type = "optionalDependency" }
)
$cfId = TocField "X-Curse-Project-ID"
if ($SkipBundle) {
	Write-Host "CurseForge: bundle skipped (-SkipBundle)."
} elseif ($DryRun) {
	if ($cfId) { Show-Plan "KroolWorldForever-$Version" $cfId $Zip (ZipHash $Zip) $Notes $bundleRelations }
	else { Write-Host "CurseForge: bundle skipped (needs ## X-Curse-Project-ID in the TOC)." }
} elseif (-not $cfId -or -not $cfToken) {
	Write-Host "CurseForge: skipped (needs ## X-Curse-Project-ID in the TOC and CF_API_KEY)."
} else {
	Publish-CurseForge $cfId $Zip "KroolWorldForever-$Version" $Notes $bundleRelations
}

# ---------------------------------------------------------------- CurseForge: the standalones
$entries = @()
if (Test-Path $Manifest) { $entries = @((Get-Content -Raw $Manifest | ConvertFrom-Json).addons | Where-Object { $_.curseId -and -not $_.held }) }
$old = @{}
if (Test-Path $Published) {
	$raw = Get-Content -Raw $Published | ConvertFrom-Json
	if ($raw) { foreach ($p in $raw.PSObject.Properties) { $old[$p.Name] = $p.Value } }
}
$new = @{}
foreach ($k in $old.Keys) { $new[$k] = $old[$k] }
$uploaded = 0
foreach ($e in $entries) {
	$zip = Join-Path $DistDir "$($e.folder)-$Version.zip"
	if (-not (Test-Path $zip)) { throw "$($e.folder): $zip is missing. Build it first (scripts\build.ps1)." }
	$hash = ZipHash $zip
	if (-not $Force -and $old.ContainsKey($e.key) -and $old[$e.key].hash -eq $hash) {
		Write-Host "CurseForge: $($e.folder) unchanged since $($old[$e.key].version); not uploaded."
		continue
	}
	$title = ($e.title -replace '^KW ', '')
	$changelog = FeatureChangelog $title $Notes $Version
	$relations = @($e.relations | Where-Object { $_ } | ForEach-Object { @{ slug = $_.slug; type = $_.type } })
	if ($DryRun) {
		Show-Plan "$($e.folder)-$Version" $e.curseId $zip $hash $changelog $relations
		continue
	}
	if (-not $cfToken) { Write-Host "CurseForge: $($e.folder) skipped (needs CF_API_KEY)."; continue }
	Publish-CurseForge $e.curseId $zip "$($e.folder)-$Version" $changelog $relations
	$new[$e.key] = @{ hash = $hash; version = $Version }
	$uploaded++
}
if ($DryRun) {
	Write-Host "DRY RUN: nothing uploaded, standalone\published.json not written."
} elseif ($uploaded -gt 0) {
	$ordered = [ordered]@{}
	foreach ($k in ($new.Keys | Sort-Object)) { $ordered[$k] = [ordered]@{ hash = $new[$k].hash; version = $new[$k].version } }
	[IO.File]::WriteAllText($Published, (($ordered | ConvertTo-Json -Depth 4) + "`n"), $utf8)
	Write-Host "Recorded $uploaded standalone upload(s) in $Published."
}

# ---------------------------------------------------------------- Wago
$wagoId = TocField "X-Wago-ID"
$wagoToken = EnvToken "WAGO_API_TOKEN"
if ($SkipBundle) {
	Write-Host "Wago: skipped (-SkipBundle)."
} elseif ($DryRun) {
	Write-Host "DRY RUN: Wago $(if ($wagoId) { "project $wagoId would get $Version" } else { 'skipped (no ## X-Wago-ID)' })."
} elseif (-not $wagoId -or -not $wagoToken) {
	Write-Host "Wago: skipped (needs ## X-Wago-ID in the TOC and WAGO_API_TOKEN)."
} else {
	$form = New-Object System.Net.Http.MultipartFormDataContent
	$form.Add((New-Object System.Net.Http.StringContent $Version), "label")
	$form.Add((New-Object System.Net.Http.StringContent "stable"), "stability")
	$form.Add((New-Object System.Net.Http.StringContent $Notes), "changelog")
	$form.Add((New-Object System.Net.Http.StringContent $patch), "supported_forever_patches[]")
	$form.Add((FileContent $Zip), "file", [IO.Path]::GetFileName($Zip))
	$req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Post), "https://addons.wago.io/api/projects/$wagoId/version"
	$req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue "Bearer", $wagoToken
	$req.Content = $form
	$res = $client.SendAsync($req).Result
	if (-not $res.IsSuccessStatusCode) { throw "Wago upload failed: $([int]$res.StatusCode) $($res.Content.ReadAsStringAsync().Result)" }
	Write-Host "Wago: uploaded $Version for Forever $patch."
}
