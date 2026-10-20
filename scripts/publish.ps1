<#
.SYNOPSIS
  Uploads a built zip to CurseForge and Wago Addons. Called by release.ps1 -Publish.

.NOTES
  UNTESTED against the live sites (no project ids or tokens yet). The endpoints and field names
  follow the BigWigs packager (release.sh), which uploads Forever builds today:
    CurseForge  POST https://wow.curseforge.com/api/projects/<id>/upload-file
                header X-Api-Token, multipart "metadata" (JSON) + "file".
                Forever is game version type 88568; the newest version of that type is used.
    Wago        POST https://addons.wago.io/api/projects/<id>/version
                header Authorization: Bearer <token>, multipart label, stability, changelog,
                supported_forever_patches[], file.
  Ids come from the TOC (## X-Curse-Project-ID, ## X-Wago-ID). Tokens come from the user
  environment (CF_API_KEY, WAGO_API_TOKEN) and are never printed.
#>
param(
	[Parameter(Mandatory)] [string] $Zip,
	[Parameter(Mandatory)] [string] $Version,
	[string] $Notes = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http
$repo = Split-Path -Parent $PSScriptRoot
$toc = Join-Path $repo "KroolWorldForever\KroolWorldForever_Forever.toc"

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

$client = New-Object System.Net.Http.HttpClient
$interface = TocField "Interface"
$patch = "1.60.1" # Forever's game version for Interface 16001; update with the client

# ---------------------------------------------------------------- CurseForge
$cfId = TocField "X-Curse-Project-ID"
$cfToken = EnvToken "CF_API_KEY"
if (-not $cfId -or -not $cfToken) {
	Write-Host "CurseForge: skipped (needs ## X-Curse-Project-ID in the TOC and CF_API_KEY)."
} else {
	$req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Get), "https://wow.curseforge.com/api/game/versions"
	$req.Headers.Add("X-Api-Token", $cfToken)
	$versions = $client.SendAsync($req).Result.Content.ReadAsStringAsync().Result | ConvertFrom-Json
	$forever = $versions | Where-Object { $_.gameVersionTypeID -eq 88568 } | Sort-Object id -Descending | Select-Object -First 1
	if (-not $forever) { throw "CurseForge: no Forever game version (type 88568) found." }
	$meta = @{ changelog = $Notes; changelogType = "markdown"; gameVersions = @($forever.id); releaseType = "release"; displayName = "KroolWorldForever-$Version" } | ConvertTo-Json -Compress
	$form = New-Object System.Net.Http.MultipartFormDataContent
	$form.Add((New-Object System.Net.Http.StringContent $meta), "metadata")
	$form.Add((FileContent $Zip), "file", [IO.Path]::GetFileName($Zip))
	$req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Post), "https://wow.curseforge.com/api/projects/$cfId/upload-file"
	$req.Headers.Add("X-Api-Token", $cfToken)
	$req.Content = $form
	$res = $client.SendAsync($req).Result
	if (-not $res.IsSuccessStatusCode) { throw "CurseForge upload failed: $([int]$res.StatusCode) $($res.Content.ReadAsStringAsync().Result)" }
	Write-Host "CurseForge: uploaded for game version $($forever.name) (interface $interface)."
}

# ---------------------------------------------------------------- Wago
$wagoId = TocField "X-Wago-ID"
$wagoToken = EnvToken "WAGO_API_TOKEN"
if (-not $wagoId -or -not $wagoToken) {
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
