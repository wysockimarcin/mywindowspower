# FAZA 18 — RDP, sesje i zrzuty ekranu

**Status:** DO ZROBIENIA

## Cel
Zarządzanie sesjami i RDP oraz zrzuty ekranu komputera docelowego (moduły z koncepcji pierwotnej, D-020).

## Zależności
FAZY 2, 3 i 4 zakończone (widget statusu RDP wymaga też FAZY 5).

## Zakres
- Moduł `MWP.Rdp`: lista sesji na komputerze docelowym (użytkownik, identyfikator, stan, czas), stan usługi pulpitu zdalnego (włączony/wyłączony, NLA, port), rozłączenie i wylogowanie sesji (**Destrukcyjna**: potwierdzenie z nazwą użytkownika i komputera), uruchomienie klienta RDP (`mstsc`) do komputera docelowego.
- Shadowing (obserwacja/sterowanie sesją, `mstsc /shadow`): tylko scenariusze obsługiwane przez system i politykę; **zbadaj i zapisz w `DECYZJE.md`**, które scenariusze są możliwe na komputerach użytkownika (wymaga polityki grupy i zgody użytkownika sesji).
- Moduł `MWP.Screenshot`: zrzut ekranu komputera docelowego. **Ograniczenie do zbadania:** zdalne polecenia działają w sesji nieinteraktywnej, bez dostępu do pulpitu użytkownika; wykonanie zrzutu w sesji użytkownika wymaga osobnego mechanizmu (np. zadanie uruchomione w tej sesji). Jeśli nie da się tego zrobić bez dodatkowego agenta lub osłabienia zabezpieczeń, zapisz decyzję i odrocz (zgodnie z zasadą nieosłabiania zabezpieczeń Windows).
- Widget „Status połączenia RDP z innym komputerem" dla Dashboardu.
- Widoki `Rdp.xaml` i `Screenshot.xaml`; testy Pester z mockami.

## Poza zakresem
Własny serwer lub agent zdalny, nagrywanie sesji, przesyłanie obrazu poza komputery użytkownika (dane zostają lokalnie).

## Checklista
- [ ] `Get-MwpRdpSession`, stan RDP, rozłączenie i wylogowanie z potwierdzeniem
- [ ] Uruchomienie `mstsc` dla komputera docelowego
- [ ] Shadowing zbadany; decyzja w `DECYZJE.md`
- [ ] Zrzut ekranu zdalnego komputera: zbadany i zaimplementowany albo świadomie odroczony z wpisem
- [ ] Moduły dopisane do listy w `tests/Modules.Tests.ps1`
- [ ] Widoki i widget statusu RDP
- [ ] Działa dla `localhost` i dla komputera zdalnego (kontekst wykonania `-Context`, błąd połączenia obsłużony na poziomie instancji)
- [ ] Testy Pester, PSScriptAnalyzer
- [ ] Dokumentacja zaktualizowana, commit `FAZA 18: ...`

## Kryteria ukończenia
Użytkownik widzi sesje na komputerze lokalnym i zdalnym i może bezpiecznie rozłączyć wskazaną; ograniczenia shadowingu i zrzutów są jawnie opisane.

## Do weryfikacji na Windows 11
Cała faza: sesje, `mstsc`, shadowing i zrzut ekranu na komputerze zdalnym użytkownika.

## Wyniki
(wypełnia Claude po zakończeniu fazy)

## Następna faza
FAZA 19 — Samodzielne uruchamianie i CLI. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_19.md`.
