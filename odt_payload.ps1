# odt_payload.ps1
# Office ODT High-Speed Interactive Installer (Fixed BITS Error)

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
        $old = Get-Location
        try {
            if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
            $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -WindowStyle Hidden
            $p.WaitForExit()
        } finally { Set-Location $old }
    }

    Say "--- Office ODT High-Speed Installer ---" Green
    
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { Say "WARNING: Not running as Administrator. Installation will likely fail." Yellow }

    $base = Join-Path $env:TEMP ("ODT_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    $odtExtract = Join-Path $base "ODT"
    $sourcePath = Join-Path $base "OfficeSource"
    New-Item -ItemType Directory -Path $odtExtract, $sourcePath -Force | Out-Null

    # תיקון: שימוש ב-Invoke-WebRequest במקום BITS עבור הקישור הדינמי
    $odtExe = Join-Path $base "odt_setup.exe"
    Say "Downloading ODT Engine..." Yellow
    Invoke-WebRequest -Uri "https://aka.ms/ODT" -OutFile $odtExe -UseBasicParsing

    Say "Extracting ODT..." Yellow
    Invoke-ExeNoExitCodeAssumption -FilePath $odtExe -Arguments @("/quiet", ("/extract:{0}" -f $odtExtract))
    
    $setupExe = (Get-ChildItem -Path $odtExtract -Filter "setup.exe" -File -Recurse | Select-Object -First 1).FullName

    # --- אפשרויות אינטראקטיביות ---
    $productOptions = @{
        "1" = "Microsoft 365 Apps for enterprise"
        "2" = "Office LTSC Professional Plus 2024"
        "3" = "Office LTSC Standard 2024"
        "4" = "Visio LTSC Professional 2024"
        "5" = "Project LTSC Professional 2024"
    }
    $productChoice = Read-Choice -Prompt "Choose Product:" -Options $productOptions -DefaultKey "1"
    $productId = switch($productChoice){"1"{"O365ProPlusRetail"}"2"{"ProPlus2024Volume"}"3"{"Standard2024Volume"}"4"{"VisioPro2024Volume"}"5"{"ProjectPro2024Volume"}}

    $arch = if ((Read-Choice "Architecture:" @{"1"="64-bit";"2"="32-bit"} "1") -eq "2") { "32" } else { "64" }
    $lang = (Ask "Language (e.g. en-us, he-il) [Default: en-us]").Trim(); if (!$lang) { $lang = "en-us" }

    $channel = "Current"
    if ($productId -eq "O365ProPlusRetail") {
        $channelChoice = Read-Choice "Update Channel:" @{"1"="Current";"2"="MonthlyEnterprise";"3"="SemiAnnual";"4"="Beta"} "1"
        $channel = switch($channelChoice){"1"{"Current"}"2"{"MonthlyEnterprise"}"3"{"SemiAnnual"}"4"{"Beta"}}
    } else { $channel = "PerpetualVL2024" }

    $verIn = Ask "Exact Version build (leave blank for latest)"
    $shared = if ($productId -eq "O365ProPlusRetail") { Read-YesNo "Enable SharedComputerLicensing (RDS/VDI)?" $false } else { $false }

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

    Say "Starting Installation (Streaming Mode - Fastest)..." Green
    Invoke-ExeNoExitCodeAssumption -FilePath $setupExe -Arguments @("/configure", $configPath) -WorkingDirectory $odtExtract

    Say "Done! Temp folder: $base" Green
}

Start-OfficeODTInteractive
