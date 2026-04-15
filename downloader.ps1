# downloader.ps1 (BOOTSTRAP)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# עדכן את הכתובת ל-Raw URL של ה-payload שלך ב-GitHub
$realScriptUrl = 'https://raw.githubusercontent.com/8shai7/Office-Downloader/main/odt_payload.ps1'

Write-Host "[BOOT] Downloading high-speed payload..." -ForegroundColor Gray

try {
    $code = (Invoke-WebRequest -Uri $realScriptUrl -UseBasicParsing).Content
    $sb = [ScriptBlock]::Create($code)
    & $sb
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
