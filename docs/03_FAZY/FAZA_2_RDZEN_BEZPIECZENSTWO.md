# FAZA 2 — Rdzeń i bezpieczeństwo zmian

**Status:** DO ZROBIENIA

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
- [ ] `Write-MwpLog` z plikiem dziennym i rotacją
- [ ] `Get-MwpSetting` / `Set-MwpSetting`
- [ ] `Test-MwpAdmin`, informacja o wersji PS i Windows
- [ ] Elewacja na życzenie
- [ ] `New-MwpRestorePoint` z obsługą błędów
- [ ] Rejestr cofnięć: zapis, lista, `Invoke-MwpUndo`
- [ ] `New-MwpResult`
- [ ] Wzorzec funkcji z `-WhatIf` opisany w `ARCHITEKTURA.md` + przykład
- [ ] Mechanizm listy ochronnej
- [ ] Pole komputera w logu, wpisie cofnięcia i `New-MwpResult` (domyślnie `localhost`)
- [ ] Kontrakt modułu: pola manifestu, `Get-MwpModuleDefinition`, walidacja wersji i zależności; manifesty modułów uzupełnione
- [ ] ADR: model wykonywania i współbieżności, kontrakt i cykl życia modułu, konfiguracja/logowanie/uprawnienia (w `DECYZJE.md`)
- [ ] Testy Pester przechodzą, PSScriptAnalyzer bez uwag
- [ ] Dokumentacja zaktualizowana, commit `FAZA 2: ...`

## Kryteria ukończenia
Kolejny moduł może użyć wzorca bez dopisywania własnej infrastruktury logowania i cofania, a rdzeń nie zakłada komputera lokalnego.

## Do weryfikacji na Windows 11
Punkt przywracania (wymaga administratora i włączonej ochrony systemu), elewacja, zapis w `%LOCALAPPDATA%`.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 3 — Komputery docelowe i połączenia zdalne. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_3.md`.
