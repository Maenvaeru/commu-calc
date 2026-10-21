# Diagnostic utility reading from gitignored .github_token
$tokenFile = Join-Path $PSScriptRoot ".github_token"
if (Test-Path $tokenFile) {
    $Token = (Get-Content $tokenFile -Raw).Trim()
    Write-Host "Local token loaded successfully." -ForegroundColor Green
} else {
    Write-Host "No local token found." -ForegroundColor Yellow
}
