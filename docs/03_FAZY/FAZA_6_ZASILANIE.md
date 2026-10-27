# FAZA 6 — Zasilanie

**Status:** ZAKOŃCZONA (ręczna weryfikacja zmian, raportów i komputera zdalnego — lista niżej)

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
- [x] Lista, aktywny plan, przełączanie — `Get-MwpPowerStatus`, `Get-MwpPowerPlan`, `Set-MwpActivePowerPlan`; także duplikowanie (`Copy-MwpPowerPlan`), zmiana nazwy (`Rename-MwpPowerPlan`), usuwanie z ochroną planu aktywnego i planów wbudowanych (`Remove-MwpPowerPlan`), import (`Import-MwpPowerPlan`)
- [x] Ultimate Performance (GUID zweryfikowany) — `Add-MwpUltimatePowerPlan`, `e9a42b02-d5df-448d-aa00-03f14749eb61`: Microsoft Q&A + domyślne schematy Windows 11 w rejestrze i `powercfg /qh` (oficjalnej strony Microsoft Learn z tym GUID nie znaleziono — D-044)
- [x] Hibernacja, szybkie uruchamianie — `Set-MwpHibernation`, `Set-MwpFastStartup` (administrator na komputerze docelowym)
- [x] Czasy wygaszania i uśpienia (AC/DC) — `Set-MwpPowerSetting` (ekran, uśpienie, hibernacja po) oraz akcje pokrywy i przycisków zasilania/uśpienia
- [x] Raport baterii i `energy` — `New-MwpPowerReport`, `Save-MwpPowerReport`, `Open-MwpPowerReport` (raport na komputerze docelowym, zapis i otwarcie lokalnie)
- [x] Widok `Power.xaml` — `src/UI/Views/Power.xaml` (widok modułu wbudowanego w hoście, D-044) + widget Dashboardu `PowerStatus`
- [x] `-WhatIf`, log, cofanie — każda zmiana; w GUI podgląd w oknie potwierdzenia i lista „Zmiany zasilania do cofnięcia”
- [x] Testy Pester, PSScriptAnalyzer — `tests/Modules/MWP.Power/Power.Tests.ps1` (mock `powercfg.exe`, polski i angielski), `tests/UI/PowerView.Tests.ps1`; wynik niżej
- [x] Działa dla `localhost` i dla komputera zdalnego (kontekst `-Context`, błąd połączenia obsłużony na poziomie instancji) — localhost: test dymny i odczyt; zdalnie: testy z mockiem transportu WinRM; **prawdziwy komputer zdalny — DO WERYFIKACJI NA WINDOWS 11**
- [x] Dokumentacja zaktualizowana, commit `FAZA 6: ...`

## Kryteria ukończenia
Każda zmiana ma podgląd i można ją cofnąć; działa przy polskim i angielskim języku systemu.

## Do weryfikacji na Windows 11
Wszystkie wywołania `powercfg`, w tym raporty i zachowanie na laptopie i na stacjonarnym. Dodatkowo test na komputerze zdalnym użytkownika (obsługa zdalna, utrata połączenia).

## Wyniki
Zakończona 2026-10-27.

- **Baza przed zmianami** (każda wersja w nowym procesie): 5.1.26100.9711 — 0 uwag, 1094/1094; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1094/1094.
- **Wynik końcowy:** `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag PSScriptAnalyzer, 1232/1232; 7.6.7 (`C:\Program Files\PowerShell\pwsh.exe`) — 0 uwag, 1232/1232 (+138 testów).
- **`MWP.Power` 0.6.0:** odczyt (`Get-MwpPowerStatus [-AsOperation]`, `Resolve-MwpPowerStatus`, `Get-MwpPowerPlan`), zmiany (`Set-MwpActivePowerPlan`, `Copy-MwpPowerPlan`, `Add-MwpUltimatePowerPlan`, `Rename-MwpPowerPlan`, `Remove-MwpPowerPlan`, `Import-MwpPowerPlan`, `Set-MwpPowerSetting`, `Set-MwpHibernation`, `Set-MwpFastStartup`), raporty (`New-MwpPowerReport`, `Save-MwpPowerReport`, `Open-MwpPowerReport`, `Get-MwpPowerReportDirectory`), widget (`ConvertTo-MwpPowerStatusView`). Kontrakt: Read, Change, Destructive, Undo, RemoteTarget; tryby Embedded, SeparateWindow, DashboardWidget; widget `PowerStatus`. Lista ochronna `MWP.Core`: kategoria `PowerPlan` (3 plany wbudowane).
- **Parsowanie niezależne od języka:** GUID-y i struktura linii (`ConvertFrom-MwpPowercfgOutput`); testy na symulatorze z komunikatami po polsku i angielsku dają ten sam wynik; na tym komputerze (Windows 11 PL z angielskimi etykietami `powercfg`) odczyt zgodny z `powercfg /qh`. Odczyt przez `/qh` — `/q` nie pokazuje w Windows 11 ukrytych akcji przycisków i pokrywy (sprawdzone).
- **Sposób pobrania raportów (ustalony w tej fazie, D-044):** raport tworzony w katalogu tymczasowym komputera docelowego, treść HTML wraca tym samym połączeniem (Base64), katalog usuwany; zapis w `<katalog danych>\reports` albo w folderze z pola w widoku; otwarcie w przeglądarce komputera lokalnego.
- **Okno (`MWP.UI`):** katalog widoków modułów wbudowanych (`Get-MwpModuleViewCatalog`), `Instance.xaml` z `ModuleHost`, widok `Power.xaml` (plany, AC/DC, przyciski i pokrywa, hibernacja i szybkie uruchamianie, raporty, cofnięcia), `Invoke-MwpUiInstanceChange` (podgląd w tle → okno potwierdzenia → wykonanie w tle), `Start-MwpUiPowerRefresh`, `Start-MwpUiPowerReport`, `Get-MwpPowerOption`, `Get-MwpPowerChangeStep`, `Get-MwpUiChangeScript`.
- **Test dymny okna (automatyczny, kopia aplikacji w katalogu tymczasowym, bez zmian systemu)** w 5.1 i 7.6.7: instancja „Zasilanie — localhost”, odczyt w tle (plan, listy AC/DC, hibernacja, ostrzeżenie o braku administratora), zmiana wartości na liście → „Zastosuj zmiany…” → okno potwierdzenia z podglądem i komputerem docelowym → Anuluj (wartość w systemie bez zmian, sprawdzone `powercfg /qh`), motyw ciemny, osobne okno, zamknięcie instancji — kod wyjścia 0; zrzuty obejrzane.
- **Znalezione i poprawione w trakcie:** (1) PowerShell traktuje polskie cudzysłowy „ ” jako ograniczniki tekstu — w tekstach w podwójnym cudzysłowie ich nie używamy; (2) blok wywołany z innego zakresu niż `MWP.Remote` omija mock `powercfg.exe` — **pierwsza wersja testu ścieżki zdalnej wywołała prawdziwy `powercfg` na komputerze deweloperskim** (odczyt i jedna zmiana „Uśpij po (sieć)” 900 → 60 s z natychmiastowym cofnięciem do 900 s; stan po teście sprawdzony `powercfg /qh` — zgodny z wyjściowym); poprawka: blok wiązany z `MWP.Remote` (`NewBoundScriptBlock`) i mock `powercfg.exe` także w `MWP.Power` i w zakresie pliku testu; (3) parametr `Set-ItemProperty -Type` jest dynamiczny (analizator zgodności) — `New-ItemProperty -PropertyType`.
- **Decyzje:** D-044.
- **Ograniczenia:** prawdziwe zmiany (`/setactive`, `/duplicatescheme`, `/delete`, `/hibernate`, `HiberbootEnabled`) i raporty nie były wykonywane na komputerze deweloperskim (zasada 5 `CLAUDE.md`) — tylko testy z mockiem, odczyt i podgląd; brak edycji opisu planu (`/changename` z opisem); zmiana ustawień dotyczy planu aktywnego (inne plany: `-PlanGuid` w CLI).

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. `.\Start-MyWindowsPower.ps1` (5.1 i 7.x) → Zasilanie → instancja localhost: lista planów, wartości AC/DC zgodne z Panelem sterowania (Opcje zasilania) i `powercfg /qh`.
2. Zmiana „Wyłącz ekran po” (sieć i bateria) → „Zastosuj zmiany…” → potwierdzenie; sprawdzenie w Ustawieniach systemu; cofnięcie z listy „Zmiany zasilania do cofnięcia”.
3. „Dodaj „Najwyższa wydajność””, „Aktywuj”, „Duplikuj” z nazwą, „Zmień nazwę”, „Usuń…” (wpisanie nazwy) planu własnego i cofnięcie usunięcia (plan wraca z tym samym GUID); odmowa usunięcia planu aktywnego i wbudowanego.
4. Aplikacja uruchomiona jako administrator (`-Elevate`): hibernacja wyłącz/włącz (`powercfg /a`), szybkie uruchamianie (Panel sterowania → Opcje zasilania → Wybierz działanie przycisków), cofnięcie.
5. Raport baterii (laptop) i raport energii (administrator, np. 10 s): zapis w folderze, otwarcie w przeglądarce; na komputerze stacjonarnym — czytelny komunikat dla raportu baterii.
6. Komputer zdalny: instancja Zasilanie dla komputera zdalnego (Połącz, poświadczenia), odczyt, zmiana ustawienia i cofnięcie, raport (treść ze zdalnego komputera, zapis lokalny); odłączenie sieci w trakcie — błąd tylko w tej instancji.
7. Widget „Zasilanie” na Pulpicie (localhost i komputer zdalny).
8. System w języku angielskim (jeśli dostępny) albo konto z innym językiem wyświetlania — ten sam odczyt.

## Następna faza
FAZA 7 — Usługi Windows. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_7.md`.
