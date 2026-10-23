# FAZA 2 — Rdzeń i bezpieczeństwo zmian

**Status:** ZAKOŃCZONA

## Cel
Wspólny fundament `MWP.Core`, dzięki któremu każda późniejsza zmiana systemowa jest podglądana, logowana i, tam gdzie się da, odwracalna, oraz kontrakt modułu (manifest, odkrywanie, walidacja). Rdzeń jest od początku przygotowany na wiele komputerów (`localhost` i zdalne, D-019): nie zakłada, że operacja dotyczy komputera lokalnego.

## Zależności
FAZA 1 zakończona.

## Zakres
- Logowanie: `Write-MwpLog` (poziomy, plik dzienny w `%LOCALAPPDATA%\MyWindowsPower\logs\`, rotacja).
- Konfiguracja: odczyt i zapis ustawień (`Get-MwpSetting`, `Set-MwpSetting`), źródło `config/settings.local.json` z wartościami domyślnymi z szablonu.
- Wykrywanie środowiska: `Test-MwpAdmin`, wersja PS, build Windows.
- Elewacja: uruchomienie ponowne z uprawnieniami administratora na życzenie (`Start-Process -Verb RunAs`).
- Punkt przywracania: `New-MwpRestorePoint` (`Checkpoint-Computer`, uwzględnij ograniczenie częstotliwości i wyłączoną ochronę systemu).
- Rejestr cofnięć: zapis stanu przed zmianą (JSON), `Save-MwpUndoEntry`, `Invoke-MwpUndo`, lista wpisów.
- Standardowy obiekt wyniku operacji (`New-MwpResult`: sukces, komunikat, stan przed/po, czy wymaga restartu).
- Wzorzec funkcji zmieniającej system: `SupportsShouldProcess`, `-WhatIf`, `-Confirm`, logowanie, wpis cofnięcia. Dokument wzorca w `docs/00_PROJEKT/ARCHITEKTURA.md`.
- Lista ochronna: mechanizm oznaczania elementów chronionych (dane w osobnym pliku).
- Testy Pester z mockami (bez zmian w realnym systemie).
- **Komputer w API rdzenia (D-019):** logowanie zapisuje nazwę komputera (domyślnie `localhost`), wpis rejestru cofnięć i `New-MwpResult` mają pole komputera docelowego, nie ma globalnego, zmiennego „bieżącego komputera". Samą obsługę kontekstu i połączeń zdalnych dostarcza FAZA 3.
- **Kontrakt modułu (stara koncepcja, sekcja 9):** manifest z polami `Id`, `Name`, `Version`, `Description`, `EntryPoint`, `MinimumHostVersion`, `Dependencies`, `Capabilities`, `SupportedPresentationModes`, `RequiredPermissions`, `ConfigurationSchema` (miejsce w manifeście `.psd1`, np. `PrivateData`, i nazwy pól do potwierdzenia w tej fazie); `Get-MwpModuleDefinition` (odkrywanie modułów w `src/Modules` po manifeście), walidacja zgodności wersji i brakujących zależności z czytelnym błędem. Wszystkie istniejące manifesty modułów dostają te pola.
- **Decyzje architektoniczne (ADR) do podjęcia i zapisania w `DECYZJE.md`** (problem, opcje, kryteria, wybór, uzasadnienie, konsekwencje — w skróconej formie): model wykonywania modułów i współbieżności (propozycja: moduły w procesie hosta, operacje długie i zdalne w runspace'ach z limitem równoległości, anulowaniem i limitami czasu; osobne procesy tylko przy uzasadnieniu), kontrakt modułu i cykl życia, konfiguracja, logowanie i zarządzanie uprawnieniami. Odkrywanie modułów obejmuje tylko `src/Modules`; instalator i aktualizacje modułów są poza zakresem (D-020).
- Z FAZY 1: przenieść wykrywanie środowiska (wersja PS, Windows 11, administrator) do `MWP.Core` i rozważyć użycie go w launcherze (D-017); rozważyć klasy operacji Odczyt/Zmiana/Destrukcyjna i zasady zapisu konfiguracji opisane w `ARCHITEKTURA.md` (D-015). Testy logiki umieszczać w `tests/Modules/MWP.Core/` (D-012), uruchamiać `.\tests\Invoke-Checks.ps1`.

## Poza zakresem
GUI, logika obszarów, kontekst wykonania, połączenia zdalne i instancje modułów (FAZA 3).

## Checklista
- [x] `Write-MwpLog` z plikiem dziennym i rotacją
- [x] `Get-MwpSetting` / `Set-MwpSetting`
- [x] `Test-MwpAdmin`, informacja o wersji PS i Windows
- [x] Elewacja na życzenie
- [x] `New-MwpRestorePoint` z obsługą błędów
- [x] Rejestr cofnięć: zapis, lista, `Invoke-MwpUndo`
- [x] `New-MwpResult`
- [x] Wzorzec funkcji z `-WhatIf` opisany w `ARCHITEKTURA.md` + przykład
- [x] Mechanizm listy ochronnej
- [x] Pole komputera w logu, wpisie cofnięcia i `New-MwpResult` (domyślnie `localhost`)
- [x] Kontrakt modułu: pola manifestu, `Get-MwpModuleDefinition`, walidacja wersji i zależności; manifesty modułów uzupełnione
- [x] ADR: model wykonywania i współbieżności, kontrakt i cykl życia modułu, konfiguracja/logowanie/uprawnienia (w `DECYZJE.md`)
- [x] Testy Pester przechodzą, PSScriptAnalyzer bez uwag
- [x] Dokumentacja zaktualizowana, commit `FAZA 2: ...`

## Kryteria ukończenia
Kolejny moduł może użyć wzorca bez dopisywania własnej infrastruktury logowania i cofania, a rdzeń nie zakłada komputera lokalnego.

## Do weryfikacji na Windows 11
Punkt przywracania (wymaga administratora i włączonej ochrony systemu), elewacja, zapis w `%LOCALAPPDATA%`.

## Wyniki
Zakończona 2026-10-23. Weryfikacja checklisty (wszystkie punkty ZROBIONE):

| Punkt | Dowód |
|---|---|
| `Write-MwpLog`, plik dzienny, rotacja | `src/Modules/MWP.Core/Public/Write-MwpLog.ps1`, `Private/Invoke-MwpLogRotation.ps1`; `tests/Modules/MWP.Core/Logging.Tests.ps1` (plik dzienny, komputer, poziomy, sekrety, rotacja, błąd zapisu) |
| `Get-MwpSetting` / `Set-MwpSetting` | `Public/Get-MwpSetting.ps1`, `Public/Set-MwpSetting.ps1`, `Private/Read-MwpSettingsData.ps1`; `Settings.Tests.ps1` (domyślne, nadpisania, uszkodzony plik, `schemaVersion`, zapis atomowy, `-WhatIf`, typy, cofnięcie) |
| `Test-MwpAdmin`, wersja PS i Windows | `Public/Test-MwpAdmin.ps1`, `Public/Get-MwpEnvironment.ps1`; `Environment.Tests.ps1` |
| Elewacja na życzenie | `Public/Request-MwpElevation.ps1`, `Start-MyWindowsPower.ps1 -Elevate`; `Environment.Tests.ps1` (mock `Start-Process`: RunAs, cytowanie, `-WhatIf`, anulowanie UAC) |
| `New-MwpRestorePoint` z obsługą błędów | `Public/New-MwpRestorePoint.ps1`; `RestorePoint.Tests.ps1` (brak administratora, `-WhatIf`, utworzenie, limit częstotliwości, kod 1058, wyjątek CIM, komputer zdalny) |
| Rejestr cofnięć | `Public/Save-MwpUndoEntry.ps1`, `Get-MwpUndoEntry.ps1`, `Invoke-MwpUndo.ps1`; `Undo.Tests.ps1` |
| `New-MwpResult` | `Public/New-MwpResult.ps1`; `Result.Tests.ps1` |
| Wzorzec z `-WhatIf` + przykład | `ARCHITEKTURA.md`, sekcja „Wzorzec funkcji zmieniającej system"; działający przykład `Set-MwpSetting` |
| Lista ochronna | `Data/protected-items.json`, `Public/Test-MwpProtectedItem.ps1`, `Get-MwpProtectedItem.ps1`; `ProtectedList.Tests.ps1` |
| Pole komputera (domyślnie `localhost`) | `-ComputerName` w `Write-MwpLog`, `Save-MwpUndoEntry`, `New-MwpResult`, `Format-MwpOperationTarget`, `New-MwpRestorePoint`; `Architecture.Tests.ps1` (domyślnie `localhost`, brak zmiennych globalnych i „bieżącego komputera") |
| Kontrakt modułu | `PrivateData.MWP` w 11 manifestach, `Public/Get-MwpModuleDefinition.ps1`, `Test-MwpModuleDefinition.ps1`; `ModuleContract.Tests.ps1`, `Modules.Tests.ps1`; walidacja w launcherze |
| ADR | `DECYZJE.md`: D-023 (wykonywanie i współbieżność), D-024 (kontrakt i cykl życia), D-025 (konfiguracja), D-026 (logowanie), D-027 (uprawnienia i klasy operacji), D-028 (rejestr cofnięć), D-029 (punkt przywracania, lista ochronna), D-030 (analizator) |
| Testy i analiza | `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: PowerShell 5.1.26100.9711 — 0 uwag, 393/393; PowerShell 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`, MSI) — 0 uwag, 393/393. Baza przed zmianami: 0 uwag, 175/175 w obu wersjach |
| Dokumentacja i commit | `STAN_PROJEKTU.md`, `CHANGELOG_FAZ.md`, `ARCHITEKTURA.md`, `DECYZJE.md`, `README.md`; commit `FAZA 2: ...` |

Testy: 393 (było 175): +22 w `tests/Modules.Tests.ps1` (kontrakt każdego z 11 modułów), +196 w `tests/Modules/MWP.Core/` (9 plików). Testy nie zmieniają systemu: CIM, `Start-Process` i sprawdzenie administratora są mockowane, katalog danych i konfiguracja podmienione na `TestDrive` (po przebiegu `%LOCALAPPDATA%\MyWindowsPower` i `config\settings.local.json` nie istnieją).

Wykryte różnice 5.1/7.x (opisane w `ARCHITEKTURA.md`): brak `Count` na pojedynczym `PSCustomObject` w 5.1 (błąd testu w pierwszym przebiegu 5.1, poprawiony), daty z `ConvertFrom-Json`, `$null` → pusty tekst w metodach .NET (`[NullString]::Value`).

DO WERYFIKACJI NA WINDOWS (ręcznie, wymaga zgody użytkownika, bo zmienia system lub pokazuje UAC): utworzenie prawdziwego punktu przywracania jako administrator i komunikat przy limicie 24 h oraz przy wyłączonej ochronie systemu; `.\Start-MyWindowsPower.ps1 -Elevate` (monit UAC, anulowanie); pierwszy zapis logu i rejestru cofnięć w prawdziwym `%LOCALAPPDATA%\MyWindowsPower`.

## Następna faza
FAZA 3 — Komputery docelowe i połączenia zdalne. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_3.md`.
