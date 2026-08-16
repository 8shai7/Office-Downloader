Describe "downloader.ps1" {
    BeforeAll {
        $ScriptPath = "$PWD/downloader.ps1"
    }

    It "Should download and execute the payload successfully" {
        Mock Invoke-WebRequest {
            return [PSCustomObject]@{ Content = "Write-Host 'Mocked script'" }
        }
        Mock Write-Host {}

        . $ScriptPath

        Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -match "https://raw.githubusercontent.com/8shai7/Office-Downloader/main/odt_payload.ps1\?v=\d{14}" }
        Assert-MockCalled Write-Host -ParameterFilter { $Object -match "\[BOOT\] Fetching FRESH payload" }
        Assert-MockCalled Write-Host -ParameterFilter { $Object -match "Mocked script" }
    }

    It "Should handle exceptions gracefully" {
        Mock Invoke-WebRequest {
            throw "Network timeout"
        }
        Mock Write-Host {}

        . $ScriptPath

        Assert-MockCalled Invoke-WebRequest -Times 1
        Assert-MockCalled Write-Host -ParameterFilter { $Object -match "ERROR: Network timeout" -and $ForegroundColor -eq 'Red' }
    }
}
