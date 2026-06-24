#Requires -Version 5.1
<#
.SYNOPSIS
  Ejecuta Voxel Truck en Windows (escritorio). Sin problemas de CORS.
#>
param(
    [string]$ApiUrl = $(if ($env:VOXEL_TRUCK_API_URL) { $env:VOXEL_TRUCK_API_URL } else { 'https://aghbackend.onrender.com' }),
    [string]$ApiToken = $(if ($env:VOXEL_TRUCK_API_TOKEN) { $env:VOXEL_TRUCK_API_TOKEN } else { 'token_cliente_001_empresa_prueba_2024' }),
    [string]$ClientId = $(if ($env:VOXEL_TRUCK_CLIENT_ID) { $env:VOXEL_TRUCK_CLIENT_ID } else { '1' })
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot

function Test-DeveloperMode {
    $key = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
        -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue
    return $key.AllowDevelopmentWithoutDevLicense -eq 1
}

if (-not (Test-DeveloperMode)) {
    Write-Host 'ERR Flutter en Windows necesita "Modo de desarrollador" (symlinks).' -ForegroundColor Red
    Write-Host '    1. Abrí Configuración > Privacidad y seguridad > Para desarrolladores'
    Write-Host '    2. Activá "Modo de desarrollador"'
    Write-Host '    3. Reiniciá la terminal y volvé a ejecutar este script'
    Write-Host ''
    Write-Host '    Abriendo configuración...' -ForegroundColor Yellow
    Start-Process 'ms-settings:developers'
    exit 1
}

$machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$user = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machine;$user"

function Find-FlutterExe {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
        "$env:USERPROFILE\flutter\bin\flutter.bat",
        'C:\src\flutter\bin\flutter.bat',
        'C:\flutter\bin\flutter.bat'
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

$flutterExe = Find-FlutterExe
if (-not $flutterExe) {
    Write-Host 'ERR Flutter no está en el PATH.' -ForegroundColor Red
    exit 1
}

Write-Host "    Flutter:   $flutterExe" -ForegroundColor DarkGray
Write-Host '==> Windows con API directa' -ForegroundColor Cyan
Write-Host "    URL:       $ApiUrl"
Write-Host "    Client ID: $ClientId"
Write-Host "    Token:     $($ApiToken.Substring(0, [Math]::Min(12, $ApiToken.Length)))..." -ForegroundColor DarkGray

$doctorOutput = & $flutterExe doctor -v 2>&1 | Out-String
if ($doctorOutput -match 'Visual Studio is missing necessary components') {
    Write-Host ''
    Write-Host 'ERR Falta Visual Studio con C++ para compilar apps de escritorio.' -ForegroundColor Red
    Write-Host '    Instalá Visual Studio 2022 Community (gratis):' -ForegroundColor Yellow
    Write-Host '    https://visualstudio.microsoft.com/es/downloads/'
    Write-Host ''
    Write-Host '    En el instalador, marcá el workload:' -ForegroundColor Yellow
    Write-Host '    "Desarrollo para el escritorio con C++"'
    Write-Host ''
    Write-Host '    Incluí estos componentes (si no vienen por defecto):'
    Write-Host '    - MSVC v142 (o más nuevo) build tools'
    Write-Host '    - C++ CMake tools for Windows'
    Write-Host '    - Windows 10/11 SDK'
    Write-Host ''
    Write-Host '    Mientras tanto, usá Chrome:' -ForegroundColor Cyan
    Write-Host '    .\scripts\run-chrome.ps1'
    exit 1
}

& $flutterExe run -d windows `
    --dart-define=VOXEL_TRUCK_API_URL=$ApiUrl `
    --dart-define=VOXEL_TRUCK_API_TOKEN=$ApiToken `
    --dart-define=VOXEL_TRUCK_CLIENT_ID=$ClientId
