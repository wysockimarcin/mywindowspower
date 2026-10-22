# FAZA 15 — Dokumentacja i wydanie

**Status:** DO ZROBIENIA

## Cel
Zamknięcie projektu: kompletna dokumentacja użytkowa i oznaczone wydanie.

## Zależności
FAZA 14 zakończona.

## Zakres
- `README.md` pełny: opis, wymagania (Windows 11, PS 5.1 lub 7.x), uruchamianie, ekrany/obszary, bezpieczeństwo zmian.
- Uruchamianie skryptu: `ExecutionPolicy` (np. `powershell -ExecutionPolicy Bypass -File .\Start-MyWindowsPower.ps1` dla jednej sesji), `Unblock-File` dla pobranych plików, uruchamianie jako administrator.
- Instrukcja użytkownika `docs/06_UZYTKOWNIK/INSTRUKCJA.md` (po polsku, obszar po obszarze, z opisem cofania zmian).
- Opcjonalny skrypt tworzący skrót `.lnk` na pulpicie.
- Finalny `CHANGELOG` projektu i podsumowanie w `STAN_PROJEKTU.md`.
- Finalny przegląd `DECYZJE.md`, `ARCHITEKTURA.md` (zgodność z rzeczywistością).
- Tag git `v1.0.0` (commit wydania).
- Zamknięcie otwartych pytań i długu technicznego (lub przeniesienie do pliku „Pomysły na przyszłość").

## Poza zakresem
Nowe funkcje, `.exe`.

## Checklista
- [ ] `README.md` pełny
- [ ] Instrukcja uruchamiania (ExecutionPolicy, Unblock-File, administrator)
- [ ] `docs/06_UZYTKOWNIK/INSTRUKCJA.md`
- [ ] Skrypt skrótu (opcjonalnie)
- [ ] Finalny `CHANGELOG`, `STAN_PROJEKTU.md`
- [ ] Zgodność `ARCHITEKTURA.md` z kodem
- [ ] Tag `v1.0.0`
- [ ] Commit `FAZA 15: ...`

## Kryteria ukończenia
Osoba bez wiedzy o projekcie uruchomi go na czystym Windows 11 wyłącznie według README.

## Do weryfikacji na Windows 11
Uruchomienie według README od zera.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
Brak — projekt zakończony. Ewentualne dalsze prace: nowa lista faz w `PLAN_FAZ.md`.
