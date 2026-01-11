# downloader.ps1 (BOOTSTRAP)
# This file is designed to be executed via: irm <url> | iex
# It downloads the real script and runs it reliably.

$ErrorActionPreference = 'Stop'

# Always use TLS 1.2+ on Windows PowerShell (harmless on PS7)
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Out-Now {
    param([string]$m)
    Write-Output $m
    try { [Console]::Out.Flush() } catch {}
}

Out-Now "[BOOT] Office Downloader bootstrap starting..."

# CHANGE THIS to match where you place the real script in your repo:
$realScriptUrl = 'https://raw.githubusercontent.com/8shai7/Office-Downloader/main/odt_payload.ps1'

try {
    # Use Invoke-WebRequest to avoid some irm/proxy weirdness
    $resp = Invoke-WebRequest -Uri $realScriptUrl -UseBasicParsing -Headers @{ 'Cache-Control'='no-cache'; 'Pragma'='no-cache'; 'User-Agent'='PowerShell' }
    $code = [string]$resp.Content

    Out-Now ("[BOOT] Downloaded payload chars: {0}" -f $code.Length)

    if ($code.Length -lt 200) { throw "Payload too short/empty. Check URL or network filtering." }
    if ($code -match '^\s*<') { throw "Got HTML instead of PowerShell. Check the raw URL." }

    # Most compatible execution method (prevents ':' parsing issues)
    $sb = [ScriptBlock]::Create($code)
    & $sb
}
catch {
    Out-Now "[BOOT] ERROR:"
    Out-Now $_.Exception.Message
    throw
}
