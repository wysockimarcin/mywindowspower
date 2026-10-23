# FAZA 6 — Zasilanie

**Status:** DO ZROBIENIA

## Cel
Zarządzanie planami zasilania i ustawieniami energii (obszar zgodny z nazwą projektu).

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Power` oparty o `powercfg`: lista planów, aktywny plan, przełączanie, duplikowanie, zmiana nazwy, usuwanie (z ochroną planu aktywnego).
- Dodanie planu „Najwyższa wydajność" (Ultimate Performance) przez `powercfg -duplicatescheme`; **zweryfikuj GUID schematu** w dokumentacji Microsoft przed użyciem.
- Ustawienia: wygaszanie ekranu, uśpienie, hibernacja (`powercfg /h`), szybkie uruchamianie (`HiberbootEnabled`), akcje przycisków zasilania i pokrywy (AC/DC).
- Raporty: `powercfg /batteryreport` i `powercfg /energy` (wymagają administratora), zapis do wskazanego folderu i otwarcie raportu.
- Widok `Power.xaml`; zmiany z podglądem, logiem i cofaniem (zapis poprzedniego planu/wartości).
- Testy Pester z mockami `powercfg`.
- Parsowanie wyniku `powercfg` niezależne od języka systemu (GUID zamiast nazw).
- Obsługa komputera docelowego (D-019): funkcje przyjmują kontekst wykonania, `powercfg` wywoływany przez `Invoke-MwpOnTarget`. Raporty (`batteryreport`, `energy`) powstają na komputerze docelowym; sposób ich pobrania i otwarcia lokalnie do ustalenia w tej fazie.

## Poza zakresem
Zaawansowane ustawienia procesora i GPU.

## Checklista
- [ ] Lista, aktywny plan, przełączanie
- [ ] Ultimate Performance (GUID zweryfikowany)
- [ ] Hibernacja, szybkie uruchamianie
- [ ] Czasy wygaszania i uśpienia (AC/DC)
- [ ] Raport baterii i `energy`
- [ ] Widok `Power.xaml`
- [ ] `-WhatIf`, log, cofanie
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Dokumentacja zaktualizowana, commit `FAZA 6: ...`

## Kryteria ukończenia
Każda zmiana ma podgląd i można ją cofnąć; działa przy polskim i angielskim języku systemu.

## Do weryfikacji na Windows 11
Wszystkie wywołania `powercfg`, w tym raporty i zachowanie na laptopie i na stacjonarnym. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 7 — Usługi Windows. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_7.md`.
