# Przykłady

## `MWP.Przyklad` — moduł przykładowy do paczki `.mwpmod`

Moduł z kontraktem `PrivateData.MWP` (D-024), który deklaruje `RemoteTarget` oraz tryby `Embedded`
i `SeparateWindow` (od wersji 1.1.0 także `DashboardWidget`). Służy do ręcznej weryfikacji FAZY 4 i 5:

- instalacja i odinstalowanie z widoku **Moduły** (D-031),
- dwie instancje tego samego modułu dla dwóch komputerów (localhost i komputer zdalny),
- tryb w oknie głównym i w osobnym oknie,
- (FAZA 5) widget Dashboardu „Komputer (przykład)” (pole `Widgets`, D-043): po instalacji **Pulpit → + Dodaj widget**;
  po odinstalowaniu modułu jego widgety znikają z Pulpitu i z `config/settings.local.json` (D-031).
  Wersja 1.0.0 (FAZA 4) nie ma widgetu — jeśli jest zainstalowana, odinstaluj ją w widoku „Moduły” i zainstaluj 1.1.0
  (host nie aktualizuje modułów, D-031). Paczka jest wzorcem dla autorów modułów: od D-053 każdy moduł deklaruje widget.

Moduł nie jest wbudowany (folder `samples` nie jest skanowany przez `Get-MwpModuleDefinition`).
Paczkę buduje się ręcznie — archiwum ZIP z jednym folderem głównym `MWP.Przyklad`:

```powershell
$zip = Join-Path -Path $env:TEMP -ChildPath 'MWP.Przyklad.zip'
Compress-Archive -Path .\samples\MWP.Przyklad -DestinationPath $zip -Force
Move-Item -LiteralPath $zip -Destination (Join-Path -Path $env:TEMP -ChildPath 'MWP.Przyklad.mwpmod') -Force
```

Potem w aplikacji: **Moduły → Zainstaluj z pliku .mwpmod…** i wybór `%TEMP%\MWP.Przyklad.mwpmod`.
Suma SHA-256 w oknie potwierdzenia: `Get-FileHash $env:TEMP\MWP.Przyklad.mwpmod -Algorithm SHA256`.
Poprawność paczki sprawdza test `tests/Samples.Tests.ps1`.
