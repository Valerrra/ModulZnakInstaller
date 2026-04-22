param(
    [string]$Url = "https://github.com/Valerrra/ModulZnakInstaller/releases/latest/download/regime-1.5.2-600.msi",
    [string]$TempFolder = "C:\Temp",
    [string]$MsiName = "regime-1.5.2-600.msi",
    [string]$LocalMsiPath = "$([Environment]::GetFolderPath('UserProfile'))\Downloads\regime-1.5.2-600.msi",
    [string]$ApplicationFolder = "C:\Program Files\Regime",
    [string]$AdminUser = "ARED",
    [string]$AdminPassword = "Ared2025",
    [string]$ServerUrl = "https://rsapi.crpt.ru",
    [string]$ProxyUrl,
    [string]$ProxyPort,
    [string]$ProxyUser,
    [string]$ProxyPass,
    [string]$LogPath = "C:\Temp\install.log",
    [switch]$Reinstall,
    [switch]$CleanInstall,
    [switch]$SkipAutoUpdater,
    [switch]$StrictAutoUpdater,
    [string]$AutoUpdaterPath,
    [int]$AutoUpdaterWaitSeconds = 20,
    [string]$AutoUpdaterLogPath = "C:\Temp\InstallAutoUpdateLM.log",
    [string]$InitToken,
    [string]$ClientId,
    [int]$ApiPort = 5995
)

function Invoke-MsiProcess {
    param(
        [string[]]$Arguments
    )

    $process = Start-Process "msiexec.exe" -ArgumentList ($Arguments -join " ") -Wait -NoNewWindow -PassThru
    return $process.ExitCode
}

function Get-LmProductCode {
    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($root in $uninstallRoots) {
        $item = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq "Локальный модуль Честный Знак" } |
            Select-Object -First 1
        if ($item -and $item.PSChildName) {
            return $item.PSChildName
        }
    }

    return "{6925DB33-0924-457F-84DD-71866268DC29}"
}

function Remove-LmInstallation {
    param(
        [string]$ApplicationFolder,
        [string]$TempFolder,
        [string]$LogPath
    )

    $productCode = Get-LmProductCode
    Write-Host " Выполняю полное удаление ЛМ ЧЗ: $productCode"

    $uninstallLogPath = Join-Path $TempFolder "uninstall-regime.log"
    $uninstallArguments = @(
        "/x"
        $productCode
        "/qn"
        "/norestart"
        "/l*v"
        "`"$uninstallLogPath`""
    )

    $uninstallExitCode = Invoke-MsiProcess -Arguments $uninstallArguments
    if ($uninstallExitCode -notin @(0, 1605, 1614, 3010)) {
        throw "Удаление MSI завершилось с кодом $uninstallExitCode."
    }
    if ($uninstallExitCode -eq 3010) {
        Write-Warning "  Удаление ЛМ ЧЗ запросило перезагрузку."
    }

    foreach ($svc in @("yenisei", "regime", "Apache2.2")) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            & sc.exe delete $svc | Out-Null
            Write-Host "  Служба $svc удалена."
        }
    }

    Get-Process -Name "epmd" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    $pathsToRemove = @(
        $ApplicationFolder,
        "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Честный Знак"
    )

    foreach ($path in $pathsToRemove) {
        if (Test-Path -Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Удалён остаток: $path"
        }
    }
}

function Find-AutoUpdaterInstaller {
    param(
        [string]$ApplicationFolder,
        [string]$TempFolder,
        [string]$ExplicitPath,
        [int]$WaitSeconds
    )

    $candidatePaths = @()
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $candidatePaths += $ExplicitPath
    }

    $candidatePaths += @(
        (Join-Path $ApplicationFolder "bin\InstallAutoUpdateLM.exe"),
        (Join-Path $ApplicationFolder "InstallAutoUpdateLM.exe"),
        (Join-Path $TempFolder "InstallAutoUpdateLM.exe"),
        (Join-Path "$([Environment]::GetFolderPath('UserProfile'))\Downloads" "InstallAutoUpdateLM.exe")
    )

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    do {
        foreach ($path in ($candidatePaths | Select-Object -Unique)) {
            if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -Path $path)) {
                return $path
            }
        }

        if (Test-Path -Path $ApplicationFolder) {
            $found = Get-ChildItem -Path $ApplicationFolder -Filter "InstallAutoUpdateLM.exe" -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName
            if ($found) {
                return $found
            }
        }

        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)

    return $null
}

function Test-MsiAutoUpdaterInstalled {
    param(
        [string]$LogPath
    )

    if ([string]::IsNullOrWhiteSpace($LogPath) -or -not (Test-Path -Path $LogPath)) {
        return $false
    }

    $patterns = @(
        "InstallAutoApdater. Код возврата 0",
        "Action ended .*InstallAutoApdater.*Return value 0"
    )

    foreach ($pattern in $patterns) {
        if (Select-String -Path $LogPath -Pattern $pattern -Quiet -SimpleMatch:$false) {
            return $true
        }
    }

    return $false
}

# Включаем TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Путь к файлу MSI для установки
$OutputPath = Join-Path $TempFolder $MsiName

# Создаём папку Temp, если нет
if (!(Test-Path -Path $TempFolder)) {
    New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null
}

# Проверяем, есть ли локальный файл
if (Test-Path -Path $LocalMsiPath) {
    Write-Host " Локальный файл найден: $LocalMsiPath"
    Copy-Item -Path $LocalMsiPath -Destination $OutputPath -Force
    Write-Host " Файл скопирован в $OutputPath"
} else {
    # Скачиваем MSI
    Write-Host " Скачиваю $Url ..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        Write-Host " Файл скачан: $OutputPath"
    } catch {
        Write-Error " Ошибка скачивания: $($_.Exception.Message)"
        exit 1
    }
}

# Останавливаем службы перед установкой и ждём полной остановки
$services = @("yenisei", "regime", "Apache2.2")
$runningServicesBeforeInstall = @{}
Write-Host " Останавливаю службы перед установкой..."
foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    $runningServicesBeforeInstall[$svc] = $false
    if ($s -and $s.Status -eq 'Running') {
        $runningServicesBeforeInstall[$svc] = $true
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Write-Host "Служба $svc остановлена, ожидаем полной остановки..."
        
        $timeout = 15
        $elapsed = 0
        while ((Get-Service -Name $svc).Status -ne 'Stopped' -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1
            $elapsed++
        }

        if ((Get-Service -Name $svc).Status -ne 'Stopped') {
            Write-Warning "  Служба $svc не остановлена полностью после $timeout секунд."
        } else {
            Write-Host "Служба $svc успешно остановлена."
        }
    }
}

if ($CleanInstall) {
    Remove-LmInstallation -ApplicationFolder $ApplicationFolder -TempFolder $TempFolder -LogPath $LogPath
}

# Устанавливаем MSI модуля в тихом режиме
Write-Host "  Устанавливаю модуль..."
$msiArguments = @(
    "/i"
    "`"$OutputPath`""
    "/qn"
    "ADMINUSER=`"$AdminUser`""
    "ADMINPASSWORD=`"$AdminPassword`""
    "APPLICATIONFOLDER=`"$ApplicationFolder`""
    "SERVERURL=`"$ServerUrl`""
    "AUTOSERVICE=`"1`""
)

if ($Reinstall) {
    $msiArguments += "REINSTALL_FLAG=`"1`""
}

if (-not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
    $msiArguments += "PROXYURL=`"$ProxyUrl`""
}

if (-not [string]::IsNullOrWhiteSpace($ProxyPort)) {
    $msiArguments += "PROXYPORT=`"$ProxyPort`""
}

if (-not [string]::IsNullOrWhiteSpace($ProxyUser)) {
    $msiArguments += "PROXYUSER=`"$ProxyUser`""
}

if (-not [string]::IsNullOrWhiteSpace($ProxyPass)) {
    $msiArguments += "PROXYPASS=`"$ProxyPass`""
}

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $msiArguments += "/l*v"
    $msiArguments += "`"$LogPath`""
}

$msiExitCode = Invoke-MsiProcess -Arguments $msiArguments
if ($msiExitCode -ne 0) {
    throw "Установка MSI завершилась с кодом $msiExitCode."
}

# Устанавливаем автоапдейтера в тихом режиме
$msiInstalledAutoUpdater = Test-MsiAutoUpdaterInstalled -LogPath $LogPath
$ResolvedUpdaterPath = Find-AutoUpdaterInstaller -ApplicationFolder $ApplicationFolder -TempFolder $TempFolder -ExplicitPath $AutoUpdaterPath -WaitSeconds $AutoUpdaterWaitSeconds
if (-not $SkipAutoUpdater -and $msiInstalledAutoUpdater) {
    Write-Host "  MSI уже установил автоапдейтер, повторный запуск пропускаю."
} elseif (-not $SkipAutoUpdater -and $ResolvedUpdaterPath) {
    Write-Host "  Устанавливаю автоапдейтера в тихом режиме..."
    Write-Host "  Найден установщик автообновления: $ResolvedUpdaterPath"
    $autoUpdaterStdOutLogPath = [System.IO.Path]::ChangeExtension($AutoUpdaterLogPath, ".stdout.log")
    $autoUpdaterStdErrLogPath = [System.IO.Path]::ChangeExtension($AutoUpdaterLogPath, ".stderr.log")
    $updaterProcess = Start-Process $ResolvedUpdaterPath -ArgumentList "/qn /norestart" -Wait -PassThru -RedirectStandardOutput $autoUpdaterStdOutLogPath -RedirectStandardError $autoUpdaterStdErrLogPath
    if ($updaterProcess.ExitCode -notin @(0, 3010)) {
        $message = "Установка автоапдейтера завершилась с кодом $($updaterProcess.ExitCode). Логи: $autoUpdaterStdOutLogPath ; $autoUpdaterStdErrLogPath"
        if ($StrictAutoUpdater) {
            throw $message
        }
        Write-Warning "  $message"
    } else {
        Write-Host " Автоапдейтер установлен."
    }
    if ($updaterProcess.ExitCode -eq 3010) {
        Write-Warning "  Автоапдейтер установлен, но запрошена перезагрузка."
    }
} elseif (-not $SkipAutoUpdater) {
    $message = "InstallAutoUpdateLM.exe не найден. По MSI-логу внутренний шаг автообновления мог быть пропущен условием."
    if ($StrictAutoUpdater) {
        throw $message
    }
    Write-Warning "  $message"
}

# Запускаем службы после установки
Write-Host " Запускаю службы..."
foreach ($svc in $services) {
    if (-not $runningServicesBeforeInstall[$svc]) {
        continue
    }

    $timeout = 30
    $elapsed = 0
    $s = $null

    while (-not $s -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 1
        $elapsed++
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    }

    if (-not $s) {
        Write-Warning "  Служба $svc не найдена после установки."
        continue
    }

    if ($s.Status -ne 'Running') {
        Start-Service -Name $svc -ErrorAction SilentlyContinue

        $startTimeout = 30
        $startElapsed = 0
        while ((Get-Service -Name $svc -ErrorAction SilentlyContinue).Status -ne 'Running' -and $startElapsed -lt $startTimeout) {
            Start-Sleep -Seconds 1
            $startElapsed++
        }

        $startedService = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($startedService -and $startedService.Status -eq 'Running') {
            Write-Host "Служба $svc запущена."
        } else {
            Write-Warning "  Служба $svc не перешла в состояние Running."
        }
    } else {
        Write-Host "Служба $svc уже запущена."
    }
}

if (-not [string]::IsNullOrWhiteSpace($InitToken)) {
    Write-Host " Выполняю инициализацию ЛМ ЧЗ..."

    $pair = "{0}:{1}" -f $AdminUser, $AdminPassword
    $basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
    $headers = @{
        Accept        = "application/json"
        Authorization = "Basic $basicAuth"
    }

    if (-not [string]::IsNullOrWhiteSpace($ClientId)) {
        $headers["X-ClientId"] = $ClientId
    }

    $initUrl = "http://127.0.0.1:$ApiPort/api/v1/init"
    $body = @{ token = $InitToken } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $initUrl -Method Post -Headers $headers -ContentType "application/json" -Body $body
        Write-Host " Инициализация завершена."
    } catch {
        throw "Ошибка инициализации через $initUrl : $($_.Exception.Message)"
    }
}
