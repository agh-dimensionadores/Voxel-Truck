#Requires -Version 5.1
<#
.SYNOPSIS
  Proxy local para desarrollo web: reenvía al backend y agrega headers CORS.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetUrl,

    [int]$Port = 8765
)

$target = $TargetUrl.Trim().TrimEnd('/')
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:${Port}/")
$listener.Prefixes.Add("http://localhost:${Port}/")
try {
    $listener.Start()
} catch {
    Write-Host "ERR No se pudo iniciar el proxy en el puerto $Port." -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host "==> Proxy API dev" -ForegroundColor Cyan
Write-Host "    Local:  http://localhost:$Port"
Write-Host "    Remoto: $target"
Write-Host "    Ctrl+C para detener"

function Set-CorsHeaders([System.Net.HttpListenerResponse]$Response) {
    $Response.Headers['Access-Control-Allow-Origin'] = '*'
    $Response.Headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
    $Response.Headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type, Accept'
    $Response.Headers['Access-Control-Max-Age'] = '600'
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    try {
        Set-CorsHeaders $response

        if ($request.HttpMethod -eq 'OPTIONS') {
            $response.StatusCode = 204
            continue
        }

        $forwardUrl = "$target$($request.Url.PathAndQuery)"
        $webRequest = [System.Net.HttpWebRequest]::Create($forwardUrl)
        $webRequest.Method = $request.HttpMethod
        $webRequest.AllowAutoRedirect = $false
        $webRequest.Timeout = 25000
        $webRequest.ReadWriteTimeout = 25000

        $authorization = $request.Headers['Authorization']
        if ($authorization) {
            $webRequest.Headers[[System.Net.HttpRequestHeader]::Authorization] = $authorization
        }

        $accept = $request.Headers['Accept']
        if ($accept) {
            $webRequest.Accept = $accept
        }

        $contentType = $request.ContentType
        if ($contentType) {
            $webRequest.ContentType = $contentType
        }

        if ($request.HttpMethod -in @('POST', 'PUT', 'PATCH')) {
            $reader = New-Object System.IO.StreamReader($request.InputStream)
            $body = $reader.ReadToEnd()
            if ($body.Length -gt 0) {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                $webRequest.ContentLength = $bytes.Length
                $requestStream = $webRequest.GetRequestStream()
                $requestStream.Write($bytes, 0, $bytes.Length)
                $requestStream.Close()
            }
        }

        try {
            $webResponse = $webRequest.GetResponse()
            $response.StatusCode = [int]$webResponse.StatusCode
            if ($webResponse.ContentType) {
                $response.ContentType = $webResponse.ContentType
            }
            $webResponse.GetResponseStream().CopyTo($response.OutputStream)
            $webResponse.Close()
        } catch [System.Net.WebException] {
            $errorResponse = $_.Exception.Response
            if ($errorResponse) {
                $response.StatusCode = [int]$errorResponse.StatusCode
                $errorStream = $errorResponse.GetResponseStream()
                if ($errorStream) {
                    $errorStream.CopyTo($response.OutputStream)
                    $errorStream.Close()
                }
                $errorResponse.Close()
            } else {
                $response.StatusCode = 502
                $message = [System.Text.Encoding]::UTF8.GetBytes($_.Exception.Message)
                $response.OutputStream.Write($message, 0, $message.Length)
            }
        }
    } catch {
        Write-Host "Proxy error: $($_.Exception.Message)" -ForegroundColor Red
        try {
            $response.StatusCode = 500
            $message = [System.Text.Encoding]::UTF8.GetBytes($_.Exception.Message)
            $response.OutputStream.Write($message, 0, $message.Length)
        } catch {
            # ignore secondary failures
        }
    } finally {
        try { $response.Close() } catch { }
    }
}
