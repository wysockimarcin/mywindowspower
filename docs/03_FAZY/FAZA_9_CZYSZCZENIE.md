# FAZA 9 — Czyszczenie dysku

**Status:** DO ZROBIENIA

## Cel
Bezpieczne zwalnianie miejsca na dysku. To jedyny obszar z trwałym usuwaniem plików, więc bezpieczeństwo ma pierwszeństwo przed funkcjonalnością.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Cleanup`: definicje kategorii (dane, nie kod): pliki tymczasowe użytkownika (`%TEMP%`), `Windows\Temp`, kosz, pamięć podręczna miniatur, raporty błędów (WER), pamięć podręczna `SoftwareDistribution\Download`, Delivery Optimization, logi.
- Skanowanie tylko do odczytu: liczba plików i rozmiar na kategorię.
- **Tryb podglądu domyślny**; usuwanie dopiero po wyraźnym potwierdzeniu użytkownika w GUI, z listą kategorii i rozmiarem.
- Zasady bezpieczeństwa: tylko ścieżki z definicji kategorii, żadnego usuwania poza nimi, pomijanie plików w użyciu, brak podążania za dowiązaniami (junction/symlink), nigdy dokumenty i pulpit użytkownika.
- Raport: ile zwolniono, ile pominięto i dlaczego.
- Analiza magazynu składników: `DISM /Online /Cleanup-Image /AnalyzeComponentStore` (tylko analiza w tej fazie, czyszczenie opcjonalnie z ostrzeżeniem).
- Widok `Cleanup.xaml`, operacje w tle z postępem i anulowaniem.
- Testy Pester na katalogach tymczasowych utworzonych w teście (nigdy na realnych ścieżkach systemu).
- Obsługa komputera docelowego (D-019): dla komputera zdalnego tylko lokalizacje systemowe (np. `Windows\Temp`, pamięć podręczna Windows Update); profile użytkowników zdalnych tylko po jawnym wyborze. Zasada „nigdy nie dotyka plików użytkownika" obowiązuje bezwzględnie; potwierdzenie czyszczenia zawiera nazwę komputera.

## Poza zakresem
Czyszczenie przeglądarek, rejestru, duplikatów plików.

## Checklista
- [ ] Definicje kategorii w pliku danych
- [ ] Skan (odczyt) z rozmiarami
- [ ] Usuwanie z potwierdzeniem i podglądem
- [ ] Zabezpieczenie przed junction/symlink i ścieżkami spoza definicji
- [ ] Raport po czyszczeniu
- [ ] Analiza składników DISM
- [ ] Widok `Cleanup.xaml`, postęp i anulowanie
- [ ] Testy Pester na katalogach testowych
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Dokumentacja zaktualizowana, commit `FAZA 9: ...`

## Kryteria ukończenia
Test sprawdza, że żadna operacja nie wychodzi poza zdefiniowane ścieżki; domyślnie nic nie jest usuwane bez potwierdzenia.

## Do weryfikacji na Windows 11
Skan i czyszczenie realnych kategorii, najpierw `-WhatIf`. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 10 — Windows Update. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_10.md`.
