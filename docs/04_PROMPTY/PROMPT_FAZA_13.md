# PROMPT — FAZA 13: Prywatność i tweaki

> Wklej całość poniżej linii do NOWEJ rozmowy w Claude Code uruchomionej w głównym folderze repozytorium `mywindowspower`.

---

Pracujesz nad projektem **mywindowspower**. Odpowiadaj wyłącznie po polsku. To jest **FAZA 13 — Prywatność i tweaki**. Nie pamiętasz poprzednich rozmów; ciągłość niesie dokumentacja w repozytorium.

## Start
1. Przeczytaj w kolejności: `CLAUDE.md`, `docs/02_STAN/STAN_PROJEKTU.md`, `docs/00_PROJEKT/CONTEXT.md`, `docs/00_PROJEKT/ARCHITEKTURA.md`, `docs/00_PROJEKT/DECYZJE.md`, `docs/03_FAZY/FAZA_13_PRYWATNOSC_TWEAKI.md`, `docs/05_PROCES/PROCEDURA_FAZY.md`.
2. Wykonaj `git status` i `git log --oneline -10`. Potwierdź, że FAZA 12 jest ZAKOŃCZONA (status, commit, wpis w `CHANGELOG_FAZ.md`). Jeśli nie, zatrzymaj się i zgłoś.
3. Uzupełnij w `CHANGELOG_FAZ.md` hash commita FAZY 12 i ustaw status FAZY 13 na `W TOKU` w `STAN_PROJEKTU.md`.

## Zadanie
Cel: katalog ustawień systemu zdefiniowany danymi, z odczytem stanu, zastosowaniem i cofnięciem. W szczególności:
- moduł `MWP.Tweaks`: format katalogu tweaków (klucz rejestru, wartości, ryzyko, uzasadnienie, wymóg administratora/restartu) i walidacja schematu,
- odczyt stanu, zastosuj/cofnij z zapisem poprzedniej wartości (także informacji, że klucza nie było),
- profile z podglądem różnic, punkt przywracania i eksport kluczy (`reg export`) przed grupą zmian,
- początkowy katalog wyłącznie bezpiecznych, udokumentowanych tweaków (bez osłabiania zabezpieczeń systemu),
- widok `Tweaks.xaml`, testy Pester na testowych kluczach rejestru (nie na realnych gałęziach),
- obsługa komputera docelowego (D-019): zdalnie `HKLM`; tweaki `HKCU` tylko po jawnym wyborze profilu albo odroczone z wpisem.
Nie wykonuj pracy z innych faz.

## Zamknięcie
Zgodnie z `docs/05_PROCES/PROCEDURA_FAZY.md` (sekcja C): zweryfikuj checklistę, zaktualizuj dokumentację, wykonaj commit `FAZA 13: <krótki opis>` i napisz: „Następna faza: FAZA 14 — Defender i firewall. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_14.md`. Otwórz nową rozmowę w Claude Code."
