#Requires -Version 5.1
<#
.SYNOPSIS
  Ejecuta Voxel Truck en Chrome con el backend configurado.

.EXAMPLE
  .\scripts\run-chrome.ps1
#>
param(
    [string]$ApiUrl = $(if ($env:VOXEL_TRUCK_API_URL) { $env:VOXEL_TRUCK_API_URL } else { 'https://aghbackend.onrender.com' }),
    [string]$ApiToken = $(if ($env:VOXEL_TRUCK_API_TOKEN) { $env:VOXEL_TRUCK_API_TOKEN } else { 'token_cliente_001_empresa_prueba_2024' }),
    [string]$ClientId = $(if ($env:VOXEL_TRUCK_CLIENT_ID) { $env:VOXEL_TRUCK_CLIENT_ID } else { '1' })
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot

$machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$user = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machine;$user"

Write-Host '==> Chrome con API Voxel Cam' -ForegroundColor Cyan
Write-Host "    URL:       $ApiUrl"
Write-Host "    Client ID: $ClientId"
Write-Host "    Token:     $($ApiToken.Substring(0, [Math]::Min(12, $ApiToken.Length)))..." -ForegroundColor DarkGray

flutter run -d chrome `
    --dart-define=VOXEL_TRUCK_API_URL=$ApiUrl `
    --dart-define=VOXEL_TRUCK_API_TOKEN=$ApiToken `
    --dart-define=VOXEL_TRUCK_CLIENT_ID=$ClientId
