#Requires -Version 5.1
<#
.SYNOPSIS
  Baut den TeamLink Windows MSIX-Installer.
.DESCRIPTION
  Voraussetzungen:
    - Flutter SDK im PATH
    - Windows SDK (für signtool) — optional, nur bei Code-Signing
  Ausgabe: desktop-client\build\windows\runner\Release\desktop_client.msix
#>
param(
  [string]$Version = '1.0.0.0',
  [string]$CertPath = '',
  [string]$CertPassword = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$client = Join-Path $root 'desktop-client'

Push-Location $client
try {
  Write-Host '==> flutter pub get'
  flutter pub get

  Write-Host '==> flutter build windows --release'
  flutter build windows --release

  Write-Host '==> dart run msix:create'
  if ($Version -ne '1.0.0.0') {
    dart run msix:create --msix-version $Version
  } else {
    dart run msix:create
  }

  $msix = Get-ChildItem -Path 'build\windows' -Recurse -Filter '*.msix' | Select-Object -First 1
  if (-not $msix) {
    Write-Error 'MSIX nicht gefunden — Build fehlgeschlagen.'
    exit 1
  }

  $out = Join-Path $root 'dist'
  New-Item -ItemType Directory -Force -Path $out | Out-Null

  $dest = Join-Path $out 'TeamLink-Windows.msix'
  Copy-Item $msix.FullName $dest -Force
  Write-Host "==> Installer: $dest"
} finally {
  Pop-Location
}
