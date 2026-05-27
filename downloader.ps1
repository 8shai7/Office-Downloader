# downloader.ps1 (BOOTSTRAP WITH CACHE BUSTER)
# V2.3
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# יצירת מחרוזת זמן כדי למנוע טעינה מה-Cache
$cacheBuster = Get-Date -Format "yyyyMMddHHmmss"
$realScriptUrl = "https://raw.githubusercontent.com/8shai7/Office-Downloader/main/odt_payload.ps1?v=$cacheBuster"

Write-Host "[BOOT] Fetching FRESH payload (v=$cacheBuster)..." -ForegroundColor Gray

try {
    # שימוש ב-Header של Cache-Control ליתר ביטחון
    $resp = Invoke-WebRequest -Uri $realScriptUrl -Headers @{'Cache-Control'='no-cache'}
    $code = $resp.Content
    
    # Payload integrity check
    $expectedHash = "ED5CCD6306FD7BA6F549E579DB252D0EA53300D23E75E5766789BFFEB77B710E"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($code)
    $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
    $computedHashBytes = $hashAlgorithm.ComputeHash($bytes)
    $computedHash = [BitConverter]::ToString($computedHashBytes) -replace "-"

    if ($computedHash -ne $expectedHash) {
        throw "Integrity check failed: Expected hash $expectedHash but got $computedHash"
    }

    $sb = [ScriptBlock]::Create($code)
    & $sb
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
