param (
    [string]$Token = "",
    [string]$Owner = "Maenvaeru",
    [string]$Repo = "commu-calc",
    [string]$Tag = "v1.0.1",
    [string]$Title = "Commu-Calc v1.0.1 (Cyber-Glass UI & OTA)",
    [string]$ApkPath = "commu-calc.apk"
)

if (-not $Token) {
    $tokenFile = Join-Path $PSScriptRoot ".github_token"
    if (Test-Path $tokenFile) {
        $Token = (Get-Content $tokenFile -Raw).Trim()
    } elseif ($env:GITHUB_TOKEN) {
        $Token = $env:GITHUB_TOKEN.Trim()
    }
}

$ErrorActionPreference = "Stop"

Write-Host "=== COMMU-CALC RELEASE UPLOADER ===" -ForegroundColor Cyan
Write-Host "Target: $Owner/$Repo | Tag: $Tag | File: $ApkPath"

if (-not (Test-Path $ApkPath)) {
    throw "APK файл не найден: $ApkPath"
}

$apkBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $ApkPath))
Write-Host "Размер APK: $($apkBytes.Length) байт ($([math]::Round($apkBytes.Length / 1MB, 2)) МБ)" -ForegroundColor Green

$headers = @{
    "Authorization" = "token $Token"
    "Accept" = "application/vnd.github.v3+json"
    "User-Agent" = "CommuCalc-Release-Tool"
}

# 1. Проверяем репозиторий
Write-Host "1. Проверка репозитория..." -ForegroundColor Yellow
try {
    $repoObj = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo" -Headers $headers -Method Get
    Write-Host "Репозиторий доступен: $($repoObj.html_url) (private=$($repoObj.private))" -ForegroundColor Green
} catch {
    Write-Host "Создание публичного репозитория $Owner/$Repo..." -ForegroundColor Yellow
    $createRepoBody = @{
        name = $Repo
        private = $false
        description = "Commu-Calc Utility Meter Application"
    } | ConvertTo-Json
    $repoObj = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $createRepoBody
    Write-Host "Репозиторий создан: $($repoObj.html_url)" -ForegroundColor Green
}

# 2. Проверяем или создаем релиз
Write-Host "2. Получение или создание релиза $Tag..." -ForegroundColor Yellow
$releasesUrl = "https://api.github.com/repos/$Owner/$Repo/releases"
$release = $null

try {
    $release = Invoke-RestMethod -Uri "$releasesUrl/tags/$Tag" -Headers $headers -Method Get
    Write-Host "Найден существующий релиз: ID $($release.id)" -ForegroundColor Green
} catch {
    Write-Host "Создание нового релиза $Tag..." -ForegroundColor Yellow
    $releasePayload = @{
        tag_name = $Tag
        name = $Title
        body = "Релиз с новым Cyber-Glass дизайном 2026, мониторингом дельты расхода и встроенным OTA-обновлением."
        draft = $false
        prerelease = $false
    } | ConvertTo-Json -Depth 5
    $release = Invoke-RestMethod -Uri $releasesUrl -Headers $headers -Method Post -Body $releasePayload
    Write-Host "Релиз успешно создан: ID $($release.id)" -ForegroundColor Green
}

# 3. Проверяем существующие ассеты в релизе
$assetName = "commu-calc-$Tag.apk"
Write-Host "3. Проверка существующих ассетов ($assetName)..." -ForegroundColor Yellow

if ($release.assets) {
    foreach ($asset in $release.assets) {
        if ($asset.name -eq $assetName -or $asset.name -like "*.apk") {
            Write-Host "Удаление старого ассета: $($asset.name) (ID: $($asset.id))..." -ForegroundColor Yellow
            try {
                Invoke-RestMethod -Uri "$releasesUrl/assets/$($asset.id)" -Headers $headers -Method Delete | Out-Null
                Write-Host "Старый ассет удален." -ForegroundColor Green
            } catch {
                Write-Host "Предупреждение при удалении: $($_.Exception.Message)" -ForegroundColor DarkYellow
            }
        }
    }
}

# 4. Загрузка бинарного APK
Write-Host "4. Загрузка APK ассета в релиз..." -ForegroundColor Yellow
$uploadUrl = $release.upload_url -replace '\{.*\}', "?name=$assetName"

$uploadHeaders = @{
    "Authorization" = "token $Token"
    "Content-Type" = "application/vnd.android.package-archive"
    "User-Agent" = "CommuCalc-Release-Tool"
}

$uploadedAsset = Invoke-RestMethod -Uri $uploadUrl -Headers $uploadHeaders -Method Post -Body $apkBytes
Write-Host "=== УСПЕХ! Ассет загружен ===" -ForegroundColor Green
Write-Host "Имя файла: $($uploadedAsset.name)"
Write-Host "Размер: $($uploadedAsset.size) байт"
Write-Host "Browser Download URL: $($uploadedAsset.browser_download_url)"
Write-Host "API Asset URL: $($uploadedAsset.url)"
