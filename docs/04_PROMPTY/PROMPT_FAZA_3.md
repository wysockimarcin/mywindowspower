# PROMPT — FAZA 3: Komputery docelowe i połączenia zdalne

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 3 — Komputery docelowe i połączenia zdalne**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_3_KOMPUTERY_ZDALNE.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 2 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. **Baza testów (przed jakąkolwiek zmianą).** W NOWYM terminalu zapisz `(Get-Command pwsh).Source` i `$PSVersionTable.PSVersion` dla `powershell.exe` (5.1) i `pwsh` (7.x). Uruchom `.\tests\Invoke-Checks.ps1` w obu wersjach. Oczekiwany stan wyjściowy po FAZIE 2: brak uwag analizatora, 393/393 testów. Jeśli coś nie przechodzi, zatrzymaj się i zgłoś.
4. Uzupełnij hash commita FAZY 2 w `CHANGELOG_FAZ.md` oraz w `STAN_PROJEKTU.md` (pole „Ostatni commit" i tabela „Postęp faz") i ustaw status FAZY 3 na `W TOKU` w `STAN_PROJEKTU.md`.
5. Przy projektowaniu kontekstu wykonania uwzględnij dług techniczny z FAZY 2 w `STAN_PROJEKTU.md` (przejściowe `-ComputerName` w rdzeniu → `-Context`, pula runspace'ów D-023, `EntryPoint` a fabryka instancji D-024).

## Zadanie
Cel: aplikacja zarządza komputerem lokalnym (`localhost`) i komputerami zdalnymi (D-019). Dostarcz model komputera docelowego, kontekst wykonania, warstwę połączeń i model instancji modułu. Najpierw zadaj użytkownikowi pytania o komputer zdalny (system, WinRM, domena lub grupa robocza, konto) i zapisz odpowiedzi w `DECYZJE.md`. W szczególności:
- nowy moduł `MWP.Remote` (dopisz do `tests/Modules.Tests.ps1`),
- rejestr komputerów w `config/settings.local.json` (poza repozytorium; nazwy prawdziwych komputerów nie trafiają do repo), `localhost` zawsze obecny, sekcja `targets` w szablonie z nazwą zastępczą, migracja `schemaVersion`,
- `New-MwpExecutionContext` (niezmienny kontekst: komputer, tryb Local/Remote, tożsamość, stan połączenia, parametry modułu, polityka limitów czasu i błędów),
- `New-MwpModuleInstance` (definicja ≠ instancja, własny kontekst i stan, cykl życia, brak współdzielenia stanu),
- `Connect-`/`Disconnect-`/`Test-MwpTarget` i `Invoke-MwpOnTarget` (lokalnie bezpośrednio, zdalnie przez sesję),
- ADR: transport (propozycja: WinRM dla operacji, CIM dla odczytu) i uwierzytelnianie (bez sekretów w tekście, repozytorium i logach),
- izolacja błędów: awaria jednego komputera nie wpływa na inne instancje; limit równoległości, anulowanie, sprzątanie sesji,
- zdalne zmiany respektują `-WhatIf`, log z nazwą komputera, cofanie i potwierdzenia z nazwą komputera,
- testy Pester z mockami.
Nie twórz GUI ani logiki obszarów. Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 3: <krótki opis>` i napisz: „Następna faza: FAZA 4 — Szkielet GUI i host modułów. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_4.md`. Otwórz nową rozmowę w Claude Code."
