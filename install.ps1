param(
    [string]$Url = "https://github.com/USERNAME/REPO/releases/latest/download/regime.msi",
    [string]$TempFolder = "C:\Temp",
    [string]$MsiName = "install.msi"
)

# Включаем TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Путь к файлу
$OutputPath = Join-Path $TempFolder $MsiName

# Создаем папку, если нет
if (!(Test-Path -Path $TempFolder)) {
    New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null
}

# Скачиваем MSI
Write-Host "Скачиваю $Url ..."
try {
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
    Write-Host "Файл скачан: $OutputPath"
} catch {
    Write-Error "Ошибка скачивания: $($_.Exception.Message)"
    exit 1
}

# Устанавливаем MSI тихо
Write-Host "Устанавливаю модуль..."
$Arguments = "/i `"$OutputPath`" /qn ADMINUSER=`"Modulznak`" ADMINPASSWORD=`"7]QI<&Oo!\jsy%3`" SERVERURL=`"https://rsapi.crpt.ru`" AUTOSERVICE=`"1`""
Start-Process "msiexec.exe" -ArgumentList $Arguments -Wait -NoNewWindow
Write-Host "✅ Установка завершена!"
