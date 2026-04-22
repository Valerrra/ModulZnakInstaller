# ModulZnakInstaller

Установка ЛМ ЧЗ одной командой:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Valerrra/ModulZnakInstaller/main/install.ps1 | iex"
```

Что хранится в репозитории:

- `install.ps1` - сценарий установки и обновления ЛМ ЧЗ
- `scripts/publish-release.ps1` - публикация MSI в GitHub Release

Что не хранится в git:

- `regime-1.5.2-600.msi` - загружается как asset релиза

Публикация релиза после установки `gh`:

```powershell
pwsh .\scripts\publish-release.ps1 -Tag v1.5.2-600 -MsiPath "D:\Работа\Программы\regime-1.5.2-600.msi"
```

После публикации `install.ps1` будет скачивать MSI из `latest` release.
