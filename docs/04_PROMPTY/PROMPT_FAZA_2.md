# PROMPT — FAZA 2: Rdzeń i bezpieczeństwo zmian

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 2 — Rdzeń i bezpieczeństwo zmian**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_2_RDZEN_BEZPIECZENSTWO.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 1 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 1 i ustaw status FAZY 2 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: wspólny fundament `MWP.Core` (każda późniejsza zmiana systemowa jest podglądana, logowana i odwracalna) oraz kontrakt modułu, przygotowane na wiele komputerów (`localhost` i zdalne, D-019). W szczególności:
- logowanie (plik dzienny, rotacja) i konfiguracja,
- wykrywanie administratora, elewacja na życzenie,
- punkt przywracania systemu,
- rejestr cofnięć (zapis stanu przed zmianą, `Invoke-MwpUndo`),
- standardowy obiekt wyniku i wzorzec funkcji z `-WhatIf` (opisz w `ARCHITEKTURA.md`),
- mechanizm listy ochronnej,
- pole komputera w logu, wpisie cofnięcia i obiekcie wyniku (domyślnie `localhost`); żadnego globalnego „bieżącego komputera",
- kontrakt modułu: pola manifestu (zob. `ARCHITEKTURA.md`), odkrywanie modułów, walidacja wersji i zależności; uzupełnij manifesty istniejących modułów,
- ADR w `DECYZJE.md`: model wykonywania i współbieżności, kontrakt i cykl życia modułu, konfiguracja/logowanie/uprawnienia,
- testy Pester z mockami (bez zmian w realnym systemie).
Nie twórz GUI, logiki obszarów ani połączeń zdalnych (to FAZA 3). Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 2: <krótki opis>` i napisz: „Następna faza: FAZA 3 — Komputery docelowe i połączenia zdalne. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_3.md`. Otwórz nową rozmowę w Claude Code."
