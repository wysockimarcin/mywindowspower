# PROMPT — FAZA 10: Windows Update

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 10 — Windows Update**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_10_WINDOWS_UPDATE.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 9 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 9 i ustaw status FAZY 10 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: kontrola nad aktualizacjami Windows bez zewnętrznych modułów. W szczególności:
- moduł `MWP.Update` na API COM (`Microsoft.Update.Session`): oczekujące aktualizacje, historia, informacja o restarcie,
- stan usług Windows Update,
- pauza aktualizacji z cofaniem (sprawdź, które klucze są obsługiwane w Windows 11),
- reset komponentów (zachowaj stare foldery, podgląd kroków, potwierdzenie),
- decyzja o instalacji aktualizacji z poziomu GUI zapisana w `DECYZJE.md`,
- widok `Update.xaml`, testy Pester z mockami COM,
- obsługa komputera docelowego (D-019): zbadaj ograniczenia COM Windows Update Agent w sesji zdalnej i zapisz decyzję.
Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 10: <krótki opis>` i napisz: „Następna faza: FAZA 11 — Sieć. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_11.md`. Otwórz nową rozmowę w Claude Code."
