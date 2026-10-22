# FAZA 6 — Usługi Windows

**Status:** DO ZROBIENIA

## Cel
Bezpieczny przegląd i zmiana usług Windows.

## Zależności
FAZY 2 i 3 zakończone.

## Zakres
- Moduł `MWP.Services`: lista usług (`Get-Service` + `Win32_Service` dla typu uruchomienia, konta, ścieżki, opisu), filtry (stan, typ, wyszukiwanie), start/stop/restart.
- Zmiana typu uruchomienia: Automatic, Automatic (Delayed Start), Manual, Disabled; rozróżnienie opóźnionego startu (np. `sc.exe config ... start= delayed-auto`).
- **Lista ochronna** usług krytycznych (w osobnym pliku danych): GUI nie pozwala ich wyłączyć ani zatrzymać; lista możliwa do przeglądu.
- Wykrywanie zależności przed zatrzymaniem (usługi zależne) i ostrzeżenie.
- Zapis stanu przed zmianą i cofanie (rejestr cofnięć z FAZY 2).
- Eksport i import profilu usług (JSON) z podglądem różnic.
- Widok `Services.xaml`; operacje w tle.
- Testy Pester z mockami.

## Poza zakresem
Edycja ścieżek binarnych usług, usuwanie usług.

## Checklista
- [ ] Lista i filtry
- [ ] Start/stop/restart z obsługą zależności
- [ ] Zmiana typu uruchomienia (w tym opóźniony start)
- [ ] Lista ochronna usług krytycznych
- [ ] Cofanie zmian
- [ ] Eksport/import profilu z podglądem różnic
- [ ] Widok `Services.xaml`
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 6: ...`

## Kryteria ukończenia
Usług z listy ochronnej nie da się wyłączyć z GUI; każda zmiana jest w logu i odwracalna.

## Do weryfikacji na Windows 11
Zmiana typu uruchomienia i stanu na usłudze testowej (nie krytycznej), z uprawnieniami administratora.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 7 — Autostart i harmonogram. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_7.md`.
