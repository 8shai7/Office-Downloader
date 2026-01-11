# odt_payload.ps1
# Office ODT interactive downloader/installer (payload)
# Called by downloader.ps1 bootstrap

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'Continue'

function Start-OfficeODTInteractive {

    function Say {
        param(
            [Parameter(Mandatory)][string] $Message,
            [ConsoleColor] $Color = [ConsoleColor]::White
        )
        try { Write-Host $Message -ForegroundColor $Color } catch { Write-Output $Message }
        try { [Console]::Out.Flush() } catch {}
    }

    function Ask {
        param([Parameter(Mandatory)][string] $Prompt)
        Say $Prompt Cyan
        $r = Read-Host "> "
        try { [Console]::Out.Flush() } catch {}
        return $r
    }

    function Read-Choice {
        param(
            [Parameter(Mandatory)] [string] $Prompt,
            [Parameter(Mandatory)] [hashtable] $Options,
            [string] $DefaultKey = $null
        )
        Say "" White
        Say $Prompt White
        foreach ($k in ($Options.Keys | Sort-Object)) {
            $label = $Options[$k]
            if ($DefaultKey -and $k -eq $DefaultKey) {
                Say ("  [{0}] {1} (default)" -f $k, $label) DarkGray
            } else {
                Say ("  [{0}] {1}" -f $k, $label) Gray
            }
        }
        while ($true) {
            $in = Ask "Select"
            if ([string]::IsNullOrWhiteSpace($in) -and $DefaultKey) { return $DefaultKey }
            if ($Options.ContainsKey($in)) { return $in }
            Say "Invalid selection. Try again." Yellow
        }
    }

    function Read-YesNo {
        param([Parameter(Mandatory)] [string] $Prompt, [bool] $Default = $true)
        $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }
        while ($true) {
            $in = Ask "$Prompt $suffix"
            if ([string]::IsNullOrWhiteSpace($in)) { return $Default }
            switch ($in.ToLowerInvariant()) {
                'y' { return $true }
                'yes' { return $true }
                'n' { return $false }
                'no' { return $false }
                default { Say "Please answer y or n." Yellow }
            }
        }
    }

    function Warn-IfNotAdmin {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p  = New-Object Security.Principal.WindowsPrincipal($id)
        if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Say "" White
            Say "WARNING: Not running as Administrator." Yellow
            Say "ODT download usually works without admin, but installation often requires admin." Yellow
            Say "If install fails, rerun PowerShell as Administrator." Yellow
        } else {
            Say "Running as Administrator." Green
        }
    }

    function Invoke-Exe {
        param(
            [Parameter(Mandatory)][string] $FilePath,
            [Parameter(Mandatory)][string[]] $Arguments,
            [string] $WorkingDirectory = $null,
            [string] $StepName = $null
        )
        if ($StepName) { Say $StepName Cyan }
        $argLine = ($Arguments | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '
        Say ("Running: {0} {1}" -f $FilePath, $argLine) DarkGray

        $old = Get-Location
        try {
            if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
            & $FilePath @Arguments
            $exitCode = 0
            if (Test-Path variable:LASTEXITCODE) {
                $exitCode = $LASTEXITCODE
            }

            if ($exitCode -ne 0) {
                throw ("Command failed with exit code {0} - {1} {2}" -f $exitCode, $FilePath, $argLine)
            }

        } finally {
            Set-Location $old
        }
    }

    function Get-ODTDownloadUrl {
        <#
          Microsoft changes the direct download.microsoft.com URL periodically.
          This function scrapes the official Download Center page (id=49117) to find the current EXE.
        #>
        $detailsUrl = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
        $fallback   = "https://aka.ms/ODT"

        try {
            Say "Resolving latest ODT download URL..." DarkGray
            $resp = Invoke-WebRequest -Uri $detailsUrl -UseBasicParsing -Headers @{ "Cache-Control"="no-cache"; "Pragma"="no-cache"; "User-Agent"="PowerShell" }

            # Common pattern used on the page: "url":"https://download.microsoft.com/download/<guid>/officedeploymenttool_....exe"
            $re = '"url"\s*:\s*"(https://download\.microsoft\.com/download/[^"]+officedeploymenttool[^"]+\.exe)"'
            if ($resp.Content -match $re) { return $Matches[1] }

            # Fallback: sometimes the "Download" button is present as a plain link in HTML
            $re2 = '(https://download\.microsoft\.com/download/[^"\s]+officedeploymenttool[^"\s]+\.exe)'
            $m = [regex]::Match($resp.Content, $re2)
            if ($m.Success) { return $m.Groups[1].Value }

            return $fallback
        } catch {
            Say "Could not scrape Download Center page. Using fallback: $fallback" Yellow
            return $fallback
        }
    }

    Write-Output "[INFO] Starting Office ODT interactive downloader/installer..."
    Say "Starting Office ODT interactive downloader/installer..." Green
    Warn-IfNotAdmin

    # Work folder
    $base = Join-Path $env:TEMP ("ODT_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    New-Item -ItemType Directory -Path $base | Out-Null

    $odtExe     = Join-Path $base "officedeploymenttool.exe"
    $odtExtract = Join-Path $base "ODT"
    New-Item -ItemType Directory -Path $odtExtract | Out-Null

    Say "Working folder: $base" DarkGray

    $odtUrl = Get-ODTDownloadUrl
    Say "Downloading Office Deployment Tool (ODT)..." Yellow
    Say "ODT URL: $odtUrl" DarkGray

    Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing -Headers @{ "Cache-Control"="no-cache"; "Pragma"="no-cache"; "User-Agent"="PowerShell" }

    Say "Extracting ODT..." Yellow
    Invoke-Exe -FilePath $odtExe -Arguments @("/quiet", ("/extract:{0}" -f $odtExtract)) -StepName "Extracting ODT to $odtExtract"

    $setupExe = Join-Path $odtExtract "setup.exe"
    if (-not (Test-Path $setupExe)) {
        throw "ODT extraction failed: setup.exe not found in $odtExtract"
    }

    # ========= Interactive options =========

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
        default { throw "Unexpected product choice: $productChoice" }
    }

    $archChoice = Read-Choice -Prompt "Choose architecture:" -Options @{ "1"="64-bit"; "2"="32-bit" } -DefaultKey "1"
    $arch = if ($archChoice -eq "2") { "32" } else { "64" }

    $langIn = Ask "Language (e.g. en-us, he-il). Leave blank for en-us"
    $lang = if ([string]::IsNullOrWhiteSpace($langIn)) { "en-us" } else { $langIn.Trim() }

    $channel = "Current"
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
            default { throw "Unexpected channel choice: $channelChoice" }
        }
    } else {
        $channel = "PerpetualVL2024"
    }

    Say "" White
    Say "Exact Version is optional." Gray
    Say "Examples (build numbers vary): 16.0.17xxxx.xxxxx" Gray
    $verIn = Ask "Enter exact Version build (or leave blank to let ODT pick latest for the channel)"
    $version = if ([string]::IsNullOrWhiteSpace($verIn)) { $null } else { $verIn.Trim() }

    $appList = @("Access","Excel","Groove","Lync","OneDrive","OneNote","Outlook","PowerPoint","Publisher","Teams","Word")
    Say "" White
    Say "Select which apps to EXCLUDE." White
    Say "Type comma-separated numbers to exclude (or blank to exclude nothing)." Gray
    for ($i=0; $i -lt $appList.Count; $i++) { Say ("{0,2}) {1}" -f ($i+1), $appList[$i]) Gray }
    $excludeIn = Ask "Exclude which? (e.g. 1,6,11) or blank"

    $excludeApps = @()
    if (-not [string]::IsNullOrWhiteSpace($excludeIn)) {
        $nums = $excludeIn.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
        foreach ($n in $nums) {
            $idx = [int]$n - 1
            if ($idx -ge 0 -and $idx -lt $appList.Count) { $excludeApps += $appList[$idx] }
        }
        $excludeApps = $excludeApps | Select-Object -Unique
    }

    $shared = $false
    if ($productId -eq "O365ProPlusRetail") {
        $shared = Read-YesNo "Enable SharedComputerLicensing (RDS/VDI)?" $false
    }

    $doInstall = Read-YesNo "After download, also INSTALL/CONFIGURE Office now?" $true

    $sourcePath = Join-Path $base "OfficeSource"
    New-Item -ItemType Directory -Path $sourcePath | Out-Null

    # ========= Build configuration.xml =========
    $excludeXml = ""
    foreach ($app in $excludeApps) { $excludeXml += "      <ExcludeApp ID=`"$app`" />`r`n" }

    $addAttrs = @("OfficeClientEdition=`"$arch`"","Channel=`"$channel`"","SourcePath=`"$sourcePath`"")
    if ($version) { $addAttrs += "Version=`"$version`"" }
    $addAttrString = $addAttrs -join " "

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

    if ($shared) { $configXml += "  <Property Name=""SharedComputerLicensing"" Value=""1"" />`r`n" }

    $configXml += @"
  <Logging Level="Standard" Path="$base" />
</Configuration>
"@

    $configPath = Join-Path $base "configuration.xml"
    $configXml | Out-File -FilePath $configPath -Encoding UTF8 -Force

    Say "" White
    Say "============================================================" DarkGray
    Say "Configuration written to:" White
    Say "  $configPath" Gray
    Say "Office source will download to:" White
    Say "  $sourcePath" Gray
    Say "ODT folder:" White
    Say "  $odtExtract" Gray
    Say "============================================================" DarkGray

    Say "" White
    Say "Starting download: setup.exe /download configuration.xml" Yellow
    Invoke-Exe -FilePath $setupExe -WorkingDirectory $odtExtract -Arguments @("/download", $configPath) -StepName "Downloading Office content..."

    Say "" White
    Say "Download completed." Green

    if ($doInstall) {
        Say "" White
        Say "Starting install/configure: setup.exe /configure configuration.xml" Yellow
        Invoke-Exe -FilePath $setupExe -WorkingDirectory $odtExtract -Arguments @("/configure", $configPath) -StepName "Installing/Configuring Office..."
        Say "" White
        Say "Install/configure completed." Green
    }

    Say "" White
    Say "Done. Logs (if any) are in:" White
    Say "  $base" Gray
}

Start-OfficeODTInteractive
