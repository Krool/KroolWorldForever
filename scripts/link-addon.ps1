<#
.SYNOPSIS
  Junctions an addon folder from this repo into a WoW Interface\AddOns folder (no admin needed).

.EXAMPLE
  .\scripts\link-addon.ps1 -Addon HelloForever -AddOnsPath "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns"

.NOTES
  The Forever live folder name is unconfirmed as of 2026-10-20 (beta used _classic_beta_).
  Without -AddOnsPath the script lists candidate flavor folders it finds.
#>
param(
	[Parameter(Mandatory)] [string] $Addon,
	[string] $AddOnsPath,
	[string] $WowRoot = "C:\Program Files (x86)\World of Warcraft"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

$source = @("$repoRoot\addons\$Addon", "$repoRoot\template\$Addon") |
	Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $source) { throw "Addon folder '$Addon' not found under addons\ or template\." }

if (-not $AddOnsPath) {
	if (-not (Test-Path $WowRoot)) { throw "WoW not found at '$WowRoot'. Pass -WowRoot or -AddOnsPath." }
	Write-Host "Flavor folders under ${WowRoot}:"
	Get-ChildItem $WowRoot -Directory | Where-Object Name -like "_*_" | ForEach-Object { "  $($_.FullName)" }
	Write-Host "Re-run with -AddOnsPath '<flavor>\Interface\AddOns'."
	return
}

if (-not (Test-Path $AddOnsPath)) { New-Item -ItemType Directory -Path $AddOnsPath | Out-Null }
$link = Join-Path $AddOnsPath $Addon

if (Test-Path $link) {
	$item = Get-Item $link -Force
	if ($item.LinkType -eq "Junction" -and $item.Target -contains $source) {
		Write-Host "Already linked: $link -> $source"
		return
	}
	throw "'$link' already exists and is not a junction to $source. Remove it manually first."
}

New-Item -ItemType Junction -Path $link -Target $source | Out-Null
Write-Host "Linked: $link -> $source"
Write-Host "Restart the client (not just /reload) the first time so the TOC is picked up."
