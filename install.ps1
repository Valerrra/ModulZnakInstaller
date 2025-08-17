param(
    [string]$Url = "https://github.com/Valerrra/ModulZnakInstaller/releases/latest/download/regime.msi",
    [string]$TempFolder = "C:\Temp",
    [string]$MsiName = "install.msi"
)

# Включаем TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Папка Downloads текущего пользователя
$Downloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$LocalMsiPath = Join-Path $Downloads "regime-1.5.0-462.msi"

# Путь к файлу MSI для установки
$OutputPath = Join-Path $TempFolder $MsiName

# Создаём папку Temp, если нет
if (!(Test-Path -Path $TempFolder)) {
    New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null
}

# Проверяем, есть ли локальный файл
if (Test-Path -Path $LocalMsiPath) {
    Write-Host "📂 Локальный файл найден: $LocalMsiPath"
    Copy-Item -Path $LocalMsiPath -Destination $OutputPath -Force
    Write-Host "✅ Файл скопирован в $OutputPath"
} else {
    # Скачиваем MSI
    Write-Host "📥 Скачиваю $Url ..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        Write-Host "✅ Файл скачан: $OutputPath"
    } catch {
        Write-Error "❌ Ошибка ска
