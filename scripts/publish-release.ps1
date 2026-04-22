param(
    [string]$Repo = "Valerrra/ModulZnakInstaller",
    [string]$Tag = "v1.5.2-600",
    [string]$Title = "regime-1.5.2-600",
    [string]$MsiPath,
    [string]$Notes = "Release for one-command installation"
)

if ([string]::IsNullOrWhiteSpace($MsiPath)) {
    throw "Не указан параметр MsiPath."
}

if (!(Test-Path -Path $MsiPath)) {
    throw "MSI не найден: $MsiPath"
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    throw "GitHub CLI gh не установлен."
}

gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI не авторизован."
}

gh release view $Tag --repo $Repo *> $null
if ($LASTEXITCODE -ne 0) {
    gh release create $Tag $MsiPath --repo $Repo --title $Title --notes $Notes
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось создать релиз $Tag."
    }
} else {
    gh release upload $Tag $MsiPath --repo $Repo --clobber
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось загрузить MSI в релиз $Tag."
    }
}

Write-Host "Релиз $Tag обновлён."
