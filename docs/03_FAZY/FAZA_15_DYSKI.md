# FAZA 15 — Dyski i woluminy

**Status:** DO ZROBIENIA

## Cel
Przegląd dysków i woluminów komputera lokalnego i zdalnych (moduł z koncepcji pierwotnej, D-020). Domyślnie tylko odczyt.

## Zależności
FAZY 2, 3 i 4 zakończone (widget Dashboardu wymaga też FAZY 5).

## Zakres
- Moduł `MWP.Disks`: dyski fizyczne, partycje, woluminy (litera, system plików, pojemność, wolne miejsce, etykieta), typ nośnika (SSD/HDD), stan zdrowia i liczniki niezawodności, tam gdzie sprzęt je udostępnia (`Get-PhysicalDisk`, `Get-StorageReliabilityCounter`, CIM jako zapasowa ścieżka).
- Wszystkie funkcje przyjmują kontekst wykonania i działają dla `localhost` i komputera zdalnego.
- Widok `Disks.xaml` (pełny widok) oraz widget „Wykorzystanie dysków" dla Dashboardu (kontrakt widgetu z FAZY 5).
- Eksport listy do JSON i tekstu.
- Testy Pester z mockami.
- Widget (korekta D-053): widget Dashboardu wg D-053 — każdy moduł deklaruje co najmniej jeden widget (reguła kompletności w `tests/UI/ModuleWidgets.Tests.ps1`): parametry wyboru danych z minimalnymi wartościami domyślnymi, `DefaultRefreshSeconds = 0` dla odczytów kosztownych, `LocalOnly`/`Enabled` w razie potrzeby; użytkownik ukrywa typ i ustawia domyślne parametry w widoku „Moduły” (sekcja „Widżety”).

## Poza zakresem
Formatowanie, partycjonowanie, zmiana liter dysków, BitLocker, SMART w głąb (surowe atrybuty producenta).

## Checklista
- [ ] `Get-MwpDisk`, `Get-MwpVolume` z odpornością na brak danych (np. brak liczników niezawodności)
- [ ] Moduł dopisany do listy w `tests/Modules.Tests.ps1`
- [ ] Widok `Disks.xaml` i widget Dashboardu
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Widget Dashboardu zgodny z D-053 (parametry z minimum domyślnym, reguła kompletności)
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 15: ...`

## Kryteria ukończenia
Dane zgadzają się z Zarządzaniem dyskami i Menedżerem zadań; moduł nie zmienia niczego w systemie.

## Do weryfikacji na Windows 11
Poprawność danych na realnym sprzęcie (SSD i HDD, dysk zewnętrzny), odczyt z komputera zdalnego.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 16 — Procesy i zasoby. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_16.md`.
