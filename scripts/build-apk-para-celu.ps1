#Requires -Version 5.1
<#
.SYNOPSIS
  Compila Voxel Truck como APK para instalar en el celular sin USB.

.DESCRIPTION
  - El Android SDK se instala en la PC (no en el celular).
  - Este script genera un APK y, opcionalmente, lo sirve por Wi-Fi
    para que lo descargues e instales desde el navegador del teléfono.

.EXAMPLE
  .\scripts\build-apk-para-celu.ps1

.EXAMPLE
  .\scripts\build-apk-para-celu.ps1 -ServirEnRed
#>
param(
    [switch]$ServirEnRed,
    [int]$Puerto = 8765
)

$ErrorActionPreference = "Stop"

function Write-Step($text) {
    Write-Host "`n==> $text" -ForegroundColor Cyan
}

function Write-Ok($text) {
    Write-Host "OK  $text" -ForegroundColor Green
}

function Write-Warn($text) {
    Write-Host "!!  $text" -ForegroundColor Yellow
}

function Write-Err($text) {
    Write-Host "ERR $text" -ForegroundColor Red
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
    $env:JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT"
}

function Ensure-AndroidLicenses {
    param([string]$SdkRoot)

    if (-not $SdkRoot) { return }

    $licensesDir = Join-Path $SdkRoot "licenses"
    New-Item -ItemType Directory -Path $licensesDir -Force | Out-Null

    $licenseFiles = @{
        "android-sdk-license" = "24333f8a63b6825ea9c5514f83c2829b004d1fee"
        "android-sdk-preview-license" = "84831b9409646a918e30573bab044c4d0ba9605f"
    }

    foreach ($entry in $licenseFiles.GetEnumerator()) {
        $path = Join-Path $licensesDir $entry.Key
        if (-not (Test-Path $path)) {
            Set-Content -Path $path -Value $entry.Value -NoNewline
        }
    }
}

function Find-AndroidSdk {
    $candidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        "$env:LOCALAPPDATA\Android\Sdk",
        "$env:USERPROFILE\AppData\Local\Android\Sdk",
        "C:\Android\Sdk"
    ) | Where-Object { $_ -and (Test-Path $_) }

    return $candidates | Select-Object -First 1
}

function Ensure-AndroidSdk {
    $sdk = Find-AndroidSdk
    if ($sdk -and (Test-Path "$sdk\platform-tools\adb.exe")) {
        Write-Ok "Android SDK encontrado en: $sdk"
        & flutter config --android-sdk $sdk | Out-Null
        return $sdk
    }

    Write-Err "No se encontró el Android SDK en esta PC."
    Write-Host @"

Instalá el SDK automáticamente con:

  .\scripts\install-android-sdk.ps1

Ese script instala Java + Android SDK en la PC (no en el celular).
Luego volvé a ejecutar este script.

"@
    exit 1
}

function Get-LocalIp {
    $ip = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.PrefixOrigin -ne "WellKnown"
        } |
        Sort-Object InterfaceMetric |
        Select-Object -ExpandProperty IPAddress -First 1

    if (-not $ip) {
        $ip = (Get-NetIPConfiguration |
            Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq "Up" } |
            Select-Object -First 1).IPv4Address.IPAddress
    }

    return $ip
}

function Start-ApkServer {
    param(
        [string]$ApkPath,
        [int]$Port
    )

    $apkName = Split-Path $ApkPath -Leaf
    $apkDir = Split-Path $ApkPath -Parent
    $localIp = Get-LocalIp

    if (-not $localIp) {
        Write-Warn "No se pudo detectar la IP local. Copiá el APK manualmente al celular."
        return
    }

    $url = "http://${localIp}:$Port/$apkName"

    Write-Step "Servidor Wi-Fi para descargar el APK"
    Write-Host @"

  1. Conectá el celular a la MISMA red Wi-Fi que esta PC.
  2. Abrí Chrome en el celular y entrá a:

       $url

  3. Descargá el APK e instalalo.
  4. Si Android lo pide, activá "Instalar apps desconocidas" para Chrome.

  Para detener el servidor: Ctrl+C

"@

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://${localIp}:$Port/")
    try {
        $listener.Start()
    }
    catch {
        Write-Warn "No se pudo iniciar el servidor en $url"
        Write-Host "Motivo: $($_.Exception.Message)"
        Write-Host "Copiá el APK manualmente al celular desde:"
        Write-Host "  $ApkPath"
        return
    }

    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            $requestedFile = [System.IO.Path]::GetFileName($request.Url.LocalPath)
            if ([string]::IsNullOrWhiteSpace($requestedFile) -or $requestedFile -eq "/") {
                $requestedFile = $apkName
            }

            $filePath = Join-Path $apkDir $requestedFile
            if (-not (Test-Path $filePath)) {
                $response.StatusCode = 404
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("Archivo no encontrado")
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.Close()
                continue
            }

            Write-Host "Descarga desde $($request.RemoteEndPoint.Address): $requestedFile"
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentType = "application/vnd.android.package-archive"
            $response.ContentLength64 = $bytes.Length
            $response.AddHeader("Content-Disposition", "attachment; filename=$requestedFile")
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
        }
    }
    finally {
        if ($listener) {
            $listener.Stop()
            $listener.Close()
        }
    }
}

Refresh-Path

$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot

Write-Step "Verificando Flutter"
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Err "Flutter no está en el PATH."
    Write-Host "Instalá Flutter y agregá C:\src\flutter\bin al PATH, luego reintentá."
    exit 1
}
Write-Ok "Flutter: $(flutter --version | Select-Object -First 1)"

Write-Step "Verificando Android SDK (solo en la PC)"
Ensure-AndroidSdk | Out-Null

Write-Step "Verificando licencias de Android"
Ensure-AndroidLicenses -SdkRoot (Find-AndroidSdk)

Write-Step "Instalando dependencias"
flutter pub get

Write-Step "Compilando APK release (puede tardar varios minutos la primera vez)"
flutter build apk --release

$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Err "No se generó el APK en la ruta esperada."
    exit 1
}

$apkSizeMb = [math]::Round((Get-Item $apkPath).Length / 1MB, 1)
Write-Ok "APK generado ($apkSizeMb MB)"
Write-Host "Ruta: $apkPath"

Write-Step "Instalación en el celular SIN USB"
Write-Host @"
Opción A - Por Wi-Fi (recomendada):
  Ejecutá este script con -ServirEnRed y abrí el link en el celular.

Opción B - Manual:
  Enviá el APK al celular (WhatsApp, Drive, email) e instalalo.

En el celular:
  - Activá "Instalar apps desconocidas" si Android lo solicita.
  - No hace falta instalar ningún SDK en el teléfono.

"@

if ($ServirEnRed) {
    Start-ApkServer -ApkPath $apkPath -Port $Puerto
}
else {
    Write-Host "Tip: para descargarlo por Wi-Fi sin cable, ejecutá:"
    Write-Host "  .\scripts\build-apk-para-celu.ps1 -ServirEnRed" -ForegroundColor Yellow
    Invoke-Item (Split-Path $apkPath -Parent)
}
