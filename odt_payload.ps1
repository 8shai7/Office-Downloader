# odt_payload.ps1
# VERSION: 3.0 (The "Original Scraper" Hybrid)
# Optimized for Shai Tal - Developer/Instructor
# Combination of original scraping logic and high-speed streaming installation.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Start-OfficeODTInteractive {

    function Say {
        param([AllowEmptyString()][string]$m = "", [ConsoleColor]$c = [ConsoleColor]::White)
        try { Write-Host $m -ForegroundColor $c } catch { Write-Output $m }
    }

    function Ask {
        param([Parameter(Mandatory)][string]$p)
        Say $p Cyan
        return Read-Host "> "
    }

    function Read-Choice {
        param([string]$p, [hashtable]$o, [string]$d = $null)
        Say "" White; Say $p White
        foreach ($k in ($o.Keys | Sort-Object)) {
            $l = $o[$k]
            if ($d -and $k -eq $d) { Say ("  [{0}] {1} (default)" -f $k, $l) DarkGray }
            else { Say ("  [{0}] {1}" -f $k, $l) Gray }
        }
        while ($true) {
            $in = Ask "Select"
            if ([string]::IsNullOrWhiteSpace($in) -and $d) { return $d }
            if ($o.ContainsKey($in)) { return $in }
            Say "Invalid selection." Yellow
        }
    }

    function Get-ODTDownloadUrl {
        # הלינק והלוגיקה המקורית מהקובץ הראשון שלך
        $detailsUrl = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
        $fallback   = "https://aka.ms/ODT"
        $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        try {
            Say "Scraping Microsoft Download Center (Original Method)..." Yellow
            $resp = Invoke-WebRequest -Uri $detailsUrl -UseBasicParsing -Headers @{ "Cache-Control"="no-cache"; "User-Agent"=$ua }
            
            # הרג'קס המקורי שלך
            $re = '"url"\s*:\s*"(https://download\.microsoft\.com/download/[^"]+officedeploymenttool[^"]+\.exe)"'
            if ($resp.Content -match $re) { return $Matches[1] }
            
            $re2 = '(https://download\.microsoft\.com/download/[^"\s]+officedeploymenttool[^"\s]+\.exe)'
            $m = [regex]::Match($resp.Content, $re2)
            if ($m.Success) { return $m.Groups[1].Value }
            
            return $fallback
        } catch {
            return $fallback
        }
    }

    function Invoke-ExeNoExitCodeAssumption {
        param([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory = $null)
        if (-not (Test-Path $FilePath)) { throw "Error: $FilePath not found." }
        
        # וידוא שמדובר ב-EXE תקין
        $fs = New-Object System.IO.FileStream($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $b = New-Object byte[] 2; $fs.Read($b, 0, 2) | Out-Null; $fs.Close()
        if ($b[0] -ne 0x4D -or $b[1] -ne 0x5A) {
            throw "The downloaded file is NOT a valid executable (Header Check Failed)."
        }

        $old = Get-Location
        try {
            if ($WorkingDirectory) { Set-Location $WorkingDirectory }
            $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -WindowStyle Hidden
            $p.WaitForExit()
        } finally { Set-Location $old }
    }

    Say "--- Office ODT High-Speed Installer (v3.0) ---" Green
    
    $base = Join-Path $env:TEMP ("ODT_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    $odtExtract = Join-Path $base "ODT"
    New-Item -ItemType Directory -Path $odtExtract, $sourcePath -Force | Out-Null
    $odtExe = Join-Path $base "odt_setup.exe"
    
    # שלב ההורדה
    $downloadUrl = Get-ODTDownloadUrl
    Say "Downloading from: $($downloadUrl.Substring(0, 50))..." Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $odtExe -UseBasicParsing -UserAgent "Mozilla/5.0"

    Say "Extracting ODT..." Yellow
    Invoke-ExeNoExitCodeAssumption -FilePath $odtExe -Arguments @("/quiet", ("/extract:$odtExtract"))
    
    $setupExe = (Get-ChildItem -Path $odtExtract -Filter "setup.exe" -File -Recurse | Select-Object -First 1).FullName

    # --- תהליך בחירת מוצר (המרה ל-Streaming מהיר) ---
    $productOptions = @{ "1"="M365 Apps"; "2"="Office 2024 LTSC Pro"; "3"="Office 2024 LTSC Std" }
    $productChoice = Read-Choice "Product:" $productOptions "1"
    $productId = switch($productChoice){"1"{"O365ProPlusRetail"}"2"{"ProPlus2024Volume"}"3"{"Standard2024Volume"}}

    $arch = if ((Read-Choice "Arch:" @{"1"="64-bit";"2"="32-bit"} "1") -eq "2") { "32" } else { "64" }
    $lang = (Ask "Language (e.g. en-us, he-il) [Default: en-us]").Trim(); if (!$lang) { $lang = "en-us" }

$configPath = Join-Path $base "configuration.xml"
    $xml = @"
<Configuration>
  <Add OfficeClientEdition="$arch" Channel="Current">
    <Product ID="$productId">
      <Language ID="$lang" />
    </Product>
  </Add>
  <Display Level="Full" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="SharedComputerLicensing" Value="0" />
</Configuration>
"@
    $xml | Out-File -FilePath $configPath -Encoding UTF8

    # האופטימיזציה למהירות: הורדה והתקנה במקביל
    Say "Starting High-Speed Installation (Streaming Mode)..." Green
    Invoke-ExeNoExitCodeAssumption -FilePath $setupExe -Arguments @("/configure", $configPath) -WorkingDirectory $odtExtract

    Say "Success! Workflow complete. Temp files: $base" Green
}

Start-OfficeODTInteractive
