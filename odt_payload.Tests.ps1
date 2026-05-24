BeforeAll {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/odt_payload.ps1", [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($func in $functions) {
        if ($func.Name -in 'Read-Choice', 'Say', 'Ask') {
            Invoke-Expression $func.Extent.Text
        }
    }
}

Describe "Read-Choice" {
    It "Returns default choice when input is empty and default is provided" {
        Mock Ask { return "" }
        Mock Say { }

        $options = @{ "1" = "Option 1"; "2" = "Option 2" }
        $result = Read-Choice -p "Prompt" -o $options -d "1"
        $result | Should -Be "1"
    }

    It "Returns user choice when valid input is provided" {
        Mock Ask { return "2" }
        Mock Say { }

        $options = @{ "1" = "Option 1"; "2" = "Option 2" }
        $result = Read-Choice -p "Prompt" -o $options -d "1"
        $result | Should -Be "2"
    }

    It "Retries on invalid selection until valid input is provided" {
        # First return "3" (invalid), then "1" (valid)
        $global:askCount = 0
        Mock Ask {
            $global:askCount++
            if ($global:askCount -eq 1) { return "3" }
            return "1"
        }
        Mock Say { }

        $options = @{ "1" = "Option 1"; "2" = "Option 2" }
        $result = Read-Choice -p "Prompt" -o $options -d "1"
        $result | Should -Be "1"
        Assert-MockCalled Ask -Times 2
    }
}
