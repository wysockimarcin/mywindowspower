# PROMPT — FAZA 4: Szkielet GUI i host modułów

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 4 — Szkielet GUI i host modułów**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_4_GUI_SZKIELET.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`. Następnie obejrzyj mockup `docs/design/mockup-pulpit.png` (wzorzec wyglądu głównego okna).
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 3 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 3 i ustaw status FAZY 4 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: okno WPF będące hostem modułów: nawigacja, motywy, bezpieczne wykonywanie operacji w tle i zarządzanie instancjami modułów dla komputera lokalnego i zdalnych, bez funkcji obszarów. W szczególności:
- `MainWindow.xaml` (nawigacja, kontener widoku, pasek stanu, panel logu) i `UI.ps1`,
- motywy jasny i ciemny (domyślnie zgodnie z systemem, przełącznik zapamiętywany w konfiguracji),
- pomocnik zadań w tle (runspace, postęp, anulowanie, bezpieczne aktualizowanie UI),
- host: wykrywanie modułów, lista instancji, wiele instancji tego samego modułu dla różnych komputerów, zamknięcie jednej bez wpływu na inne,
- wybór komputera docelowego dla instancji, stan połączenia w pasku stanu i w widoku instancji,
- tryby Embedded i Separate window,
- widoki `Ustawienia` (w tym komputery docelowe) i `O programie`,
- widok „Moduły" (D-031): lista wbudowanych i zainstalowanych, instalacja z pliku `.mwpmod` z oknem potwierdzenia (nazwa, wersja, `RequiredPermissions`, SHA-256), odinstalowanie z potwierdzeniem zawierającym nazwę modułu; logika w `MWP.Core` z FAZY 3, nie w kodzie widoku,
- widoki-zaślepki dla wszystkich obszarów, wspólne style, okno potwierdzenia z podglądem zmian,
- zgodność z PS 5.1 i 7.x.
Jeśli środowisko nie jest Windows, napisz kod i testy statyczne, a punkty wymagające uruchomienia zapisz jako „DO WERYFIKACJI NA WINDOWS". Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 4: <krótki opis>` i napisz: „Następna faza: FAZA 5 — Dashboard. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_5.md`. Otwórz nową rozmowę w Claude Code."
