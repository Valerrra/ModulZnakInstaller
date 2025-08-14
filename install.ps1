param(
    [string]$Url = "https://github.com/Valerrra/ModulZnakInstaller/releases/latest/download/regime.msi",
    [string]$TempFolder = "C:\Temp",
    [string]$MsiName = "install.msi"
)

# Включаем TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Путь к файлу MSI
$OutputPath = Join-Path $TempFolder $MsiName

# Создаём папку Temp, если нет
if (!(Test-Path -Path $TempFolder)) {
    New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null
}

# Скачиваем MSI
Write-Host "📥 Скачиваю $Url ..."
try {
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
    Write-Host "✅ Файл скачан: $OutputPath"
} catch {
    Write-Error "❌ Ошибка скачивания: $($_.Exception.Message)"
    exit 1
}

# Останавливаем службы перед установкой
$services = @("yenisei", "regime")
Write-Host "⏹ Останавливаю службы перед установкой..."
foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s -and $s.Status -eq 'Running') {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Write-Host "Служба $svc остановлена."
    }
}

# Устанавливаем MSI тихо
Write-Host "⚙️  Устанавливаю модуль..."
$Arguments = "/i `"$OutputPath`" /qn ADMINUSER=`"Modulznak`" ADMINPASSWORD=`"7]QI<&Oo!\jsy%3`" SERVERURL=`"https://rsapi.crpt.ru`" AUTOSERVICE=`"1`""
Start-Process "msiexec.exe" -ArgumentList $Arguments -Wait -NoNewWindow

# Запускаем службы после установки
Write-Host "▶ Запускаю службы..."
foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s -and $s.Status -ne 'Running') {
        Start-Service -Name $svc -ErrorAction SilentlyContinue
        Write-Host "Служба $svc запущена."
    }
}

Write-Host "🏁 Установка и перезапуск служб завершены!"
