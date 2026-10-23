# FAZA 12 — Aplikacje i winget

**Status:** DO ZROBIENIA

## Cel
Porządek w zainstalowanych programach: lista, aktualizacje, odinstalowanie.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Apps`: lista programów z rejestru (`Uninstall`, 64/32 bit, użytkownik/maszyna) oraz pakietów Appx (`Get-AppxPackage`), z filtrami i sortowaniem.
- `winget`: wykrycie obecności, lista (`winget list`), aktualizacje (`winget upgrade`), aktualizacja pojedynczej aplikacji, odinstalowanie; parsowanie wyjścia odporne na język i szerokość kolumn (np. przełączniki wyjścia, a gdy ich brak — parsowanie po nagłówkach).
- Odinstalowanie: wyłącznie z potwierdzeniem i podglądem; **lista ochronna** pakietów systemowych (nie do usunięcia z GUI).
- Wyszukiwanie pakietów w repozytorium winget i instalacja wybranego (z potwierdzeniem).
- Zapis informacji o odinstalowanej aplikacji w logu (nazwa, wersja, wydawca); cofnięcie = ponowna instalacja przez winget, jeśli pakiet jest w repozytorium.
- Widok `Apps.xaml`, operacje w tle z postępem.
- Testy Pester z mockami `winget`.
- Obsługa komputera docelowego (D-019): lista z rejestru (HKLM; HKCU tylko dla wskazanego profilu) działa zdalnie. **Do zbadania:** `winget` i pakiety Appx w kontekście sesji zdalnej bez zalogowanego użytkownika bywają niedostępne; zakres zdalny ustal po sprawdzeniu i zapisz w `DECYZJE.md`.

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
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Dokumentacja zaktualizowana, commit `FAZA 12: ...`

## Kryteria ukończenia
Pakietów systemowych nie da się usunąć z GUI; parsowanie `winget` działa przy polskim systemie.

## Do weryfikacji na Windows 11
`winget` na realnym systemie, odinstalowanie aplikacji testowej. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 13 — Prywatność i tweaki. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_13.md`.
