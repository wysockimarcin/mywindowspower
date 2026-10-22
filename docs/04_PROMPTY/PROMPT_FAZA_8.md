# PROMPT — FAZA 8: Czyszczenie dysku

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 8 — Czyszczenie dysku**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_8_CZYSZCZENIE.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 7 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 7 i ustaw status FAZY 8 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: bezpieczne zwalnianie miejsca na dysku (to jedyny obszar z trwałym usuwaniem plików, więc bezpieczeństwo ma pierwszeństwo). W szczególności:
- moduł `MWP.Cleanup`: kategorie zdefiniowane danymi, skan tylko do odczytu z rozmiarami,
- podgląd domyślny, usuwanie dopiero po potwierdzeniu; tylko ścieżki z definicji kategorii, pomijanie plików w użyciu i dowiązań (junction/symlink), nigdy dokumenty i pulpit,
- raport po czyszczeniu, analiza składników DISM (tylko analiza),
- widok `Cleanup.xaml` z postępem i anulowaniem,
- testy Pester wyłącznie na katalogach tymczasowych utworzonych w teście.
Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 8: <krótki opis>` i napisz: „Następna faza: FAZA 9 — Windows Update. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_9.md`. Otwórz nową rozmowę w Claude Code."
