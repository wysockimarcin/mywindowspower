# FAZA 16 — Procesy i zasoby

**Status:** DO ZROBIENIA

## Cel
Przegląd procesów i monitorowanie zasobów komputera lokalnego i zdalnych (moduł z koncepcji pierwotnej, D-020).

## Zależności
FAZY 2, 3 i 4 zakończone (widget Dashboardu wymaga też FAZY 5).

## Zakres
- Moduł `MWP.Processes`: lista procesów (nazwa, identyfikator, użytkownik, ścieżka, czas startu, CPU, pamięć), filtry i sortowanie, drzewo procesów.
- Monitorowanie zasobów: CPU, pamięć, dysk, sieć (CIM / liczniki wydajności), z kontrolowaną częstotliwością odświeżania.
- Zakończenie procesu jako operacja **Destrukcyjna**: jawne potwierdzenie z nazwą procesu i komputera, log, **lista ochronna** procesów krytycznych (np. `System`, `csrss`, `wininit`, `lsass`) — blokada w GUI.
- Wszystkie funkcje przyjmują kontekst wykonania; działają dla `localhost` i komputera zdalnego.
- Widok `Processes.xaml` i widget „Zużycie zasobów" dla Dashboardu.
- Testy Pester z mockami.
- Widget (korekta D-053): widget Dashboardu wg D-053 — każdy moduł deklaruje co najmniej jeden widget (reguła kompletności w `tests/UI/ModuleWidgets.Tests.ps1`): parametry wyboru danych z minimalnymi wartościami domyślnymi, `DefaultRefreshSeconds = 0` dla odczytów kosztownych, `LocalOnly`/`Enabled` w razie potrzeby; użytkownik ukrywa typ i ustawia domyślne parametry w widoku „Moduły” (sekcja „Widżety”).

## Poza zakresem
Zmiana priorytetów i powinowactwa, zrzuty pamięci, uruchamianie procesów na komputerze zdalnym.

## Checklista
- [ ] `Get-MwpProcess`, odczyt zasobów
- [ ] Zakończenie procesu z potwierdzeniem i listą ochronną
- [ ] Moduł dopisany do listy w `tests/Modules.Tests.ps1`
- [ ] Widok `Processes.xaml` i widget Dashboardu
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Widget Dashboardu zgodny z D-053 (parametry z minimum domyślnym, reguła kompletności)
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 16: ...`

## Kryteria ukończenia
Procesów z listy ochronnej nie da się zakończyć z GUI; dane zgadzają się z Menedżerem zadań.

## Do weryfikacji na Windows 11
Zgodność danych z Menedżerem zadań, zakończenie procesu testowego (nie krytycznego), odczyt z komputera zdalnego.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 17 — Użytkownicy i grupy lokalne. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_17.md`.
