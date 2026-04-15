# odt_payload.ps1
# Office ODT High-Speed Interactive Installer (Anti-Corruption Fix)

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
        if (-not (Test-Path $FilePath)) { throw "Executable not found: $FilePath" }
        
        # בדיקה אם הקובץ ריק או קטן מדי (פחות מ-1MB זה כנראה דף שגיאה)
        if ((Get-Item $FilePath).Length -lt 1MB) {
            throw "Downloaded file is corrupted or not a valid EXE. Please check your internet/firewall."
        }

        $old = Get-Location
        try {
            if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
            $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -WindowStyle Hidden
            $p.WaitForExit()
        } finally { Set-Location $old }
    }

    Say "--- Office ODT High-Speed Installer ---" Green
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { Say "WARNING: Not running as Administrator." Yellow }

    $base = Join-Path $env:TEMP ("ODT_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    $odtExtract = Join-Path $base "ODT"
    $sourcePath = Join-Path $base "OfficeSource"
    New-Item -ItemType Directory -Path $odtExtract, $sourcePath -Force | Out-Null

    $odtExe = Join-Path $base "odt_setup.exe"
    Say "Downloading ODT Engine..." Yellow

    # שימוש ב-UserAgent של דפדפן כדי למנוע חסימות מצד מיקרוסופט
    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    try {
        Invoke-WebRequest -Uri "https://aka.ms/ODT" -OutFile $odtExe -UserAgent $ua -UseBasicParsing
    } catch {
        Say "Primary download failed. Trying fallback..." Yellow
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB4551408F/officedeploymenttool_17328-20162.exe" -OutFile $odtExe -UserAgent $ua -UseBasicParsing
    }

    Say "Extracting ODT..." Yellow
    Invoke-ExeNoExitCodeAssumption -FilePath $odtExe -Arguments @("/quiet", ("/extract:{0}" -f $odtExtract))
    
    $setupExe = (Get-ChildItem -Path $odtExtract -Filter "setup.exe" -File -Recurse | Select-Object -First 1).FullName

    # --- הגדרות מוצר ---
    $productOptions = @{
        "1" = "Microsoft 365 Apps for enterprise"
        "2" = "Office LTSC Professional Plus 2024"
        "3" = "Office LTSC Standard 2024"
    }
    $productChoice = Read-Choice -Prompt "Choose Product:" -Options $productOptions -DefaultKey "1"
    $productId = switch($productChoice){"1"{"O365ProPlusRetail"}"2"{"ProPlus2024Volume"}"3"{"Standard2024Volume"}}

    $arch = if ((Read-Choice "Architecture:" @{"1"="64-bit";"2"="32-bit"} "1") -eq "2") { "32" } else { "64" }
    $lang = (Ask "Language (e.g. en-us, he-il) [Default: en-us]").Trim(); if (!$lang) { $lang = "en-us" }

    # ערוצי עדכון
    $channel = "Current"
    if ($productId -eq "O365ProPlusRetail") {
        $channelChoice = Read-Choice "Update Channel:" @{"1"="Current";"2"="MonthlyEnterprise";"3"="SemiAnnual";"4"="Beta"} "1"
        $channel = switch($channelChoice){"1"{"Current"}"2"{"MonthlyEnterprise"}"3"{"SemiAnnual"}"4"{"Beta"}}
    } else { $channel = "PerpetualVL2024" }

    $verIn = Ask "Exact Version build (leave blank for latest)"
    $shared = if ($productId -eq "O365ProPlusRetail") { Read-YesNo "Enable SharedComputerLicensing (RDS/VDI)?" $false } else { $false }

    # החרגת אפליקציות
    $appList = @("Access","Excel","Groove","Lync","OneDrive","OneNote","Outlook","PowerPoint","Publisher","Teams","Word")
    Say "Exclude Apps (e.g. 1,4,9):" Gray
    for ($i=0; $i -lt $appList.Count; $i++) { Say ("{0,2}) {1}" -f ($i+1), $appList[$i]) Gray }
    $excludeIn = Ask "Exclude"; $excludeXml = ""
    if ($excludeIn) {
        $excludeIn.Split(",") | ForEach-Object {
            $idx = [int]$_.Trim() - 1
            if ($idx -ge 0 -and $idx -lt $appList.Count) { $excludeXml += "      <ExcludeApp ID=`"$($appList[$idx])`" />`n" }
        }
    }

    $configPath = Join-Path $base "configuration.xml"
    $verAttr = if ($verIn) { "Version=`"$verIn`"" } else { "" }
    $sharedAttr = if ($shared) { "<Property Name=`"SharedComputerLicensing`" Value=`"1`" />" } else { "" }

    $xml = @"
<Configuration>
  <Add OfficeClientEdition="$arch" Channel="$channel" SourcePath="$sourcePath" $verAttr>
    <Product ID="$productId">
      <Language ID="$lang" />
$excludeXml    </Product>
  </Add>
  <Display Level="Full" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  $sharedAttr
</Configuration>
"@
    $xml | Out-File -FilePath $configPath -Encoding UTF8

    Say "Starting Installation (Streaming Mode)..." Green
    Invoke-ExeNoExitCodeAssumption -FilePath $setupExe -Arguments @("/configure", $configPath) -WorkingDirectory $odtExtract

    Say "Success! Files and logs are at: $base" Green
}

Start-OfficeODTInteractive
