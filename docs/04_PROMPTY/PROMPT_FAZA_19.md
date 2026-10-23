# PROMPT — FAZA 19: Samodzielne uruchamianie i CLI

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 19 — Samodzielne uruchamianie i CLI**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_19_STANDALONE_CLI.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 18 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 18 i ustaw status FAZY 19 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: samodzielne uruchamianie modułów bez głównego okna i tryb CLI, z tą samą logiką co w GUI. W szczególności:
- `Invoke-MwpModule` z aliasem `apprun` (składnia przykładowa: `apprun "Services" -ComputerName "<nazwa>"`, do zatwierdzenia z użytkownikiem),
- wyszukanie i weryfikacja modułu (manifest, wersja, zależności), budowa kontekstu wykonania, uruchomienie okna (Standalone) lub trybu CLI,
- zachowanie walidacji, autoryzacji i logowania; czytelne błędy; moduł nie ładuje całego hosta,
- deklaracja `SupportedPresentationModes` w manifestach modułów, które to obsługują,
- testy Pester (moduł bez hosta, brak modułu, brak zależności).
Nie twórz osobnej logiki biznesowej na potrzeby trybu samodzielnego. Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 19: <krótki opis>` i napisz: „Następna faza: FAZA 20 — Testy i hardening. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_20.md`. Otwórz nową rozmowę w Claude Code."
