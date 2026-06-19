#Requires -Version 5.1
<#
.SYNOPSIS
  Conecta el celular por Wi-Fi para usar "flutter run" sin cable USB.

.DESCRIPTION
  Requiere Android 11+ y depuración inalámbrica activada en el teléfono.
  La primera vez hay que emparejar con código desde:
  Ajustes > Opciones de desarrollador > Depuración inalámbrica > Emparejar dispositivo

.EXAMPLE
  .\scripts\conectar-celu-wifi.ps1 -PairIp 192.168.1.50 -PairPort 37891 -PairCode 123456 -ConnectIp 192.168.1.50 -ConnectPort 43201
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$PairIp,

    [Parameter(Mandatory = $true)]
    [int]$PairPort,

    [Parameter(Mandatory = $true)]
    [string]$PairCode,

    [Parameter(Mandatory = $true)]
    [string]$ConnectIp,

    [Parameter(Mandatory = $true)]
    [int]$ConnectPort
)

$ErrorActionPreference = "Stop"

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Find-Adb {
    $sdk = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        "$env:LOCALAPPDATA\Android\Sdk"
    ) | Where-Object { $_ -and (Test-Path "$_\platform-tools\adb.exe") } | Select-Object -First 1

    if ($sdk) {
        return "$sdk\platform-tools\adb.exe"
    }

    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if ($adb) {
        return $adb.Source
    }

    throw "No se encontró adb.exe. Instalá Android Studio y el Android SDK."
}

Refresh-Path
$adb = Find-Adb

Write-Host "Emparejando dispositivo..." -ForegroundColor Cyan
& $adb pair "$PairIp`:$PairPort" $PairCode

Write-Host "Conectando por Wi-Fi..." -ForegroundColor Cyan
& $adb connect "$ConnectIp`:$ConnectPort"

Write-Host "`nDispositivos detectados:" -ForegroundColor Green
& $adb devices

Write-Host @"

Listo. Ahora podés correr la app sin USB:

  cd $($PSScriptRoot | Split-Path -Parent)
  flutter run

"@
Write-Host "Si se desconecta, repetí el emparejamiento desde el celular." -ForegroundColor Yellow
