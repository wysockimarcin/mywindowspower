# FAZA 1 — Szkielet techniczny

**Status:** DO ZROBIENIA

## Cel
Działający, pusty projekt: da się go uruchomić, przeanalizować i przetestować, zanim powstanie jakakolwiek funkcja.

## Zależności
FAZA 0 zakończona.

## Zakres
- Launcher `Start-MyWindowsPower.ps1`: wykrycie wersji PowerShella (5.1 / 7.x), sprawdzenie systemu (Windows 11), sprawdzenie trybu STA (w razie potrzeby ponowne uruchomienie z `-STA`), import modułów z `src/Modules`, informacja po polsku o błędach.
- Szkielet modułów `src/Modules/MWP.*` z manifestami `.psd1` i plikami `.psm1` (puste lub z jedną funkcją-zaślepką) dla wszystkich obszarów z `ARCHITEKTURA.md`.
- Konfiguracja Pester 5 (`tests/`) i pierwszy test (ładowanie modułów).
- `PSScriptAnalyzerSettings.psd1` z regułami zgodności z 5.1 (np. `PSUseCompatibleSyntax`, `PSUseCompatibleCmdlets`).
- `tests/Invoke-Checks.ps1`: uruchamia analizę i testy jednym poleceniem.
- `config/settings.example.json`.
- Zasada kodowania: pliki `.ps1`/`.psm1` jako UTF-8 z BOM; opcjonalnie `.editorconfig`.
- Weryfikacja, czy układ katalogów z `ARCHITEKTURA.md` jest nadal właściwy (korekta + wpis w `DECYZJE.md`).

## Poza zakresem
GUI, logika obszarów, funkcje zmieniające system.

## Checklista
- [ ] Launcher uruchamia się w PS 5.1 i 7.x i wypisuje wersję oraz status administratora
- [ ] Wykrywanie STA i ponowne uruchomienie z `-STA`
- [ ] Szkielety modułów dla wszystkich obszarów + manifesty `.psd1`
- [ ] Pester: test ładowania wszystkich modułów
- [ ] `PSScriptAnalyzerSettings.psd1`
- [ ] `tests/Invoke-Checks.ps1` działa
- [ ] `config/settings.example.json`
- [ ] Pliki zapisane jako UTF-8 z BOM
- [ ] Dokumentacja zaktualizowana, `README.md` z instrukcją uruchomienia launchera
- [ ] Commit `FAZA 1: ...`

## Kryteria ukończenia
Launcher startuje, wszystkie moduły się importują, analiza i testy przechodzą bez błędów.

## Do weryfikacji na Windows 11
Uruchomienie launchera w `powershell.exe` (5.1) i `pwsh` (7.x); zachowanie przy `ExecutionPolicy`.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 2 — Rdzeń i bezpieczeństwo zmian. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_2.md`.
