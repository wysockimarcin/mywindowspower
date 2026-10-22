# PROMPT — FAZA 0: Fundament

> FAZA 0 została już wykonana (2026-10-22). Tego promptu użyj tylko wtedy, gdy trzeba zweryfikować lub naprawić fundament projektu. Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 0 — Fundament** (weryfikacja). Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_0_FUNDAMENT.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`.

## Zadanie
Sprawdź kompletność fundamentu według checklisty z `docs/03_FAZY/FAZA_0_FUNDAMENT.md`:
- czy istnieją wszystkie pliki z `docs/` (w tym 16 plików faz i 16 promptów),
- czy nazwy plików i odnośniki w dokumentach są spójne,
- czy remote `origin` wskazuje https://github.com/wysockimarcin/mywindowspower,
- czy `CLAUDE.md` jest w głównym folderze.
Napraw rozbieżności. Nie twórz kodu aplikacji.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zaktualizuj dokumentację, jeśli coś poprawiałeś, wykonaj commit `FAZA 0: <opis poprawek>` i napisz: „Następna faza: FAZA 1 — Szkielet techniczny. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_1.md`. Otwórz nową rozmowę w Claude Code."
