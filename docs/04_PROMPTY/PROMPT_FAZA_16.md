# PROMPT — FAZA 16: Procesy i zasoby

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 16 — Procesy i zasoby**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_16_PROCESY.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 15 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 15 i ustaw status FAZY 16 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: moduł `MWP.Processes` do przeglądu procesów i monitorowania zasobów komputera lokalnego i zdalnych. W szczególności:
- lista procesów z filtrami, drzewo procesów, odczyt CPU, pamięci, dysku i sieci z kontrolowaną częstotliwością odświeżania,
- zakończenie procesu jako operacja Destrukcyjna (potwierdzenie z nazwą procesu i komputera, log) oraz lista ochronna procesów krytycznych,
- funkcje przyjmują kontekst wykonania (`localhost` i komputer zdalny),
- widok `Processes.xaml` i widget „Zużycie zasobów" dla Dashboardu,
- dopisanie modułu do `tests/Modules.Tests.ps1`, testy Pester z mockami.
Nie wykonuj pracy z innych faz.
- widget (korekta D-053): widget Dashboardu wg D-053 — każdy moduł deklaruje co najmniej jeden widget (reguła kompletności w `tests/UI/ModuleWidgets.Tests.ps1`): parametry wyboru danych z minimalnymi wartościami domyślnymi, `DefaultRefreshSeconds = 0` dla odczytów kosztownych, `LocalOnly`/`Enabled` w razie potrzeby; użytkownik ukrywa typ i ustawia domyślne parametry w widoku „Moduły” (sekcja „Widżety”).

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 16: <krótki opis>` i napisz: „Następna faza: FAZA 17 — Użytkownicy i grupy lokalne. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_17.md`. Otwórz nową rozmowę w Claude Code."
