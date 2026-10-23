# FAZA 5 — Dashboard

**Status:** DO ZROBIENIA

## Cel
Pierwszy realny widok, bezpieczny (tylko odczyt): informacje o systemie i sprzęcie, oraz Dashboard jako konfigurowalna kompozycja niezależnych widgetów, które mogą pokazywać różne komputery jednocześnie (D-019).

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Dashboard`: `Get-MwpSystemInfo` (przyjmuje kontekst wykonania, działa dla `localhost` i komputera zdalnego) zwracający obiekt z danymi: system (wersja, build, data instalacji), uptime, CPU, RAM (użycie), GPU, dyski (pojemność, wolne miejsce, typ), płyta główna i BIOS, bateria (jeśli jest), podstawowy stan sieci.
- Użycie CIM (`Get-CimInstance`), bez przestarzałego WMI; odporność na brak danych.
- Widok `Dashboard.xaml`: kafelki, odświeżanie w tle, przycisk „Odśwież", automatyczne odświeżanie opcjonalne.
- Eksport raportu do JSON i tekstu.
- **Kontrakt widgetu (ADR):** widget to osobny kontrakt prezentacji danych, a nie miniaturowe okno: własna konfiguracja, jawne powiązanie z instancją modułu lub źródłem danych i komputerem docelowym, korzystanie z tych samych usług aplikacyjnych co pełny widok. Stany: ładowanie, błąd, brak danych, utrata połączenia.
- **Dashboard (widok `Dashboard.xaml`):** dodawanie i usuwanie widgetów, wybór komputera i parametrów modułu dla każdego widgetu, rozmiar i położenie (jeśli pozwala model UI), odświeżanie ręczne i automatyczne z kontrolowaną częstotliwością, zapis i odtworzenie konfiguracji po ponownym uruchomieniu (miejsce zapisu do ustalenia w `DECYZJE.md`, propozycja: plik lokalny poza repozytorium).
- **Izolacja widgetów:** błąd jednego widgetu ani utrata połączenia z jednym komputerem nie zatrzymuje pozostałych; limit równoległych zadań w tle; usunięcie widgetu anuluje jego zadania i zwalnia zasoby.
- Pierwsze widgety: informacje o systemie lokalnym i wybranego komputera zdalnego. Kolejne moduły dostarczają własne widgety w swoich fazach.
- Testy Pester z mockami CIM.

## Poza zakresem
Zmiany w systemie.

## Checklista
- [ ] `Get-MwpSystemInfo` + podfunkcje
- [ ] Obsługa braków danych (np. brak baterii)
- [ ] Widok Dashboard z kafelkami
- [ ] Odświeżanie w tle bez zawieszania GUI
- [ ] Eksport JSON / tekst
- [ ] `Get-MwpSystemInfo` działa dla `localhost` i komputera zdalnego
- [ ] Kontrakt widgetu opisany w `DECYZJE.md` i `ARCHITEKTURA.md`
- [ ] Dashboard: dodawanie i usuwanie widgetów, komputer per widget, odświeżanie ręczne i automatyczne
- [ ] Izolacja widgetów (awaria jednego nie zatrzymuje reszty), anulowanie zadań przy usunięciu
- [ ] Zapis i odtworzenie konfiguracji Dashboardu
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 5: ...`

## Kryteria ukończenia
Dane zgadzają się z narzędziami systemowymi (Menedżer zadań, `winver`, `systeminfo`); dwa widgety dla dwóch komputerów działają niezależnie, a utrata połączenia z jednym nie zatrzymuje drugiego.

## Do weryfikacji na Windows 11
Poprawność danych i wygląd widoku, konfiguracja widgetów dla komputera lokalnego i zdalnego, odtworzenie układu po ponownym uruchomieniu.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 6 — Zasilanie. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_6.md`.
