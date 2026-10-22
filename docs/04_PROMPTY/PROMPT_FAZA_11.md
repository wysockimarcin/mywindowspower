# PROMPT — FAZA 11: Aplikacje i winget

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 11 — Aplikacje i winget**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_11_APLIKACJE.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 10 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 10 i ustaw status FAZY 11 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: porządek w zainstalowanych programach. W szczególności:
- moduł `MWP.Apps`: lista z rejestru (Uninstall, 64/32 bit) i pakietów Appx, filtry i sortowanie,
- `winget`: wykrycie, lista, aktualizacje, aktualizacja pojedyncza, wyszukiwanie i instalacja; parsowanie odporne na język i szerokość kolumn,
- odinstalowanie tylko z potwierdzeniem; lista ochronna pakietów systemowych,
- wpisy w logu o odinstalowanych aplikacjach,
- widok `Apps.xaml`, testy Pester z mockami `winget`.
Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 11: <krótki opis>` i napisz: „Następna faza: FAZA 12 — Prywatność i tweaki. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_12.md`. Otwórz nową rozmowę w Claude Code."
