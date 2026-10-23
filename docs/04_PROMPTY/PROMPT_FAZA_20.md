# PROMPT — FAZA 20: Testy i hardening

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 20 — Testy i hardening**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_20_TESTY_QA.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 19 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 19 i ustaw status FAZY 20 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: jakość całości przed wydaniem. Bez nowych funkcji. W szczególności:
- przegląd kodu (spójność, obsługa błędów, komunikaty po polsku, martwy kod),
- przegląd bezpieczeństwa: lista wszystkich funkcji zmieniających system i ich zabezpieczeń (`-WhatIf`, log, cofanie, lista ochronna), brak sekretów w repozytorium,
- PSScriptAnalyzer bez uwag, Pester kompletny z raportem pokrycia, macierz zgodności PS 5.1 i 7.x,
- utworzenie `docs/05_PROCES/CHECKLISTA_TESTOW_RECZNYCH.md` dla testów GUI na Windows 11,
- testy architektoniczne (12 scenariuszy z `ARCHITEKTURA.md`), macierz zgodności z podziałem na `localhost` i komputer zdalny, przegląd bezpieczeństwa zdalnego zarządzania (poświadczenia, potwierdzenia z nazwą komputera, utrata łączności),
- rozliczenie długu technicznego z `STAN_PROJEKTU.md` (napraw lub odrocz z wpisem w `DECYZJE.md`).

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 20: <krótki opis>` i napisz: „Następna faza: FAZA 21 — Dokumentacja i wydanie. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_21.md`. Otwórz nową rozmowę w Claude Code."
