# install.ps1
# Установка локального модуля в автоматическом режиме

$ErrorActionPreference = "Stop"

# Папка для временных файлов
$tempDir = "$env:TEMP\ModulZnakInstaller"
if (-Not (Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory | Out-Null
}

# URL установщика (MSI в Release)
$installerUrl = "https://github.com/Valerrra/ModulZnakInstaller/releases/download/regime/regime.msi"
$installer = Join-Path $tempDir "regime.msi"

# Скачивание установщика
try {
    Write-Host "Скачиваю установщик..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $installer -UseBasicParsing
    Write-Host "Файл сохранён: $installer"
}
catch {
    Write-Host "Ошибка при скачивании: $_"
    Exit 1
}

# Запуск автоматической установки
try {
    Write-Host "Запускаю установку (автоматический режим)..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installer`" /qn /norestart" -Wait -PassThru
    Write-Host "Установка завершена"
}
catch {
    Write-Host "Ошибка при установке: $_"
    Exit 1
}

# Очистка временных файлов
try {
    if (Test-Path $installer) {
        Remove-Item $installer -Force
    }
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Force -Recurse
    }
    Write-Host "Временные файлы удалены"
}
catch {
    Write-Host "Не удалось удалить временные файлы: $_"
}
