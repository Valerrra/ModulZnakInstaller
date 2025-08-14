Set-ExecutionPolicy Bypass -Scope Process -Force

$ErrorActionPreference = "Stop"

# === Настройки ===
$downloadUrl = "https://example.com/regime-1.5.0-462.msi"  # ссылка на MSI
$userDownloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$installerPath = Join-Path $userDownloads "regime-1.5.0-462.msi"

# === Проверка наличия файла ===
if (Test-Path $installerPath) {
    Write-Host "Файл найден в $userDownloads — пропускаем загрузку."
} else {
    Write-Host "Файл не найден — начинаю загрузку..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
    Write-Host "Файл успешно скачан."
}

# === Список служб для остановки ===
$servicesToStop = @(
    "yenisei",
    "regime",
    "Apache2.2"
)

# Добавляем службы 1С, если есть
$service1C = Get-Service | Where-Object { $_.Name -like "1C*" -or $_.DisplayName -like "*1C*" }
if ($service1C) {
    $servicesToStop += $service1C.Name
}

# === Остановка служб ===
foreach ($svc in $servicesToStop) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Останавливаю службу: $svc"
            Stop-Service -Name $svc -Force
        } catch {
            Write-Warning "Не удалось остановить службу $svc: $(${_.Exception.Message})"
        }
    }
}

# === Установка ===
Write-Host "Запуск установки..."
Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" /qn /norestart" -Wait
Write-Host "Установка завершена."

# === Запуск служб ===
foreach ($svc in $servicesToStop) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Запускаю службу: $svc"
            Start-Service -Name $svc
        } catch {
            Write-Warning "Не удалось запустить службу $svc: $(${_.Exception.Message})"
        }
    }
}

Write-Host "Все операции завершены."
