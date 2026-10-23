# FAZA 20 — Testy i hardening

**Status:** DO ZROBIENIA

## Cel
Jakość całości przed wydaniem: przegląd, testy, zgodność 5.1/7, bezpieczeństwo.

## Zależności
FAZY 5–19 zakończone (lub świadomie pominięte w `DECYZJE.md`).

## Zakres
- Przegląd całego kodu: spójność nazw, obsługa błędów, komunikaty po polsku, usunięcie martwego kodu.
- **Przegląd bezpieczeństwa:** każda funkcja zmieniająca system ma `-WhatIf`, wpis w logu i (gdzie możliwe) cofanie; listy ochronne są kompletne i przetestowane; żadne dane nie wychodzą poza komputer; brak sekretów w repozytorium.
- PSScriptAnalyzer bez uwag (lub z udokumentowanymi wyjątkami), w tym reguły zgodności z 5.1.
- Pester: uzupełnienie braków, raport pokrycia, testy regresji dla poprawionych błędów.
- Macierz zgodności: PS 5.1 i 7.x × scenariusze główne × komputer (`localhost` i zdalny).
- **Testy architektoniczne** (12 scenariuszy z `ARCHITEKTURA.md`, sekcja „Testy architektoniczne"): uruchomienie modułu samodzielnie i w hoście, dwie instancje tego samego modułu dla dwóch komputerów, brak współdzielonego stanu, widgety różnych modułów i różnych komputerów, utrata połączenia z jednym komputerem bez zatrzymywania reszty, anulowanie długiej operacji, zamknięcie jednej instancji bez wpływu na inne, odtworzenie konfiguracji Dashboardu, niezgodna wersja lub brakująca zależność, weryfikacja uprawnień przed operacją. Brakujące testy uzupełnij.
- Przegląd zdalnego zarządzania: poświadczenia (brak sekretów w repozytorium, logach i plikach konfiguracyjnych), potwierdzenia z nazwą komputera, zachowanie przy utracie łączności, ograniczenia zapisane w `DECYZJE.md` rozliczone.
- Ręczna checklista testów GUI na Windows 11 (plik `docs/05_PROCES/CHECKLISTA_TESTOW_RECZNYCH.md`): start, motywy, każdy widok, operacje w tle, anulowanie, uprawnienia, instancje i osobne okna, Dashboard z wieloma komputerami, scenariusze komputera zdalnego (w tym wyłączony komputer i złe poświadczenia).
- Wydajność GUI i czas startu; obsługa błędów braku uprawnień.
- Rozliczenie długu technicznego z `STAN_PROJEKTU.md`: naprawić lub świadomie odroczyć z wpisem.

## Poza zakresem
Nowe funkcje.

## Checklista
- [ ] Przegląd kodu i porządki
- [ ] Przegląd bezpieczeństwa (lista funkcji zmieniających system i ich zabezpieczeń)
- [ ] PSScriptAnalyzer czysty
- [ ] Pester kompletny, raport pokrycia
- [ ] Macierz zgodności 5.1 / 7.x i `localhost` / komputer zdalny
- [ ] Testy architektoniczne (12 scenariuszy) zaliczone
- [ ] Przegląd bezpieczeństwa zdalnego zarządzania
- [ ] `CHECKLISTA_TESTOW_RECZNYCH.md` utworzona i przejść
- [ ] Dług techniczny rozliczony
- [ ] Dokumentacja zaktualizowana, commit `FAZA 20: ...`

## Kryteria ukończenia
Brak znanych błędów krytycznych; lista usterek pusta lub świadomie odroczona z wpisem.

## Do weryfikacji na Windows 11
Cała checklista testów ręcznych.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 21 — Dokumentacja i wydanie. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_21.md`.
