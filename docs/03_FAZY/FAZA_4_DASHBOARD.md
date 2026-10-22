# FAZA 4 — Dashboard

**Status:** DO ZROBIENIA

## Cel
Pierwszy realny widok, bezpieczny (tylko odczyt): informacje o systemie i sprzęcie.

## Zależności
FAZY 2 i 3 zakończone.

## Zakres
- Moduł `MWP.Dashboard`: `Get-MwpSystemInfo` zwracający obiekt z danymi: system (wersja, build, data instalacji), uptime, CPU, RAM (użycie), GPU, dyski (pojemność, wolne miejsce, typ), płyta główna i BIOS, bateria (jeśli jest), podstawowy stan sieci.
- Użycie CIM (`Get-CimInstance`), bez przestarzałego WMI; odporność na brak danych.
- Widok `Dashboard.xaml`: kafelki, odświeżanie w tle, przycisk „Odśwież", automatyczne odświeżanie opcjonalne.
- Eksport raportu do JSON i tekstu.
- Testy Pester z mockami CIM.

## Poza zakresem
Zmiany w systemie.

## Checklista
- [ ] `Get-MwpSystemInfo` + podfunkcje
- [ ] Obsługa braków danych (np. brak baterii)
- [ ] Widok Dashboard z kafelkami
- [ ] Odświeżanie w tle bez zawieszania GUI
- [ ] Eksport JSON / tekst
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 4: ...`

## Kryteria ukończenia
Dane zgadzają się z narzędziami systemowymi (Menedżer zadań, `winver`, `systeminfo`).

## Do weryfikacji na Windows 11
Poprawność danych i wygląd widoku.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 5 — Zasilanie. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_5.md`.
