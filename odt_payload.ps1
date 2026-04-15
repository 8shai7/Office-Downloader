# odt_payload.ps1
# VERSION: 2.3 (The "Direct Hit" Edition)
# Optimized for Shai Tal
# Fix: Using absolute CDN URL to bypass redirection loops

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
        
        # בדיקת Magic Bytes (חתימת EXE) - תואם לכל גרסאות PowerShell
        $fileStream = New-Object System.IO.FileStream($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $bytes = New-Object byte[] 2
        $fileStream.Read($bytes, 0, 2) | Out-Null
        $fileStream.Close()

        if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
            Say "DEBUG: File content starts with: $([System.Text.Encoding]::ASCII.GetString($bytes))" Yellow
            $contentSample = Get-Content $FilePath -TotalCount 5
            Say "DEBUG: First lines of file: $contentSample" Gray
            throw "The downloaded file is NOT a valid Windows executable. It appears to be an HTML or Text file."
        }

        $old = Get-Location
        try {
            if ($WorkingDirectory) { Set-Location $FilePath }
            $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -WindowStyle Hidden
            $p.WaitForExit()
        } finally { Set-Location $old }
    }

    Say "--- Office ODT High-Speed Installer (v2.3 - CDN DIRECT) ---" Green
    
    $base = Join-Path $env:TEMP ("ODT_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    $odtExtract = Join-Path $base "ODT"
    $sourcePath = Join-Path $base "OfficeSource"
    New-Item -ItemType Directory -Path $odtExtract, $sourcePath -Force | Out-Null

    $odtExe = Join-Path $base "odt_setup.exe"
    
    # שימוש בקישור ישיר ל-CDN של מיקרוסופט (עוקף את aka.ms)
    $cdnUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB4551408F/officedeploymenttool_17328-20162.exe"
    
    Say "Fetching ODT Engine from Direct CDN..." Yellow
    & curl.exe -sSL -o $odtExe $cdnUrl 2>$null

    Say "Extracting ODT..." Yellow
    Invoke-ExeNoExitCodeAssumption -FilePath $odtExe -Arguments @("/quiet", ("/extract:$odtExtract"))
    
    $setupExe = (Get-ChildItem -Path $odtExtract -Filter "setup.exe" -File -Recurse | Select-Object -First 1).FullName

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

    Say "Success! All temporary files are in: $base" Green
}

Start-OfficeODTInteractive
