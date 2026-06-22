$code = Get-Content -Raw -Path ./odt_payload.ps1
$bytes = [System.Text.Encoding]::UTF8.GetBytes($code)
$hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
$computedHashBytes = $hashAlgorithm.ComputeHash($bytes)
$computedHash = [BitConverter]::ToString($computedHashBytes) -replace "-"
Write-Host "Computed: $computedHash"
