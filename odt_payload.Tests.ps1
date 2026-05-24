Import-Module Pester -ErrorAction Stop

Describe "Get-ODTDownloadUrl" {
    BeforeAll {
        . "$PSScriptRoot/odt_payload.ps1"
    }

    It "Should return URL from Microsoft Download Center when regex matches" {
        function Say { } # Mock Say to suppress output
        $expectedUrl = "https://download.microsoft.com/download/some/officedeploymenttool2021.exe"
        $mockHtml = "{ ""url"" : ""$expectedUrl"" }"

        Mock Invoke-WebRequest {
            return [PSCustomObject]@{ Content = $mockHtml }
        }

        $result = Get-ODTDownloadUrl

        $result | Should -Be $expectedUrl
        Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
    }

    It "Should return fallback URL when regex does not match" {
        function Say { } # Mock Say to suppress output
        $fallback = "https://aka.ms/ODT"
        $mockHtml = "{ ""url"" : ""something_else.exe"" }"

        Mock Invoke-WebRequest {
            return [PSCustomObject]@{ Content = $mockHtml }
        }

        $result = Get-ODTDownloadUrl

        $result | Should -Be $fallback
        Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
    }

    It "Should return fallback URL when an exception occurs" {
        function Say { } # Mock Say to suppress output
        $fallback = "https://aka.ms/ODT"

        Mock Invoke-WebRequest {
            throw "Network Error"
        }

        $result = Get-ODTDownloadUrl

        $result | Should -Be $fallback
        Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
    }
}
