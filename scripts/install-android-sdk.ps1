#Requires -Version 5.1
<#
.SYNOPSIS
  Instala Java + Android SDK (sin Android Studio) para compilar APKs con Flutter.

.EXAMPLE
  .\scripts\install-android-sdk.ps1
#>
$ErrorActionPreference = "Stop"

function Write-Step($text) {
    Write-Host "`n==> $text" -ForegroundColor Cyan
}

function Write-Ok($text) {
    Write-Host "OK  $text" -ForegroundColor Green
}

function Write-Err($text) {
    Write-Host "ERR $text" -ForegroundColor Red
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Ensure-Java {
    Refresh-Path
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) {
        Write-Ok "Java encontrado: $(java -version 2>&1 | Select-Object -First 1)"
        return
    }

    Write-Step "Instalando Java 17 (OpenJDK)"
    winget install --id Microsoft.OpenJDK.17 `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements `
        --disable-interactivity

    Refresh-Path
    $java = Get-Command java -ErrorAction SilentlyContinue
    if (-not $java) {
        $fallback = "C:\Program Files\Microsoft\jdk-17*\bin\java.exe"
        $javaExe = Get-ChildItem $fallback -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($javaExe) {
            $javaHome = Split-Path (Split-Path $javaExe.FullName -Parent) -Parent
            [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
            $env:JAVA_HOME = $javaHome
            $env:Path = "$javaHome\bin;$env:Path"
        }
    }

    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        Write-Err "No se pudo instalar Java. Reiniciá la terminal e intentá de nuevo."
        exit 1
    }

    Write-Ok "Java instalado"
}

function Ensure-CommandLineTools {
    param([string]$SdkRoot)

    $sdkManager = Join-Path $SdkRoot "cmdline-tools\latest\bin\sdkmanager.bat"
    if (Test-Path $sdkManager) {
        Write-Ok "Command-line tools ya instaladas"
        return $sdkManager
    }

    Write-Step "Descargando Android command-line tools"
    $zipUrl = "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
    $tempZip = Join-Path $env:TEMP "android-cmdline-tools.zip"
    $tempExtract = Join-Path $env:TEMP "android-cmdline-tools"

    if (Test-Path $tempExtract) {
        Remove-Item $tempExtract -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null

    Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    $latestDir = Join-Path $SdkRoot "cmdline-tools\latest"
    New-Item -ItemType Directory -Path $latestDir -Force | Out-Null

    $innerTools = Join-Path $tempExtract "cmdline-tools"
    if (-not (Test-Path $innerTools)) {
        Write-Err "Estructura inesperada del ZIP de Android SDK"
        exit 1
    }

    Copy-Item -Path (Join-Path $innerTools "*") -Destination $latestDir -Recurse -Force
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path $sdkManager)) {
        Write-Err "No se encontró sdkmanager después de la instalación"
        exit 1
    }

    Write-Ok "Command-line tools instaladas"
    return $sdkManager
}

function Install-SdkPackageFromZip {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Dest
    )

    if (Test-Path $Dest) {
        Write-Ok "$Name ya instalado"
        return
    }

    Write-Host "  Descargando $Name..."
    $zip = Join-Path $env:TEMP "$Name.zip"
    $extract = Join-Path $env:TEMP "$Name-extract"

    Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing
    if (Test-Path $extract) {
        Remove-Item $extract -Recurse -Force
    }
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    New-Item -ItemType Directory -Path (Split-Path $Dest -Parent) -Force | Out-Null

    $inner = Get-ChildItem $extract -Directory | Select-Object -First 1
    Move-Item $inner.FullName $Dest

    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "$Name instalado"
}

function Install-SdkPackagesDirect {
    param([string]$SdkRoot)

    Write-Step "Instalando paquetes del Android SDK (descarga directa)"
    $base = "https://dl.google.com/android/repository"
    $packages = @(
        @{ Name = "platform-tools"; Url = "$base/platform-tools_r37.0.0-win.zip"; Dest = "$SdkRoot\platform-tools" },
        @{ Name = "platform-35"; Url = "$base/platform-35_r02.zip"; Dest = "$SdkRoot\platforms\android-35" },
        @{ Name = "platform-36"; Url = "$base/platform-36_r02.zip"; Dest = "$SdkRoot\platforms\android-36" },
        @{ Name = "build-tools-36.0.0"; Url = "$base/build-tools_r36_windows.zip"; Dest = "$SdkRoot\build-tools\36.0.0" },
        @{ Name = "build-tools-35.0.1"; Url = "$base/build-tools_r35.0.1_windows.zip"; Dest = "$SdkRoot\build-tools\35.0.1" },
        @{ Name = "build-tools-28.0.3"; Url = "$base/build-tools_r28.0.3-windows.zip"; Dest = "$SdkRoot\build-tools\28.0.3" }
    )

    foreach ($pkg in $packages) {
        Install-SdkPackageFromZip -Name $pkg.Name -Url $pkg.Url -Dest $pkg.Dest
    }

    $licensesDir = Join-Path $SdkRoot "licenses"
    New-Item -ItemType Directory -Path $licensesDir -Force | Out-Null
    @(
        @{ File = "android-sdk-license"; Hash = "24333f8a63b6825ea9c5514f83c2829b004d1fee" },
        @{ File = "android-sdk-preview-license"; Hash = "84831b9409646a918e30573bab044c4d0ba9605f" }
    ) | ForEach-Object {
        $path = Join-Path $licensesDir $_.File
        if (-not (Test-Path $path)) {
            Set-Content -Path $path -Value $_.Hash -NoNewline
        }
    }
}

function Configure-Environment {
    param([string]$SdkRoot)

    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $SdkRoot, "User")
    [Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $SdkRoot, "User")

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathsToAdd = @(
        "$SdkRoot\platform-tools",
        "$SdkRoot\cmdline-tools\latest\bin"
    )

    foreach ($entry in $pathsToAdd) {
        if ($userPath -notlike "*$entry*") {
            $userPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $entry } else { "$userPath;$entry" }
        }
    }

    [Environment]::SetEnvironmentVariable("Path", $userPath, "User")
    $env:ANDROID_HOME = $SdkRoot
    $env:ANDROID_SDK_ROOT = $SdkRoot
    Refresh-Path

    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) {
        flutter config --android-sdk $SdkRoot | Out-Null
        Write-Ok "Flutter configurado con ANDROID_SDK=$SdkRoot"
    }
}

Refresh-Path
$sdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
New-Item -ItemType Directory -Path $sdkRoot -Force | Out-Null

Ensure-Java
Ensure-CommandLineTools -SdkRoot $sdkRoot | Out-Null
Install-SdkPackagesDirect -SdkRoot $sdkRoot
Configure-Environment -SdkRoot $sdkRoot

Write-Step "Verificando instalación"
flutter doctor -v

Write-Host "`nListo. Ahora podés ejecutar:" -ForegroundColor Green
Write-Host "  .\scripts\build-apk-para-celu.ps1 -ServirEnRed"
