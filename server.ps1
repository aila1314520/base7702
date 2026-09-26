$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$page = Join-Path $root "index.html"
$port = 8765
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)

if (-not (Test-Path -LiteralPath $page)) {
    Write-Host "Missing index.html"
    exit 1
}

try {
    $listener.Start()
    Start-Process "http://127.0.0.1:$port/"
    Write-Host "Base wallet recovery page is running at http://127.0.0.1:$port/"
    Write-Host "Keep this window open. Close it after the recovery is finished."

    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $buffer = New-Object byte[] 8192
            $request = ""

            while ($request.IndexOf("`r`n`r`n") -lt 0) {
                $count = $stream.Read($buffer, 0, $buffer.Length)
                if ($count -le 0) { break }
                $request += [System.Text.Encoding]::ASCII.GetString($buffer, 0, $count)
                if ($request.Length -gt 65536) { break }
            }

            $body = [System.IO.File]::ReadAllBytes($page)
            $headers = "HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($body, 0, $body.Length)
            $stream.Flush()
        }
        finally {
            $client.Close()
        }
    }
}
catch {
    Write-Host $_.Exception.Message
    exit 1
}
finally {
    $listener.Stop()
}
