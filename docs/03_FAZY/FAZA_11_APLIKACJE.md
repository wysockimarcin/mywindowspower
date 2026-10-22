# FAZA 11 — Aplikacje i winget

**Status:** DO ZROBIENIA

## Cel
Porządek w zainstalowanych programach: lista, aktualizacje, odinstalowanie.

## Zależności
FAZY 2 i 3 zakończone.

## Zakres
- Moduł `MWP.Apps`: lista programów z rejestru (`Uninstall`, 64/32 bit, użytkownik/maszyna) oraz pakietów Appx (`Get-AppxPackage`), z filtrami i sortowaniem.
- `winget`: wykrycie obecności, lista (`winget list`), aktualizacje (`winget upgrade`), aktualizacja pojedynczej aplikacji, odinstalowanie; parsowanie wyjścia odporne na język i szerokość kolumn (np. przełączniki wyjścia, a gdy ich brak — parsowanie po nagłówkach).
- Odinstalowanie: wyłącznie z potwierdzeniem i podglądem; **lista ochronna** pakietów systemowych (nie do usunięcia z GUI).
- Wyszukiwanie pakietów w repozytorium winget i instalacja wybranego (z potwierdzeniem).
- Zapis informacji o odinstalowanej aplikacji w logu (nazwa, wersja, wydawca); cofnięcie = ponowna instalacja przez winget, jeśli pakiet jest w repozytorium.
- Widok `Apps.xaml`, operacje w tle z postępem.
- Testy Pester z mockami `winget`.

## Poza zakresem
Instalacja z plików `.msi`/`.exe` spoza winget, czyszczenie resztek po odinstalowaniu.

## Checklista
- [ ] Lista programów (rejestr + Appx)
- [ ] Wykrycie i obsługa `winget`
- [ ] Lista aktualizacji i aktualizacja pojedyncza
- [ ] Odinstalowanie z potwierdzeniem i listą ochronną
- [ ] Wyszukiwanie i instalacja pakietu
- [ ] Widok `Apps.xaml`
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 11: ...`

## Kryteria ukończenia
Pakietów systemowych nie da się usunąć z GUI; parsowanie `winget` działa przy polskim systemie.

## Do weryfikacji na Windows 11
`winget` na realnym systemie, odinstalowanie aplikacji testowej.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 12 — Prywatność i tweaki. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_12.md`.
