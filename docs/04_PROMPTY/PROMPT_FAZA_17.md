# PROMPT — FAZA 17: Użytkownicy i grupy lokalne

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 17 — Użytkownicy i grupy lokalne**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_17_UZYTKOWNICY_GRUPY.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 16 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 16 i ustaw status FAZY 17 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: moduł `MWP.Accounts` do ostrożnego zarządzania lokalnymi użytkownikami i grupami. W szczególności:
- lista użytkowników i grup z członkostwem,
- włączanie i wyłączanie kont, dodawanie i usuwanie członków grup (podgląd, log, cofanie),
- lista ochronna: ostatni aktywny administrator, bieżące konto, konta wbudowane krytyczne,
- sprawdź dostępność `Microsoft.PowerShell.LocalAccounts` w 5.1 i 7.x (w razie potrzeby wariant przez CIM/ADSI), zdalnie przez `Invoke-MwpOnTarget`,
- widok `Accounts.xaml`, dopisanie modułu do `tests/Modules.Tests.ps1`, testy Pester z mockami.
Tworzenie i usuwanie kont oraz hasła są poza zakresem. Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 17: <krótki opis>` i napisz: „Następna faza: FAZA 18 — RDP, sesje i zrzuty ekranu. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_18.md`. Otwórz nową rozmowę w Claude Code."
