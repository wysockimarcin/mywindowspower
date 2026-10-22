# FAZA 9 — Windows Update

**Status:** DO ZROBIENIA

## Cel
Kontrola nad aktualizacjami Windows bez zewnętrznych modułów.

## Zależności
FAZY 2 i 3 zakończone.

## Zakres
- Moduł `MWP.Update` oparty o wbudowane API COM (`Microsoft.Update.Session`): wyszukiwanie oczekujących aktualizacji, historia aktualizacji, informacja o wymaganym restarcie.
- Stan usług `wuauserv`, `bits`, `cryptsvc`, `usosvc`.
- Pauza aktualizacji (ustawienia rejestru/polityki) z cofaniem; sprawdź, które klucze są obsługiwane w Windows 11 przed użyciem.
- Reset komponentów Windows Update (zatrzymanie usług, zmiana nazw `SoftwareDistribution` i `catroot2`, restart usług) — wyłącznie z potwierdzeniem i podglądem kroków.
- Instalacja aktualizacji: tylko jeśli da się to zrobić bezpiecznie przez COM, z potwierdzeniem; w przeciwnym razie odeślij do Ustawień Windows i zapisz w `DECYZJE.md`.
- Widok `Update.xaml`, operacje w tle z postępem.
- Testy Pester z mockami COM.

## Poza zakresem
Ukrywanie sterowników, zarządzanie WSUS, moduł `PSWindowsUpdate` (zewnętrzna zależność).

## Checklista
- [ ] Wyszukiwanie oczekujących aktualizacji (COM)
- [ ] Historia aktualizacji
- [ ] Stan usług Windows Update
- [ ] Pauza aktualizacji z cofaniem
- [ ] Reset komponentów z podglądem kroków
- [ ] Decyzja o instalacji aktualizacji zapisana w `DECYZJE.md`
- [ ] Widok `Update.xaml`
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 9: ...`

## Kryteria ukończenia
Wszystko działa bez dodatkowych modułów; reset jest odwracalny (zachowane stare foldery).

## Do weryfikacji na Windows 11
Wyszukiwanie przez COM, pauza, reset komponentów (administrator).

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 10 — Sieć. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_10.md`.
