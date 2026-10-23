# mywindowspower

Osobisty panel do zarządzania systemami Windows 11 — komputerem lokalnym (`localhost`) i komputerami zdalnymi — napisany w PowerShellu z interfejsem graficznym WPF/XAML.

- **Platforma:** Windows 11
- **Język:** PowerShell (działa w 7.x i w wbudowanym 5.1)
- **GUI:** WPF + XAML, motyw jasny/ciemny
- **Uruchamianie:** skryptem `.ps1`
- **Komputery:** `localhost` i komputery zdalne; niezależne moduły, wiele instancji modułu, Dashboard z widgetami (zob. `docs/00_PROJEKT/ARCHITEKTURA.md`)

## Status

Projekt jest prowadzony fazami. Aktualny stan: [`docs/02_STAN/STAN_PROJEKTU.md`](docs/02_STAN/STAN_PROJEKTU.md).
Plan faz: [`docs/01_PLAN/PLAN_FAZ.md`](docs/01_PLAN/PLAN_FAZ.md).

## Dokumentacja

Cała dokumentacja i pamięć projektu znajdują się w folderze [`docs/`](docs/).
Zasady pracy w Claude Code opisuje [`CLAUDE.md`](CLAUDE.md).

## Uruchomienie

Wymagania: Windows 11, Windows PowerShell 5.1 (wbudowany) lub PowerShell 7.x.

W katalogu repozytorium:

```powershell
.\Start-MyWindowsPower.ps1
```

Launcher sprawdza wersję PowerShella, system i tryb STA (w razie potrzeby uruchamia się ponownie z `-STA`), wypisuje status administratora i importuje moduły z `src/Modules`, sprawdzając kontrakt każdego modułu (wersja, zależności). Niczego nie zmienia w systemie. Uprawnienia administratora tylko na życzenie: `.\Start-MyWindowsPower.ps1 -Elevate` (monit UAC). Logi aplikacji: `%LOCALAPPDATA%\MyWindowsPower\logs\`. Okno GUI pojawi się od FAZY 4, a obsługa komputerów zdalnych powstaje w FAZIE 3 (wymagania po stronie komputera zdalnego zostaną opisane tutaj w FAZIE 21).

Jeśli PowerShell blokuje skrypty, ustaw dla swojego konta `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

## Testy i analiza (dla dewelopera)

Jednorazowo:

```powershell
Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

Sprawdzenie (PSScriptAnalyzer + Pester):

```powershell
.\tests\Invoke-Checks.ps1
```

Używane wersje: Pester 6.2.0, PSScriptAnalyzer 1.25.0.
