# PROMPT — FAZA 4: Dashboard

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 4 — Dashboard**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_4_DASHBOARD.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 3 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 3 i ustaw status FAZY 4 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: pierwszy realny widok, tylko do odczytu: informacje o systemie i sprzęcie. W szczególności:
- moduł `MWP.Dashboard` z `Get-MwpSystemInfo` (system, uptime, CPU, RAM, GPU, dyski, BIOS i płyta, bateria, podstawy sieci) na CIM, odporny na braki danych,
- widok `Dashboard.xaml` z kafelkami, odświeżanie w tle,
- eksport raportu do JSON i tekstu,
- testy Pester z mockami CIM.
Nie zmieniaj niczego w systemie. Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 4: <krótki opis>` i napisz: „Następna faza: FAZA 5 — Zasilanie. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_5.md`. Otwórz nową rozmowę w Claude Code."
