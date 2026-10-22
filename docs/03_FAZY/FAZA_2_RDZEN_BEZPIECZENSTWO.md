# FAZA 2 — Rdzeń i bezpieczeństwo zmian

**Status:** DO ZROBIENIA

## Cel
Wspólny fundament `MWP.Core`, dzięki któremu każda późniejsza zmiana systemowa jest podglądana, logowana i, tam gdzie się da, odwracalna.

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

## Poza zakresem
GUI i logika obszarów.

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
- [ ] Testy Pester przechodzą, PSScriptAnalyzer bez uwag
- [ ] Dokumentacja zaktualizowana, commit `FAZA 2: ...`

## Kryteria ukończenia
Kolejny moduł może użyć wzorca bez dopisywania własnej infrastruktury logowania i cofania.

## Do weryfikacji na Windows 11
Punkt przywracania (wymaga administratora i włączonej ochrony systemu), elewacja, zapis w `%LOCALAPPDATA%`.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 3 — Szkielet GUI. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_3.md`.
