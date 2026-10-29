# PROMPT — FAZA 15: Dyski i woluminy

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 15 — Dyski i woluminy**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_15_DYSKI.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 14 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 14 i ustaw status FAZY 15 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: moduł `MWP.Disks` do przeglądu dysków i woluminów komputera lokalnego i zdalnych (domyślnie tylko odczyt). W szczególności:
- dyski fizyczne, partycje, woluminy, pojemność i wolne miejsce, typ nośnika, stan zdrowia i liczniki niezawodności (tam, gdzie sprzęt je udostępnia), odporność na braki danych,
- funkcje przyjmują kontekst wykonania (`localhost` i komputer zdalny),
- widok `Disks.xaml` i widget „Wykorzystanie dysków" dla Dashboardu, eksport do JSON i tekstu,
- dopisanie modułu do `tests/Modules.Tests.ps1`, testy Pester z mockami.
Formatowanie, partycjonowanie i BitLocker są poza zakresem. Nie wykonuj pracy z innych faz.
- widget (korekta D-053): widget Dashboardu wg D-053 — każdy moduł deklaruje co najmniej jeden widget (reguła kompletności w `tests/UI/ModuleWidgets.Tests.ps1`): parametry wyboru danych z minimalnymi wartościami domyślnymi, `DefaultRefreshSeconds = 0` dla odczytów kosztownych, `LocalOnly`/`Enabled` w razie potrzeby; użytkownik ukrywa typ i ustawia domyślne parametry w widoku „Moduły” (sekcja „Widżety”).

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 15: <krótki opis>` i napisz: „Następna faza: FAZA 16 — Procesy i zasoby. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_16.md`. Otwórz nową rozmowę w Claude Code."
