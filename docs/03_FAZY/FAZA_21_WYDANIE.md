# FAZA 21 — Dokumentacja i wydanie

**Status:** DO ZROBIENIA

## Cel
Zamknięcie projektu: kompletna dokumentacja użytkowa i oznaczone wydanie.

## Zależności
FAZA 20 zakończona.

## Zakres
- `README.md` pełny: opis, wymagania (Windows 11, PS 5.1 lub 7.x), uruchamianie, ekrany/obszary, bezpieczeństwo zmian.
- Sekcja o komputerach zdalnych: wymagania po stronie zdalnego komputera (np. WinRM), dodawanie komputera w `Ustawieniach`, uwierzytelnianie, ograniczenia znane z `DECYZJE.md`; użycie `apprun` (FAZA 19).
- Uruchamianie skryptu: `ExecutionPolicy` (np. `powershell -ExecutionPolicy Bypass -File .\Start-MyWindowsPower.ps1` dla jednej sesji), `Unblock-File` dla pobranych plików, uruchamianie jako administrator.
- Instrukcja użytkownika `docs/06_UZYTKOWNIK/INSTRUKCJA.md` (po polsku, obszar po obszarze, z opisem cofania zmian).
- Opcjonalny skrypt tworzący skrót `.lnk` na pulpicie. Skrót uruchamia aplikację z ukrytą konsolą (`-WindowStyle Hidden`), bo w wydaniu konsola PowerShella nie jest potrzebna; błędy startu widać wtedy w oknie komunikatu, a dane startowe w dzienniku operacji (korekta D-042 po FAZIE 4). Launcher nie ukrywa konsoli sam (bez P/Invoke).
- Finalny `CHANGELOG` projektu i podsumowanie w `STAN_PROJEKTU.md`.
- Finalny przegląd `DECYZJE.md`, `ARCHITEKTURA.md` (zgodność z rzeczywistością).
- Tag git `v1.0.0` (commit wydania).
- Zamknięcie otwartych pytań i długu technicznego (lub przeniesienie do pliku „Pomysły na przyszłość").

## Poza zakresem
Nowe funkcje, `.exe`.

## Checklista
- [ ] `README.md` pełny
- [ ] Instrukcja uruchamiania (ExecutionPolicy, Unblock-File, administrator)
- [ ] Sekcja o komputerach zdalnych w README i instrukcji
- [ ] `docs/06_UZYTKOWNIK/INSTRUKCJA.md`
- [ ] Skrypt skrótu (opcjonalnie): z `-WindowStyle Hidden`; sprawdzić, że błąd importu modułu jest widoczny w oknie komunikatu, a wpisy `Startup.*` w dzienniku operacji (D-042)
- [ ] Finalny `CHANGELOG`, `STAN_PROJEKTU.md`
- [ ] Zgodność `ARCHITEKTURA.md` z kodem
- [ ] Tag `v1.0.0`
- [ ] Commit `FAZA 21: ...`

## Kryteria ukończenia
Osoba bez wiedzy o projekcie uruchomi go na czystym Windows 11 wyłącznie według README.

## Do weryfikacji na Windows 11
Uruchomienie według README od zera.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
Brak — projekt zakończony. Ewentualne dalsze prace: nowa lista faz w `PLAN_FAZ.md`.
