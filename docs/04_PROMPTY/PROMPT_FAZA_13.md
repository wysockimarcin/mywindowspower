# PROMPT — FAZA 13: Defender i firewall

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 13 — Defender i firewall**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_13_DEFENDER_FIREWALL.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 12 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 12 i ustaw status FAZY 13 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: przegląd stanu ochrony i bezpieczne akcje dla Defendera i zapory. W szczególności:
- moduł `MWP.Security`, Defender: stan, sygnatury, aktualizacja, szybki i pełny skan z postępem, historia zagrożeń, wyłączenia (podgląd, dodaj/usuń z potwierdzeniem),
- zapora: profile, lista i filtrowanie reguł, włącz/wyłącz regułę, eksport reguł,
- GUI nie wyłącza ochrony w czasie rzeczywistym ani profilu zapory bez wyraźnego, podwójnego ostrzeżenia (domyślnie nie oferuje tych operacji; zapisz decyzję w `DECYZJE.md`),
- obsługa sytuacji, gdy Defender jest zastąpiony innym AV,
- widok `Security.xaml`, testy Pester z mockami.
Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 13: <krótki opis>` i napisz: „Następna faza: FAZA 14 — Testy i hardening. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_14.md`. Otwórz nową rozmowę w Claude Code."
