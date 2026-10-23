# My Windows Power

Modularna aplikacja desktopowa oparta na PowerShell do lokalnego i zdalnego zarządzania komputerami z Windows 11. Składa się z hosta oraz niezależnych modułów administracyjnych.

> **Status:** wczesny etap. Istnieje dokumentacja architektury, konfiguracja narzędzi i pierwsze testy struktury repozytorium. Kodu hosta i modułów jeszcze nie ma.

## Dokumentacja

Pełne założenia, zasady architektury, decyzje (wraz ze statusem) i zasady pracy znajdują się w [`CLAUDE.md`](./CLAUDE.md). To główny dokument projektu.

## Wymagania

- Windows 11.
- PowerShell 7.6 (wydanie LTS) do pracy deweloperskiej i uruchamiania hosta. Kod wykonywany na komputerach docelowych ma być zgodny z Windows PowerShell 5.1 (zob. `CLAUDE.md`, sekcja 5).
- Moduł **Pester** w wersji 5.0 lub nowszej (testy).
- Moduł **PSScriptAnalyzer** (analiza statyczna).

Instalacja modułów (jednorazowo, w PowerShell 7):

```powershell
Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

Sprawdź zainstalowane wersje poleceniem `Get-Module Pester, PSScriptAnalyzer -ListAvailable` i wpisz tu użyte wersje:

- Pester: _do uzupełnienia po pierwszym uruchomieniu_
- PSScriptAnalyzer: _do uzupełnienia po pierwszym uruchomieniu_

## Polecenia

Wszystkie polecenia uruchamiaj w PowerShell 7. Skrypty same ustalają katalog główny projektu, więc można je uruchomić z dowolnego katalogu.

```powershell
./scripts/Invoke-MwpTests.ps1                      # testy jednostkowe i kontraktowe
./scripts/Invoke-MwpTests.ps1 -Type Integration    # testy integracyjne (tylko cele z pliku lokalnego)
./scripts/Invoke-MwpLint.ps1                       # analiza statyczna
```

## Testy integracyjne

Działają tylko na celach z lokalnego pliku `tests/Integration/targets.local.psd1`, którego nie ma w repozytorium (jest w `.gitignore`). Skopiuj szablon `tests/Integration/targets.example.psd1` i wpisz własne cele. Domyślnie dozwolone są wyłącznie operacje odczytu. Szczegóły i zasady bezpieczeństwa: `CLAUDE.md`, sekcje 12 i 15.5. Bez pliku celów testy integracyjne są pomijane.

## Dane aplikacji

Dane (konfiguracja, układ Dashboardu, logi) leżą domyślnie w `./data/`, poza repozytorium. Lokalizację można zmienić (`CLAUDE.md`, sekcja 14.1).
