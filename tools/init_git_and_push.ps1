$ErrorActionPreference = "Stop"

$tokenFile = Join-Path $PSScriptRoot ".github_token"
if (Test-Path $tokenFile) {
    $Token = (Get-Content $tokenFile -Raw).Trim()
} elseif ($env:GITHUB_TOKEN) {
    $Token = $env:GITHUB_TOKEN.Trim()
} else {
    throw "Не найден токен GitHub (создайте tools/.github_token или задайте GITHUB_TOKEN)"
}

$RepoUrl = "https://$($Token)@github.com/Maenvaeru/commu-calc.git"

Write-Host "1. Resetting Git repo completely..." -ForegroundColor Yellow
if (Test-Path ".git") {
    Remove-Item -Recurse -Force ".git"
}

Write-Host "2. Fresh Git Init..." -ForegroundColor Yellow
git init
git config user.name "Maenvaeru"
git config user.email "maenvaeru@users.noreply.github.com"

Write-Host "3. Git Add..." -ForegroundColor Yellow
git add .

Write-Host "4. Clean Initial Commit (zero secrets)..." -ForegroundColor Yellow
git commit -m "feat: initial release with Commu-Calc mobile and OTA updater"

Write-Host "5. Set main branch..." -ForegroundColor Yellow
git branch -M main

Write-Host "6. Add origin remote..." -ForegroundColor Yellow
git remote add origin $RepoUrl

Write-Host "7. Pushing to GitHub..." -ForegroundColor Yellow
git push -u origin main -f

Write-Host "Git push complete and accepted by GitHub!" -ForegroundColor Green
