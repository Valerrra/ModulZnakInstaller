# install.ps1
$ErrorActionPreference = "Stop"

# Параметры
$moduleFileName = "regime.msi"
$moduleDownloadUrl = "https://github.com/Valerrra/ModulZnakInstaller/releases/download/regime/regime.msi"
$downloadsPath = Join-Path $env:USERPROFILE "Downloads"
$localModulePath = Join-Path $downloadsPath $moduleFileName
$OutputPath = Join-Path $env:TEMP $moduleFileName

# Проверка файла в Downloads
if (Test-Path $localModulePath) {
    Write-Host "Файл найден в Загрузках. Используем его."
    Copy-Item $localModulePath $OutputPath -Force
} else {
    Write-Host "Скачивание модуля..."
    Invoke-WebRequest -Uri $moduleDownloadUrl -OutFile $OutputPath
    Write-Host "Модуль скачан."
}

# Останавливаем службы (только yenisei и regime)
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

$servicesToStop = @("yenisei", "regime")
foreach ($svc in $servicesToStop) { Stop-ServiceSafe $svc }

# Установка модуля в тихом режиме с параметрами пользователя ARED
Write-Host "Устанавливаю модуль..."
$Arguments = "/i `"$OutputPath`" /qn ADMINUSER=`"ARED`" ADMINPASSWORD=`"Ared2025`" SERVERURL=`"https://rsapi.crpt.ru`" AUTOSERVICE=`"1`""
Start-Process "msiexec.exe" -ArgumentList $Arguments -Wait -NoNewWindow
Write-Host "Установка завершена."

# Запуск служб обратно
foreach ($svc in $servicesToStop) { Start-ServiceSafe $svc }

Write-Host "Готово."
