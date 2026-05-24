# downloader.ps1 (BOOTSTRAP WITH CACHE BUSTER)
# V2.3
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# יצירת מחרוזת זמן כדי למנוע טעינה מה-Cache
$cacheBuster = Get-Date -Format "yyyyMMddHHmmss"
$realScriptUrl = "https://raw.githubusercontent.com/8shai7/Office-Downloader/main/odt_payload.ps1?v=$cacheBuster"

Write-Host "[BOOT] Fetching FRESH payload (v=$cacheBuster)..." -ForegroundColor Gray

try {
    # שימוש ב-Header של Cache-Control ליתר ביטחון
    $resp = Invoke-WebRequest -Uri $realScriptUrl -Headers @{'Cache-Control'='no-cache'}
    $code = $resp.Content
    
    $sb = [ScriptBlock]::Create($code)
    & $sb
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
