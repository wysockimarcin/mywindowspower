# PROMPT — FAZA 5: Zasilanie

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 5 — Zasilanie**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_5_ZASILANIE.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 4 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 4 i ustaw status FAZY 5 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: zarządzanie planami zasilania i ustawieniami energii. W szczególności:
- moduł `MWP.Power` na `powercfg`: lista, aktywny plan, przełączanie, duplikowanie, usuwanie z ochroną planu aktywnego; parsowanie po GUID, niezależne od języka systemu,
- plan „Najwyższa wydajność" (zweryfikuj GUID w dokumentacji Microsoft przed użyciem),
- hibernacja, szybkie uruchamianie, czasy wygaszania i uśpienia (AC/DC), raporty baterii i `energy`,
- widok `Power.xaml`; zmiany z `-WhatIf`, logiem i cofaniem (wzorzec z `MWP.Core`),
- testy Pester z mockami `powercfg`.
Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 5: <krótki opis>` i napisz: „Następna faza: FAZA 6 — Usługi Windows. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_6.md`. Otwórz nową rozmowę w Claude Code."
