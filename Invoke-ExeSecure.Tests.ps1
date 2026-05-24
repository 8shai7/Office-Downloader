BeforeAll {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile("$(Join-Path $PSScriptRoot odt_payload.ps1)", [ref]$null, [ref]$null)
    $functionAst = $ast.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'Invoke-ExeSecure' }, $true)
    Invoke-Expression $functionAst.Extent.Text
}

Describe "Invoke-ExeSecure" {
    Context "When file does not exist" {
        It "Throws an error" {
            Mock Test-Path { return $false }
            { Invoke-ExeSecure -FilePath "fake.exe" -Arguments @() } | Should -Throw "Error: fake.exe not found."
            Assert-MockCalled Test-Path -Times 1 -ParameterFilter { $Path -eq "fake.exe" }
        }
    }

    Context "When file exists" {
        BeforeEach {
            Mock Test-Path { return $true }
            Mock Unblock-File {}
            Mock Get-Location { return [PSCustomObject]@{ Path = "C:\OldPath" } }
            Mock Set-Location {}
        }

        It "Calls Unblock-File and Start-Process and returns exit code" {
            Mock Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }

            $result = Invoke-ExeSecure -FilePath "real.exe" -Arguments @("-arg1")

            $result | Should -Be 0
            Assert-MockCalled Test-Path -Times 1 -ParameterFilter { $Path -eq "real.exe" }
            Assert-MockCalled Unblock-File -Times 1 -ParameterFilter { $Path -eq "real.exe" }
            Assert-MockCalled Start-Process -Times 1 -ParameterFilter { $FilePath -eq "real.exe" -and $ArgumentList -eq @("-arg1") }
            Assert-MockCalled Set-Location -Times 1 # Finally block always executes
        }

        It "Sets working directory if provided" {
            Mock Start-Process { return [PSCustomObject]@{ ExitCode = 42 } }

            $result = Invoke-ExeSecure -FilePath "real.exe" -Arguments @() -WorkingDirectory "C:\NewPath"

            $result | Should -Be 42
            Assert-MockCalled Set-Location -Times 2 # Once in try, once in finally
        }

        It "Restores location even if Start-Process throws" {
            Mock Start-Process { throw "Process failed" }

            { Invoke-ExeSecure -FilePath "real.exe" -Arguments @() -WorkingDirectory "C:\NewPath" } | Should -Throw "Process failed"

            Assert-MockCalled Set-Location -Times 2 # Once in try, once in finally
        }
    }
}
