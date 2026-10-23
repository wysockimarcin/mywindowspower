# PROMPT — FAZA 21: Dokumentacja i wydanie

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 21 — Dokumentacja i wydanie**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_21_WYDANIE.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 20 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 20 i ustaw status FAZY 21 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: zamknięcie projektu. W szczególności:
- pełny `README.md` (wymagania, uruchamianie, `ExecutionPolicy` dla jednej sesji, `Unblock-File`, uruchamianie jako administrator),
- `docs/06_UZYTKOWNIK/INSTRUKCJA.md` po polsku, obszar po obszarze, z opisem cofania zmian,
- opcjonalny skrypt tworzący skrót `.lnk`,
- finalny przegląd `DECYZJE.md` i `ARCHITEKTURA.md` pod kątem zgodności z kodem, rozliczenie otwartych pytań i długu technicznego,
- tag git `v1.0.0` (po commicie wydania).
Nie dodawaj nowych funkcji.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 21: <krótki opis>`, utwórz tag `v1.0.0` i napisz: „Projekt zakończony. Brak kolejnej fazy. Ewentualne dalsze prace: nowa lista faz w `docs/01_PLAN/PLAN_FAZ.md`."
