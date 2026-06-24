#Requires -Version 5.1
<#
.SYNOPSIS
  Ejecuta Voxel Truck en Chrome con el backend configurado.

.EXAMPLE
  .\scripts\run-chrome.ps1

.EXAMPLE
  .\scripts\run-chrome.ps1 -UseProxy
#>
param(
    [string]$ApiUrl = $(if ($env:VOXEL_TRUCK_API_URL) { $env:VOXEL_TRUCK_API_URL } else { 'https://aghbackend.onrender.com' }),
    [string]$ApiToken = $(if ($env:VOXEL_TRUCK_API_TOKEN) { $env:VOXEL_TRUCK_API_TOKEN } else { 'token_cliente_001_empresa_prueba_2024' }),
    [string]$ClientId = $(if ($env:VOXEL_TRUCK_CLIENT_ID) { $env:VOXEL_TRUCK_CLIENT_ID } else { '1' }),
    [switch]$UseProxy
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot

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

function Get-CurlStatusCode([string]$Url, [hashtable]$Headers, [string]$Method = 'GET', [string]$Body = $null, [int]$TimeoutSec = 90) {
    $curlArgs = @(
        '-s', '-m', $TimeoutSec, '-w', '%{http_code}', '-o', 'NUL',
        '-X', $Method,
        $Url
    )
    foreach ($key in $Headers.Keys) {
        $curlArgs += @('-H', "${key}: $($Headers[$key])")
    }
    if ($Body) {
        $curlArgs += @('-H', 'Content-Type: application/json', '-d', $Body)
    }
    $output = & curl.exe @curlArgs 2>$null
    return [string]$output
}

function Wake-RenderBackend([string]$BaseUrl, [string]$Token, [string]$ClientIdValue) {
    $url = "$BaseUrl/api/voxel-truck/camiones?client_id=$ClientIdValue"
    $headers = @{ Authorization = "Bearer $Token" }

    Write-Host '    Backend:   verificando conexión...' -ForegroundColor DarkGray

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $status = Get-CurlStatusCode -Url $url -Headers $headers -TimeoutSec 90
        if ($status -eq '200') {
            Write-Host '    Backend:   en línea' -ForegroundColor DarkGray
            return $true
        }
        if ($attempt -lt 3) {
            Write-Host "    Backend:   intento $attempt/3 ($status), reintentando..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

function Test-BackendCors([string]$BaseUrl) {
    $curlArgs = @(
        '-s', '-m', '20', '-i', '-X', 'OPTIONS',
        "$BaseUrl/api/voxel-truck/camiones",
        '-H', 'Origin: http://127.0.0.1:7357',
        '-H', 'Access-Control-Request-Method: GET',
        '-H', 'Access-Control-Request-Headers: authorization,content-type,accept'
    )
    $output = (& curl.exe @curlArgs 2>$null) -join "`n"
    return $output -match 'Access-Control-Allow-Origin' -and $output -notmatch 'Disallowed CORS'
}

function Stop-PortListeners([int]$Port) {
    Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.OwningProcess -gt 4) {
                Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
}

$flutterExe = Find-FlutterExe
if (-not $flutterExe) {
    Write-Host 'ERR Flutter no está en el PATH.' -ForegroundColor Red
    exit 1
}

$webPort = 7357
$webHost = '127.0.0.1'
$webUrl = "http://${webHost}:$webPort"
$proxyPort = 18765
$proxyUrl = "http://${webHost}:$proxyPort"
$proxyScript = Join-Path $PSScriptRoot 'dev-api-proxy.mjs'
$proxyProcess = $null
$apiUrlForApp = $ApiUrl.Trim().TrimEnd('/')

Write-Host "    Flutter:   $flutterExe" -ForegroundColor DarkGray
Write-Host '==> Chrome con API Voxel Truck' -ForegroundColor Cyan
Write-Host "    Backend:   $ApiUrl"
Write-Host "    Client ID: $ClientId"
Write-Host "    App web:   $webUrl" -ForegroundColor DarkGray

if (-not (Wake-RenderBackend -BaseUrl $apiUrlForApp -Token $ApiToken -ClientIdValue $ClientId)) {
    Write-Host 'ERR El backend no respondió.' -ForegroundColor Red
    exit 1
}

$needsProxy = $UseProxy.IsPresent
if (-not $needsProxy) {
    $needsProxy = -not (Test-BackendCors -BaseUrl $apiUrlForApp)
}

if ($needsProxy) {
    Write-Host "    API:       proxy local $proxyUrl" -ForegroundColor Yellow
    Stop-PortListeners -Port $proxyPort

    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        Write-Host 'ERR CORS bloqueado y Node.js no está instalado para el proxy.' -ForegroundColor Red
        exit 1
    }

    $proxyProcess = Start-Process -FilePath $node.Source -ArgumentList @(
        $proxyScript, $apiUrlForApp, $proxyPort
    ) -PassThru -WindowStyle Hidden

    Start-Sleep -Seconds 1
    if ($proxyProcess.HasExited) {
        Write-Host 'ERR El proxy no pudo iniciar.' -ForegroundColor Red
        exit 1
    }

    $probe = Get-CurlStatusCode -Url "$proxyUrl/api/voxel-truck/camiones?client_id=$ClientId" `
        -Headers @{ Authorization = "Bearer $ApiToken" } -TimeoutSec 30
    if ($probe -ne '200') {
        Write-Host "ERR Proxy sin respuesta (HTTP $probe)." -ForegroundColor Red
        Stop-Process -Id $proxyProcess.Id -Force -ErrorAction SilentlyContinue
        exit 1
    }

    $apiUrlForApp = $proxyUrl
} else {
    Write-Host '    API:       directo al backend (sin proxy)' -ForegroundColor DarkGray
}

Write-Host "    API URL:   $apiUrlForApp" -ForegroundColor DarkGray

try {
    & $flutterExe run -d chrome `
        --web-hostname=$webHost `
        --web-port=$webPort `
        --web-launch-url="$webUrl/" `
        "--dart-define=VOXEL_TRUCK_API_URL=$apiUrlForApp" `
        "--dart-define=VOXEL_TRUCK_API_TOKEN=$ApiToken" `
        "--dart-define=VOXEL_TRUCK_CLIENT_ID=$ClientId"
} finally {
    if ($proxyProcess -and -not $proxyProcess.HasExited) {
        Stop-Process -Id $proxyProcess.Id -Force -ErrorAction SilentlyContinue
    }
}
