# FAZA 19 — Samodzielne uruchamianie i CLI

**Status:** DO ZROBIENIA

## Cel
Samodzielne uruchamianie modułów bez głównego okna oraz tryb CLI (koncepcja pierwotna, D-020). Ta sama logika co w GUI, bez osobnej implementacji.

## Zależności
FAZY 2, 3 i 4 zakończone oraz co najmniej jeden moduł obszaru (np. FAZA 7 — Usługi).

## Zakres
- Launcher modułu: funkcja `Invoke-MwpModule` z aliasem `apprun` (składnia przykładowa, do zatwierdzenia): `apprun "Services"`, `apprun "Services" -ComputerName "<nazwa>"`.
- Launcher znajduje i weryfikuje moduł (manifest, zgodność wersji, zależności; wyszukuje przez `Get-MwpModuleDefinition`: `src/Modules`, `<katalog danych>\modules` i dawny `src/Modules/Installed`, D-031, D-038), buduje kontekst wykonania dla wskazanego komputera, uruchamia widok w osobnym oknie (tryb Standalone) albo tryb CLI (obiekty na wyjściu), zachowuje walidację, autoryzację i logowanie. Tryb samodzielny nie omija zabezpieczeń.
- Moduł deklaruje w manifeście obsługiwane tryby prezentacji (`SupportedPresentationModes`): Embedded, SeparateWindow, DashboardWidget, Standalone, CLI. Nie każdy moduł musi obsługiwać wszystkie.
- Czytelne błędy przy braku modułu lub zależności. Moduł uruchamiany samodzielnie nie ładuje całego hosta.
- Testy Pester: uruchomienie modułu bez hosta, błędna nazwa modułu, brak zależności.

## Poza zakresem
Instalacja launchera w `PATH`, pakowanie do `.exe`, osobny proces na moduł (chyba że decyzja o modelu procesów z FAZY 2 stanowi inaczej).

## Checklista
- [ ] `Invoke-MwpModule` i alias `apprun`
- [ ] Weryfikacja modułu i zależności, czytelne błędy
- [ ] Tryb Standalone (okno) i CLI dla co najmniej jednego modułu
- [ ] Zachowanie walidacji, autoryzacji i logowania w trybie samodzielnym
- [ ] Testy Pester (moduł bez hosta), PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 19: ...`

## Kryteria ukończenia
Co najmniej jeden moduł uruchamia się samodzielnie dla `localhost` i komputera zdalnego, z tą samą logiką co w głównym oknie.

## Do weryfikacji na Windows 11
Uruchomienie `apprun` z terminala, okno Standalone, tryb CLI.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 20 — Testy i hardening. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_20.md`.
