# odt_payload.ps1
# VERSION: 2.4 (The "Browser-Mimic" Edition)
# Fixed: 404 Error by using resilient redirect handling with Browser UserAgent

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

    function Read-YesNo {
        param([string]$p, [bool]$d = $true)
        $s = if ($d) { "[Y/n]" } else { "[y/N]" }
        while ($true) {
            $in = Ask "$p $s"
            if ([string]::IsNullOrWhiteSpace($in)) { return $d }
            if ($in.ToLower() -match 'y|yes') { return $true }
            if ($in.ToLower() -match 'n|no') { return $false }
            Say "Please answer y or n." Yellow
        }
    }

    function Invoke-ExeNoExitCodeAssumption {
        param([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory = $null)
        if (-not (Test-Path $FilePath)) { throw "Error: $FilePath not found." }
        
        # אימות חתימת EXE (Magic Bytes MZ)
        $fs = New-Object System.IO.FileStream($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $b = New-Object byte[] 2
        $fs.Read($b, 0, 2) | Out-Null
        $fs.Close()

        if ($b[0] -ne 0x4D -or $b[1] -ne 0x5A) {
            Say "DEBUG: File starts with: $([System.Text.Encoding]::ASCII.GetString($b))" Red
            throw "The downloaded file is NOT a valid EXE (Header check failed). Check network filters."
        }

        $old = Get-Location
        try {
            if ($WorkingDirectory) { Set-Location $WorkingDirectory }
            $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -WindowStyle Hidden
            $p.WaitForExit()
        } finally { Set-Location $old }
    }

    Say "--- Office ODT High-Speed Installer (v2.4 - FINAL BYPASS) ---" Green
    
    $base = Join-Path $env:TEMP ("ODT_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    $odtExtract = Join-Path $base "ODT"
    $sourcePath = Join-Path $base "OfficeSource"
    New-Item -ItemType Directory -Path $odtExtract, $sourcePath -Force | Out-Null

    $odtExe = Join-Path $base "odt_setup.exe"
    
    # שימוש ב-UserAgent של Chrome כדי למנוע ממיקרוסופט להגיש דף 404 ל-"בוטים"
    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    Say "Downloading ODT Engine (Redirect-Safe Mode)..." Yellow
    try {
        # ה-aka.ms/ODT תמיד מפנה לגרסה האחרונה. אנחנו נותנים ל-PowerShell לנהל את ה-Redirect.
        Invoke-WebRequest -Uri "https://aka.ms/ODT" -OutFile $odtExe -UserAgent $ua -UseBasicParsing
    } catch {
        Say "Primary download failed. Trying Curl as backup..." Yellow
        & curl.exe -L -A $ua -o $odtExe "https://aka.ms/ODT" 2>$null
    }

    Say "Extracting ODT..." Yellow
    Invoke-ExeNoExitCodeAssumption -FilePath $odtExe -Arguments @("/quiet", ("/extract:$odtExtract"))
    
    $setupExe = (Get-ChildItem -Path $odtExtract -Filter "setup.exe" -File -Recurse | Select-Object -First 1).FullName

    # --- תהליך התקנה ---
    $productOptions = @{ "1"="M365 Apps"; "2"="Office 2024 LTSC Pro"; "3"="Office 2024 LTSC Std" }
    $productChoice = Read-Choice "Product:" $productOptions "1"
    $productId = switch($productChoice){"1"{"O365ProPlusRetail"}"2"{"ProPlus2024Volume"}"3"{"Standard2024Volume"}}

    $arch = if ((Read-Choice "Arch:" @{"1"="64-bit";"2"="32-bit"} "1") -eq "2") { "32" } else { "64" }
    $lang = (Ask "Language (e.g. en-us, he-il) [Default: en-us]").Trim(); if (!$lang) { $lang = "en-us" }

    $configPath = Join-Path $base "configuration.xml"
    $xml = @"
<Configuration>
  <Add OfficeClientEdition="$arch" Channel="Current" SourcePath="$sourcePath">
    <Product ID="$productId">
      <Language ID="$lang" />
    </Product>
  </Add>
  <Display Level="Full" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
</Configuration>
"@
    $xml | Out-File -FilePath $configPath -Encoding UTF8

    Say "Starting High-Speed Installation (Streaming Mode)..." Green
    Invoke-ExeNoExitCodeAssumption -FilePath $setupExe -Arguments @("/configure", $configPath) -WorkingDirectory $odtExtract

    Say "Success! ODT workflow completed. Logs at: $base" Green
}

Start-OfficeODTInteractive
