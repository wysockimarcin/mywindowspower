# PROMPT — FAZA 1: Szkielet techniczny

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 1 — Szkielet techniczny**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_1_SZKIELET.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 0 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 0 i ustaw status FAZY 1 na `W TOKU` w `STAN_PROJEKTU.md`.
4. Zapytaj użytkownika o wersję PowerShella i build Windows 11 na komputerze docelowym (`$PSVersionTable`, `winver`), jeśli nie ma ich w dokumentacji.

## Zadanie
Cel: działający, pusty projekt, który da się uruchomić, przeanalizować i przetestować. W szczególności:
- launcher `Start-MyWindowsPower.ps1` (wersja PS 5.1/7.x, STA, import modułów, komunikaty po polsku),
- szkielety modułów `src/Modules/MWP.*` z manifestami `.psd1`,
- konfiguracja Pester 5 i PSScriptAnalyzer (z regułami zgodności z 5.1), skrypt `tests/Invoke-Checks.ps1`,
- `config/settings.example.json`, pliki UTF-8 z BOM,
- sprawdzenie układu katalogów z `ARCHITEKTURA.md` (korekta + wpis w `DECYZJE.md`).
Nie twórz GUI ani logiki obszarów. Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 1: <krótki opis>` i napisz: „Następna faza: FAZA 2 — Rdzeń i bezpieczeństwo zmian. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_2.md`. Otwórz nową rozmowę w Claude Code."
