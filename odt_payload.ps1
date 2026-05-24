# odt_payload.ps1
# VERSION: 3.4 (The "Reference Fix" Edition)
# Optimized for Shai Tal - Developer/Instructor

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
        $detailsUrl = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
        $fallback   = "https://aka.ms/ODT"
        $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        try {
            Say "Scraping Microsoft Download Center..." Yellow
            $resp = Invoke-WebRequest -Uri $detailsUrl -UseBasicParsing -Headers @{ "Cache-Control"="no-cache"; "User-Agent"=$ua }
            $re = '"url"\s*:\s*"(https://download\.microsoft\.com/download/[^"]+officedeploymenttool[^"]+\.exe)"'
            if ($resp.Content -match $re) { return $Matches[1] }
            return $fallback
        } catch { return $fallback }
    }

    function Invoke-ExeSecure {
        param([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory = $null)
        if (-not (Test-Path $FilePath)) { throw "Error: $FilePath not found." }
        
        Unblock-File -Path $FilePath -ErrorAction SilentlyContinue

        $old = Get-Location
        try {
            if ($WorkingDirectory) { Set-Location $WorkingDirectory }
            $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -Wait
            return $p.ExitCode
        } finally { Set-Location $old }
    }

    Say "--- Office ODT High-Speed Installer (v3.4) ---" Green
    
    $base = Join-Path $env:TEMP ("ODT_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    $odtExtract = Join-Path $base "ODT"
    New-Item -ItemType Directory -Path $odtExtract -Force | Out-Null
    $odtExe = Join-Path $base "odt_setup.exe"
    
    $downloadUrl = Get-ODTDownloadUrl
    Say "Downloading ODT engine..." Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $odtExe -UseBasicParsing -UserAgent "Mozilla/5.0"

    Say "Extracting ODT..." Yellow
    Invoke-ExeSecure -FilePath $odtExe -Arguments @("/quiet", "/extract:`"$odtExtract`"")
    
    $setupExe = (Get-ChildItem -Path $odtExtract -Filter "setup.exe" -File -Recurse | Select-Object -First 1).FullName

    # --- Configuration Phase ---
    $productOptions = @{ "1"="M365 Apps"; "2"="Office 2024 LTSC Pro"; "3"="Office 2024 LTSC Std" }
    $productChoice = Read-Choice "Product Suite:" $productOptions "1"
    
    $productId = switch($productChoice){"1"{"O365ProPlusRetail"}"2"{"ProPlus2024Volume"}"3"{"Standard2024Volume"}}
    $channel = if ($productChoice -eq "1") { "Current" } else { "PerpetualVL2024" }

    $arch = if ((Read-Choice "Arch:" @{"1"="64-bit";"2"="32-bit"} "1") -eq "2") { "32" } else { "64" }

    while ($true) {
        $lang = (Ask "Language (e.g. en-us, he-il) [Default: en-us]").Trim()
        if (!$lang) {
            $lang = "en-us"
            break
        }
        if ($lang -match '^[a-zA-Z0-9\-]+$') {
            break
        }
        Say "Invalid language format. Only alphanumeric characters and hyphens are allowed (no spaces, quotes, etc)." Yellow
    }

    # --- App Selection Logic ---
    $appSelection = Read-Choice "Install Scope:" @{"1"="Full Suite (All Apps)"; "2"="Custom Selection"} "1"
    $exclusions = ""
    if ($appSelection -eq "2") {
        $allApps = @("Access", "Excel", "Groove", "Lync", "OneDrive", "OneNote", "Outlook", "PowerPoint", "Publisher", "Teams", "Word")
        Say "Enter numbers to INCLUDE (e.g. 2,8,11):" Yellow
        for ($i=0; $i -lt $allApps.Count; $i++) { Say ("  [$($i+1)] $($allApps[$i])") Gray }
        
        $inputRaw = Ask "Apps to INCLUDE"
        $chosenIdx = $inputRaw.Split(',') | ForEach-Object { 
            $v = 0 # FIX: Pre-initialize variable for [ref]
            if ([int]::TryParse($_.Trim(), [ref]$v)) { $v - 1 } 
        }
        
        for ($i=0; $i -lt $allApps.Count; $i++) {
            if ($i -notin $chosenIdx) {
                $exclusions += "`n      <ExcludeApp ID=""$($allApps[$i])"" />"
            }
        }
    }

    $configPath = Join-Path $base "configuration.xml"
    $xml = @"
<Configuration>
  <Add OfficeClientEdition="$arch" Channel="$channel">
    <Product ID="$productId">
      <Language ID="$lang" />$exclusions
    </Product>
  </Add>
  <Display Level="Full" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="SharedComputerLicensing" Value="0" />
</Configuration>
"@
    $xml | Out-File -FilePath $configPath -Encoding UTF8

    if (Test-Path $configPath) {
        Say "Starting High-Speed Installation (Streaming Mode)..." Green
        $argList = @("/configure", "`"$configPath`"")
        Invoke-ExeSecure -FilePath $setupExe -Arguments $argList -WorkingDirectory $odtExtract
        
        Say "Success! Workflow complete." Green
    } else {
        Say "Critical Error: Configuration file could not be generated." Red
    }

    Say "Cleaning up temporary files..." Gray
    Remove-Item -Path $base -Recurse -Force -ErrorAction SilentlyContinue
}

Start-OfficeODTInteractive
