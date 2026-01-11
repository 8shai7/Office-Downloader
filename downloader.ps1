# Office ODT interactive downloader/installer
# Designed to run via: irm <url> | iex

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Choice {
    param(
        [Parameter(Mandatory)] [string] $Prompt,
        [Parameter(Mandatory)] [hashtable] $Options,
        [string] $DefaultKey = $null
    )
    Write-Host ""
    Write-Host $Prompt
    foreach ($k in ($Options.Keys | Sort-Object)) {
        $label = $Options[$k]
        if ($DefaultKey -and $k -eq $DefaultKey) {
            Write-Host "  [$k] $label (default)"
        } else {
            Write-Host "  [$k] $label"
        }
    }
    while ($true) {
        $in = Read-Host "Select"
        if ([string]::IsNullOrWhiteSpace($in) -and $DefaultKey) { return $DefaultKey }
        if ($Options.ContainsKey($in)) { return $in }
        Write-Host "Invalid selection. Try again."
    }
}

function Read-YesNo {
    param([Parameter(Mandatory)] [string] $Prompt, [bool] $Default = $true)
    $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }
    while ($true) {
        $in = Read-Host "$Prompt $suffix"
        if ([string]::IsNullOrWhiteSpace($in)) { return $Default }
        switch ($in.ToLowerInvariant()) {
            'y' { return $true }
            'yes' { return $true }
            'n' { return $false }
            'no' { return $false }
            default { Write-Host "Please answer y or n." }
        }
    }
}

function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host ""
        Write-Host "Not running as Administrator."
        Write-Host "Re-launching elevated..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $($MyInvocation.MyCommand.Path) }`""
        $psi.Verb = "runas"
        try { [System.Diagnostics.Process]::Start($psi) | Out-Null } catch { throw "Elevation cancelled. Exiting." }
        exit
    }
}

# NOTE: If you run this via irm|iex there is no script file path to relaunch.
# We'll just warn instead of forcing elevation.
function Warn-IfNotAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host ""
        Write-Host "WARNING: Not running as Administrator."
        Write-Host "ODT download usually works without admin, but installation often requires admin."
        Write-Host "If install fails, rerun PowerShell as Administrator."
    }
}

Warn-IfNotAdmin

# Work folder
$base = Join-Path $env:TEMP ("ODT_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $base | Out-Null

$odtExe  = Join-Path $base "officedeploymenttool.exe"
$odtUrl  = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool.exe"
$odtExtract = Join-Path $base "ODT"
New-Item -ItemType Directory -Path $odtExtract | Out-Null

Write-Host ""
Write-Host "Downloading Office Deployment Tool (ODT)..."
Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing

Write-Host "Extracting ODT..."
# /quiet /extract:<path> works for ODT self-extractor
Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:`"$odtExtract`"" -Wait

$setupExe = Join-Path $odtExtract "setup.exe"
if (-not (Test-Path $setupExe)) {
    throw "ODT extraction failed: setup.exe not found in $odtExtract"
}

# ========= Interactive options =========

# Product selection
$productOptions = @{
    "1" = "Microsoft 365 Apps for enterprise (O365ProPlusRetail)"
    "2" = "Office LTSC Professional Plus 2024 (ProPlus2024Volume)"
    "3" = "Office LTSC Standard 2024 (Standard2024Volume)"
    "4" = "Visio LTSC Professional 2024 (VisioPro2024Volume)"
    "5" = "Project LTSC Professional 2024 (ProjectPro2024Volume)"
}
$productChoice = Read-Choice -Prompt "Choose the Office product:" -Options $productOptions -DefaultKey "1"

$productId = switch ($productChoice) {
    "1" { "O365ProPlusRetail" }
    "2" { "ProPlus2024Volume" }
    "3" { "Standard2024Volume" }
    "4" { "VisioPro2024Volume" }
    "5" { "ProjectPro2024Volume" }
}

# Architecture
$archChoice = Read-Choice -Prompt "Choose architecture:" -Options @{ "1"="64-bit"; "2"="32-bit" } -DefaultKey "1"
$arch = if ($archChoice -eq "2") { "32" } else { "64" }

# Language
$langIn = Read-Host "Language (e.g. en-us, he-il). Leave blank for en-us"
$lang = if ([string]::IsNullOrWhiteSpace($langIn)) { "en-us" } else { $langIn.Trim() }

# Channel (Microsoft 365 Apps)
$channel = "Current"
$channelChoice = $null
if ($productId -eq "O365ProPlusRetail") {
    $channelChoice = Read-Choice -Prompt "Choose update channel:" -Options @{
        "1"="Current"
        "2"="MonthlyEnterprise"
        "3"="SemiAnnual"
        "4"="Beta"
    } -DefaultKey "2"
    $channel = switch ($channelChoice) {
        "1" { "Current" }
        "2" { "MonthlyEnterprise" }
        "3" { "SemiAnnual" }
        "4" { "Beta" }
    }
} else {
    # LTSC/Volume products generally use PerpetualVL2024 channel
    $channel = "PerpetualVL2024"
}

# Exact version/build (optional)
Write-Host ""
Write-Host "Exact Version is optional."
Write-Host "Examples (build numbers vary): 16.0.17xxxx.xxxxx"
$verIn = Read-Host "Enter exact Version build (or leave blank to let ODT pick latest for the channel)"
$version = if ([string]::IsNullOrWhiteSpace($verIn)) { $null } else { $verIn.Trim() }

# Exclude apps selection (Word/Excel/etc.)
$appList = @("Access","Excel","Groove","Lync","OneDrive","OneNote","Outlook","PowerPoint","Publisher","Teams","Word")
Write-Host ""
Write-Host "Select which apps to EXCLUDE."
Write-Host "Type comma-separated numbers to exclude (or blank to exclude nothing)."
for ($i=0; $i -lt $appList.Count; $i++) {
    "{0,2}) {1}" -f ($i+1), $appList[$i] | Write-Host
}
$excludeIn = Read-Host "Exclude which? (e.g. 1,6,11) or blank"
$excludeApps = @()
if (-not [string]::IsNullOrWhiteSpace($excludeIn)) {
    $nums = $excludeIn.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
    foreach ($n in $nums) {
        $idx = [int]$n - 1
        if ($idx -ge 0 -and $idx -lt $appList.Count) { $excludeApps += $appList[$idx] }
    }
    $excludeApps = $excludeApps | Select-Object -Unique
}

# Shared computer licensing (common for RDS/VDI) - mainly for M365 Apps
$shared = $false
if ($productId -eq "O365ProPlusRetail") {
    $shared = Read-YesNo "Enable SharedComputerLicensing (RDS/VDI)?" $false
}

# Download-only or download+install
$doInstall = Read-YesNo "After download, also INSTALL/CONFIGURE Office now?" $true

# Where to store downloaded Office source files
$sourcePath = Join-Path $base "OfficeSource"
New-Item -ItemType Directory -Path $sourcePath | Out-Null

# ========= Build configuration.xml =========

$excludeXml = ""
foreach ($app in $excludeApps) {
    $excludeXml += "      <ExcludeApp ID=`"$app`" />`r`n"
}

$addAttrs = @("OfficeClientEdition=`"$arch`"","Channel=`"$channel`"","SourcePath=`"$sourcePath`"")
if ($version) { $addAttrs += "Version=`"$version`"" }
$addAttrString = $addAttrs -join " "

# NOTE: Display/AcceptEULA are for install phase
$configXml = @"
<Configuration>
  <Add $addAttrString>
    <Product ID="$productId">
      <Language ID="$lang" />
$excludeXml    </Product>
  </Add>
  <Updates Enabled="TRUE" Channel="$channel" />
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
"@

if ($shared) {
    $configXml += "  <Property Name=""SharedComputerLicensing"" Value=""1"" />`r`n"
}

$configXml += @"
  <Logging Level="Standard" Path="$base" />
</Configuration>
"@

$configPath = Join-Path $base "configuration.xml"
$configXml | Out-File -FilePath $configPath -Encoding UTF8 -Force

Write-Host ""
Write-Host "============================================================"
Write-Host "Configuration written to:"
Write-Host "  $configPath"
Write-Host "Office source will download to:"
Write-Host "  $sourcePath"
Write-Host "ODT folder:"
Write-Host "  $odtExtract"
Write-Host "============================================================"
Write-Host ""
Write-Host "Starting download: setup.exe /download configuration.xml"
Start-Process -FilePath $setupExe -WorkingDirectory $odtExtract -ArgumentList "/download `"$configPath`"" -Wait

Write-Host ""
Write-Host "Download completed."

if ($doInstall) {
    Write-Host ""
    Write-Host "Starting install/configure: setup.exe /configure configuration.xml"
    Start-Process -FilePath $setupExe -WorkingDirectory $odtExtract -ArgumentList "/configure `"$configPath`"" -Wait
    Write-Host ""
    Write-Host "Install/configure completed."
}

Write-Host ""
Write-Host "Done. Logs (if any) are in:"
Write-Host "  $base"
