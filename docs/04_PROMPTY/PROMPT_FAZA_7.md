# PROMPT — FAZA 7: Autostart i harmonogram

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 7 — Autostart i harmonogram**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_7_AUTOSTART_HARMONOGRAM.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 6 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 6 i ustaw status FAZY 7 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: kontrola tego, co uruchamia się z systemem. W szczególności:
- moduł `MWP.Startup`: Run/RunOnce (także WOW6432Node), foldery Startup, `StartupApproved`,
- włącz/wyłącz zgodnie z Menedżerem zadań, bez kasowania wpisów,
- zadania harmonogramu: lista, włącz/wyłącz, uruchom; usunięcie tylko z potwierdzeniem i eksportem XML,
- informacja o podpisie wydawcy (`Get-AuthenticodeSignature`), cofanie zmian,
- widok `Startup.xaml` (zakładki Autostart i Harmonogram), testy Pester z mockami.
Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 7: <krótki opis>` i napisz: „Następna faza: FAZA 8 — Czyszczenie dysku. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_8.md`. Otwórz nową rozmowę w Claude Code."
