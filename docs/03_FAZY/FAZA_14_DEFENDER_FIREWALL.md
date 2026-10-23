# FAZA 14 — Defender i firewall

**Status:** DO ZROBIENIA

## Cel
Przegląd stanu ochrony i bezpieczne akcje związane z Microsoft Defenderem i zaporą Windows.

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Security`, część Defender: stan (`Get-MpComputerStatus`), wersje sygnatur, aktualizacja sygnatur (`Update-MpSignature`), szybki i pełny skan (`Start-MpScan`) z postępem, historia wykrytych zagrożeń (`Get-MpThreatDetection`).
- Wyłączenia Defendera: podgląd listy; dodanie i usunięcie tylko z potwierdzeniem i ostrzeżeniem o ryzyku.
- Zapora: profile (`Get-NetFirewallProfile`) i ich stan, lista reguł z filtrami (kierunek, akcja, włączona), włącz/wyłącz regułę, eksport reguł.
- **GUI nie wyłącza ochrony w czasie rzeczywistym ani profilu zapory bez wyraźnego, podwójnego ostrzeżenia**; domyślnie takie operacje nie są oferowane (decyzja zapisana w `DECYZJE.md`).
- Obsługa sytuacji, gdy Defender jest zastąpiony innym produktem antywirusowym.
- Widok `Security.xaml` (zakładki: Defender, Zapora), operacje w tle.
- Testy Pester z mockami.
- Obsługa komputera docelowego (D-019): status Defendera, sygnatury, skan i reguły zapory przez kontekst wykonania. **Ostrzeżenie:** zmiana reguły zapory na komputerze zdalnym może odciąć połączenie (np. reguła WinRM) — wymagane potwierdzenie z nazwą komputera i dodatkowe ostrzeżenie dla reguł związanych z połączeniem.

## Poza zakresem
Tworzenie nowych reguł zapory z poziomu GUI, zarządzanie innymi produktami AV.

## Checklista
- [ ] Stan Defendera i sygnatur
- [ ] Aktualizacja sygnatur i skany z postępem
- [ ] Historia zagrożeń
- [ ] Wyłączenia: podgląd, dodaj/usuń z potwierdzeniem
- [ ] Profile i reguły zapory, włącz/wyłącz regułę
- [ ] Decyzja o zakazie wyłączania ochrony zapisana w `DECYZJE.md`
- [ ] Widok `Security.xaml`
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Dokumentacja zaktualizowana, commit `FAZA 14: ...`

## Kryteria ukończenia
Ochrona nie może zostać wyłączona przypadkowo; stan odczytywany poprawnie także przy innym AV.

## Do weryfikacji na Windows 11
Odczyt stanu, aktualizacja sygnatur, szybki skan, zmiana stanu reguły testowej (administrator). Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 15 — Dyski i woluminy. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_15.md`.
