# PROMPT — FAZA 3: Szkielet GUI

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 3 — Szkielet GUI**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_3_GUI_SZKIELET.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 2 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 2 i ustaw status FAZY 3 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: okno WPF z nawigacją, motywami i bezpiecznym wykonywaniem operacji w tle, bez funkcji obszarów. W szczególności:
- `MainWindow.xaml` (nawigacja, kontener widoku, pasek stanu, panel logu) i `UI.ps1`,
- motywy jasny i ciemny (domyślnie zgodnie z systemem, przełącznik zapamiętywany w konfiguracji),
- pomocnik zadań w tle (runspace, postęp, anulowanie, bezpieczne aktualizowanie UI),
- widoki-zaślepki dla wszystkich obszarów, wspólne style, okno potwierdzenia z podglądem zmian,
- zgodność z PS 5.1 i 7.x.
Jeśli środowisko nie jest Windows, napisz kod i testy statyczne, a punkty wymagające uruchomienia zapisz jako „DO WERYFIKACJI NA WINDOWS". Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 3: <krótki opis>` i napisz: „Następna faza: FAZA 4 — Dashboard. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_4.md`. Otwórz nową rozmowę w Claude Code."
