function Say {
    param([AllowEmptyString()][string]$m = "", [ConsoleColor]$c = [ConsoleColor]::White)
    try { Write-Host $m -ForegroundColor $c } catch { Write-Output $m }
}

$testCases = @(
    "en-us",
    "he-il",
    "en",
    "EN-US",
    "en-us`" /><Display Level=`"None`" />",
    "<script>alert(1)</script>",
    "en us"
)

foreach ($testCase in $testCases) {
    if ($testCase -match '^[a-zA-Z0-9\-]+$') {
        Say "Valid: $testCase" Green
    } else {
        Say "Invalid: $testCase" Red
    }
}
