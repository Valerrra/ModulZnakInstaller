# install.ps1
$ErrorActionPreference = "Stop"

# Параметры
$moduleFileName = "regime-1.5.0-462.msi"
$moduleDownloadUrl = "https://example.com/$moduleFileName" # <-- замени на свою ссылку
$downloadsPath = Join-Path $env:USERPROFILE "Downloads"
$localModulePath = Join-Path $downloadsPath $moduleFileName
$tempPath = Join-Path $env:TEMP $moduleFileName

# Функция остановки службы
function Stop-ServiceSafe($svc) {
    try {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-Host "Остановка службы $svc..."
            Stop-Service -Name $svc -Force -ErrorAction Stop
            Write-Host "Служба $svc остановлена."
        }
    } catch {
        Write-Warning ("Не удалось остановить службу {0}: {1}" -f $svc, $_.Exception.Message)
    }
}

# Функция запуска службы
function Start-ServiceSafe($svc) {
    try {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-Host "Запуск службы $svc..."
            Start-Service -Name $svc -ErrorAction Stop
            Write-Host "Служба $svc запущена."
        }
    } catch {
        Write-Warning ("Не удалось запустить службу {0}: {1}" -f $svc, $_.Exception.Message)
    }
}

# Проверяем, есть ли файл в Downloads
if (Test-Path $localModulePath) {
    Write-Host "Файл найден в папке Загрузки. Используем его."
    Copy-Item $localModulePath $tempPath -Force
} else {
    Write-Host "Скачивание модуля..."
    Invoke-WebRequest -Uri $moduleDownloadUrl -OutFile $tempPath
    Write-Host "Модуль скачан."
}

# Останавливаем службы перед установкой
$servicesToStop = @(
    "yenisei",
    "regime",
    "Apache2.2",
    "1C:Enterprise 8.3 Server Agent"
)
foreach ($svc in $servicesToStop) {
    Stop-ServiceSafe $svc
}

# Устанавливаем модуль
Write-Host "Установка модуля..."
Start-Process msiexec.exe -ArgumentList "/i `"$tempPath`" /qn /norestart" -Wait
Write-Host "Установка завершена."

# Запускаем службы обратно
foreach ($svc in $servicesToStop) {
    Start-ServiceSafe $svc
}

Write-Host "Готово."
