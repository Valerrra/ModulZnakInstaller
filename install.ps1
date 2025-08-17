param(
    [string]$Url = "https://github.com/Valerrra/ModulZnakInstaller/releases/latest/download/regime.msi",
    [string]$TempFolder = "C:\Temp",
    [string]$MsiName = "install.msi"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Downloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$LocalMsiPath = Join-Path $Downloads "regime-1.5.0-462.msi"
$OutputPath   = Join-Path $TempFolder $MsiName

if (!(Test-Path $TempFolder)) { New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null }

if (Test-Path $LocalMsiPath) {
    Copy-Item $LocalMsiPath $OutputPath -Force
} else {
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
}

$services = @("yenisei", "regime", "Apache2.2")
foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s -and $s.Status -eq 'Running') {
        Stop-Service $svc -Force
        Start-Sleep 3
    }
}

$Arguments = "/i `"$OutputPath`" /qn ADMINUSER=`"Modulznak`" ADMINPASSWORD=`"7]QI<&Oo!\jsy%3`" SERVERURL=`"https://rsapi.crpt.ru`" AUTOSERVICE=`"1`""
Start-Process msiexec.exe -ArgumentList $Arguments -Wait -NoNewWindow

foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s -and $s.Status -ne 'Running') { Start-Service $svc }
}

$installer = "C:\Program Files\Regime\bin\InstallAutoUpdateLM.exe"
if (Test-Path $installer) {
    Start-Process $installer -ArgumentList "/S" -Wait -NoNewWindow
}

Restart-Computer -Force
