# install.ps1
$ErrorActionPreference = "Stop"

# Параметры
$moduleFileName = "regime.msi"
$moduleDownloadUrl = "https://github.com/Valerrra/ModulZnakInstaller/releases/download/regime/regime.msi"
$downloadsPath = Join-Path $env:USERPROFILE "Downloads"
$localModulePath = Join-Path $downloadsPath $moduleFileName
$tempPath = Join-Path $env:TEMP $moduleFileName

function Stop-ServiceSafe($svc) {
    try {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-Host "Остановка службы $svc..."
            Stop-Service -Name $svc -Force -ErrorAction Stop
            Write-Host "Служба $svc остановлена."
        }
    } catch {
        Write-Warning ("Не удалось остановить службу {0}. Ошибка: {1}" -f $svc, $_.Exception.Message)
    }
}

function Start-ServiceSafe($svc) {
    try {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-Host "Запуск службы $svc..."
            Start-Service -Name $svc -ErrorAction Stop
            Write-Host "Служба $svc запущена."
        }
    } catch {
        Write-Warning ("Не удалось запустить службу {0}. Ошибка: {1}" -f $svc, $_.Exception.Message)
    }
}

# Проверка наличия MSI в Загрузках
if (Test-Path $localModulePath) {
    Write-Host "Файл найден в папке Загрузки. Используем его."
    Copy-Item $localModulePath $tempPath -Force
} else {
    Write-Host "Скачивание модуля..."
    Invoke-WebRequest -Uri $moduleDownloadUrl -OutFile $tempPath
    Write-Host "Модуль скачан."
}

# Останавливаем только yenisei и regime
$servicesToStop = @("yenisei", "regime")
foreach ($svc in $servicesToStop) {
    Stop-ServiceSafe $svc
}

# Установка с автоподстановкой логина/пароля (но с мастером)
Write-Host "Установка модуля..."
Start-Process msiexec.exe -ArgumentList "/i `"$tempPath`" USER=ARED PASSWORD=Ared2025 /norestart" -Wait
Write-Host "Установка завершена."

# Запуск служб обратно
foreach ($svc in $servicesToStop) {
    Start-ServiceSafe $svc
}

Write-Host "Готово."
