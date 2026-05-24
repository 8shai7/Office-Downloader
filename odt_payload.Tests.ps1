$ErrorActionPreference = 'Stop'
Import-Module Pester -ErrorAction Stop

Describe "ODT Payload End-to-End" {

    BeforeAll {
        $script:originalTemp = $env:TEMP
        $env:TEMP = Join-Path $PWD "tmp_test"
        if (-not (Test-Path $env:TEMP)) { New-Item -ItemType Directory -Path $env:TEMP | Out-Null }
    }

    AfterAll {
        if (Test-Path $env:TEMP) { Remove-Item $env:TEMP -Recurse -Force }
        $env:TEMP = $script:originalTemp
    }

    BeforeEach {
        Mock Start-Process { return [pscustomobject]@{ ExitCode = 0 } }
        Mock Unblock-File {}
        Mock Get-ChildItem {
            param($Path, $Filter, $File, $Recurse)
            $setupPath = Join-Path $Path "setup.exe"
            if (-not (Test-Path (Split-Path $setupPath))) { New-Item -ItemType Directory -Path (Split-Path $setupPath) | Out-Null }
            Set-Content -Path $setupPath -Value "dummy setup"
            return Get-Item $setupPath
        } -ParameterFilter { $Filter -eq "setup.exe" }

        Mock Remove-Item {
            param($Path, $Recurse, $Force, $ErrorAction)
            if ($Path -like "*ODT_*") {
                $script:basePath = $Path
            } else {
                & (Get-Command Remove-Item -CommandType Cmdlet) -Path $Path -Recurse:$Recurse -Force:$Force -ErrorAction $ErrorAction
            }
        } -ParameterFilter { $Path -like "*ODT_*" }
    }

    Context "Happy Path - M365 Apps, 64-bit, Full Suite, en-us" {
        It "Should generate correct XML without ExcludeApps" {
            $script:inputs = @("1", "1", "en-us", "1")

            Mock Read-Host {
                $val = $script:inputs[0]
                if ($script:inputs.Length -gt 1) {
                    $script:inputs = $script:inputs[1..($script:inputs.Length-1)]
                } else {
                    $script:inputs = @()
                }
                return $val
            }

            Mock Invoke-WebRequest {
                param($Uri, $OutFile, $UseBasicParsing, $Headers, $UserAgent)
                if ($Uri -match "details.aspx") {
                    return [pscustomobject]@{ Content = '"url":"https://download.microsoft.com/download/something/officedeploymenttool_123.exe"' }
                }
                if ($OutFile) {
                    Set-Content -Path $OutFile -Value "dummy exe"
                }
            }

            # Run the script
            . ./odt_payload.ps1

            # Verify
            $xmlPath = Join-Path $script:basePath "configuration.xml"
            $xmlContent = Get-Content $xmlPath -Raw

            $xmlContent | Should -Match "O365ProPlusRetail"
            $xmlContent | Should -Match 'OfficeClientEdition="64"'
            $xmlContent | Should -Match 'Language ID="en-us"'
            $xmlContent | Should -Not -Match "ExcludeApp"
        }
    }

    Context "Custom App Selection - M365 Apps, 64-bit, Exclude Apps" {
        It "Should generate XML with ExcludeApps" {
            # 1: M365, 1: 64-bit, en-us, 2: Custom Selection, 1,2: Include Access and Excel
            $script:inputs = @("1", "1", "en-us", "2", "1,2")

            Mock Read-Host {
                $val = $script:inputs[0]
                if ($script:inputs.Length -gt 1) {
                    $script:inputs = $script:inputs[1..($script:inputs.Length-1)]
                } else {
                    $script:inputs = @()
                }
                return $val
            }

            Mock Invoke-WebRequest {
                param($Uri, $OutFile, $UseBasicParsing, $Headers, $UserAgent)
                if ($Uri -match "details.aspx") {
                    return [pscustomobject]@{ Content = '"url":"https://download.microsoft.com/download/something/officedeploymenttool_123.exe"' }
                }
                if ($OutFile) {
                    Set-Content -Path $OutFile -Value "dummy exe"
                }
            }

            # Run the script
            . ./odt_payload.ps1

            # Verify
            $xmlPath = Join-Path $script:basePath "configuration.xml"
            $xmlContent = Get-Content $xmlPath -Raw

            $xmlContent | Should -Match "ExcludeApp ID=`"Word`""
            $xmlContent | Should -Not -Match "ExcludeApp ID=`"Access`""
            $xmlContent | Should -Not -Match "ExcludeApp ID=`"Excel`""
        }
    }

    Context "Different Product - Office 2024 LTSC Pro, 32-bit, he-il" {
        It "Should map products and channels correctly" {
            # 2: LTSC Pro, 2: 32-bit, he-il, 1: Full Suite
            $script:inputs = @("2", "2", "he-il", "1")

            Mock Read-Host {
                $val = $script:inputs[0]
                if ($script:inputs.Length -gt 1) {
                    $script:inputs = $script:inputs[1..($script:inputs.Length-1)]
                } else {
                    $script:inputs = @()
                }
                return $val
            }

            Mock Invoke-WebRequest {
                param($Uri, $OutFile, $UseBasicParsing, $Headers, $UserAgent)
                if ($Uri -match "details.aspx") {
                    return [pscustomobject]@{ Content = '"url":"https://download.microsoft.com/download/something/officedeploymenttool_123.exe"' }
                }
                if ($OutFile) {
                    Set-Content -Path $OutFile -Value "dummy exe"
                }
            }

            # Run the script
            . ./odt_payload.ps1

            # Verify
            $xmlPath = Join-Path $script:basePath "configuration.xml"
            $xmlContent = Get-Content $xmlPath -Raw

            $xmlContent | Should -Match "ProPlus2024Volume"
            $xmlContent | Should -Match 'OfficeClientEdition="32"'
            $xmlContent | Should -Match 'Channel="PerpetualVL2024"'
            $xmlContent | Should -Match 'Language ID="he-il"'
        }
    }

    Context "Fallback Web Request" {
        It "Should fallback to aka.ms/ODT on scrape failure" {
            $script:inputs = @("3", "1", "en-us", "1")

            Mock Read-Host {
                $val = $script:inputs[0]
                if ($script:inputs.Length -gt 1) {
                    $script:inputs = $script:inputs[1..($script:inputs.Length-1)]
                } else {
                    $script:inputs = @()
                }
                return $val
            }

            Mock Invoke-WebRequest {
                param($Uri, $OutFile, $UseBasicParsing, $Headers, $UserAgent)
                if ($Uri -match "details.aspx") {
                    # Simulate non-matching output
                    return [pscustomobject]@{ Content = 'no url here' }
                }
                if ($OutFile) {
                    $script:downloadedUri = $Uri
                    Set-Content -Path $OutFile -Value "dummy exe"
                }
            }

            # Run the script
            . ./odt_payload.ps1

            # Verify fallback
            $script:downloadedUri | Should -Be "https://aka.ms/ODT"

            $xmlPath = Join-Path $script:basePath "configuration.xml"
            $xmlContent = Get-Content $xmlPath -Raw
            $xmlContent | Should -Match "Standard2024Volume"
        }
    }

}
