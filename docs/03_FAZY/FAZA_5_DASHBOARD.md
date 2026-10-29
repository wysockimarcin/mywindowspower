# FAZA 5 — Dashboard

**Status:** ZAKOŃCZONA (ręczna weryfikacja z komputerem zdalnym i porównanie danych z narzędziami systemowymi — u użytkownika, lista niżej)

## Cel
Pierwszy realny widok, bezpieczny (tylko odczyt): informacje o systemie i sprzęcie, oraz Dashboard jako konfigurowalna kompozycja niezależnych widgetów, które mogą pokazywać różne komputery jednocześnie (D-019).

## Zależności
FAZY 2, 3 i 4 zakończone.

## Zakres
- Moduł `MWP.Dashboard`: `Get-MwpSystemInfo` (przyjmuje kontekst wykonania, działa dla `localhost` i komputera zdalnego) zwracający obiekt z danymi: system (wersja, build, data instalacji), uptime, CPU, RAM (użycie), GPU, dyski (pojemność, wolne miejsce, typ), płyta główna i BIOS, bateria (jeśli jest), podstawowy stan sieci.
- Użycie CIM (`Get-CimInstance`), bez przestarzałego WMI; odporność na brak danych.
- Widok `Dashboard.xaml`: kafelki, odświeżanie w tle, przycisk „Odśwież", automatyczne odświeżanie opcjonalne.
- Eksport raportu do JSON i tekstu.
- **Kontrakt widgetu (ADR):** widget to osobny kontrakt prezentacji danych, a nie miniaturowe okno: własna konfiguracja, jawne powiązanie z instancją modułu lub źródłem danych i komputerem docelowym, korzystanie z tych samych usług aplikacyjnych co pełny widok. Stany: ładowanie, błąd, brak danych, utrata połączenia.
- **Dashboard (widok `Dashboard.xaml`):** dodawanie i usuwanie widgetów, wybór komputera i parametrów modułu dla każdego widgetu, rozmiar i położenie (jeśli pozwala model UI), odświeżanie ręczne i automatyczne z kontrolowaną częstotliwością, zapis i odtworzenie konfiguracji po ponownym uruchomieniu (miejsce zapisu do ustalenia w `DECYZJE.md`, propozycja: plik lokalny poza repozytorium).
- **Izolacja widgetów:** błąd jednego widgetu ani utrata połączenia z jednym komputerem nie zatrzymuje pozostałych; limit równoległych zadań w tle; usunięcie widgetu anuluje jego zadania i zwalnia zasoby.
- **Odinstalowanie modułu (D-031):** `Uninstall-MwpModulePackage` (FAZA 3) usuwa z konfiguracji Dashboardu wszystkie widgety odinstalowanego modułu (z anulowaniem ich zadań); przy odtwarzaniu konfiguracji widget modułu, którego już nie ma, jest pomijany z ostrzeżeniem i usuwany z zapisu.
- Pierwsze widgety: informacje o systemie lokalnym i wybranego komputera zdalnego. Kolejne moduły dostarczają własne widgety w swoich fazach.
- Testy Pester z mockami CIM.

## Wejście z FAZY 4 (do uwzględnienia)
- Okno hosta: moduł `MWP.UI` (`src/UI`, D-039). Pulpit to dziś zaślepka `Views/Dashboard.xaml` (`Initialize-`/`Update-MwpDashboardView`): karty komputerów i lista otwartych instancji; odstępstwa od mockupu do uzupełnienia w tej fazie — D-040 (2).
- Zadania w tle: `Start-MwpUiTask` (funkcje MWP w puli GUI) i `Register-MwpUiOperation` (operacje `Start-MwpOperation` na komputerze), wyniki w wątku okna przez `Update-MwpUiTask` (zegar okna, 250 ms) — do odświeżania widgetów.
- Stan połączenia do prezentacji: `Get-MwpConnectionStateInfo` (etykieta, ton, `NeedsCredential`), plakietka `Mwp.StateBadge` w `Themes/Styles.xaml`; okno poświadczeń `Show-MwpCredentialDialog`.
- Odinstalowanie modułu w GUI: `Uninstall-MwpUiModule` zamyka instancje modułu — tu dopisać usuwanie widgetów (D-031).
- Odczyt informacji o komputerze: `Get-MwpTargetInfo -Context [-AsOperation]` (`MWP.Remote`, D-041).
- Ręczna weryfikacja okna z FAZY 4 (lista w `FAZA_4_GUI_SZKIELET.md`) — jeśli nie została wykonana, zrób ją na początku.

## Poza zakresem
Zmiany w systemie.

## Checklista
- [x] `Get-MwpSystemInfo` + podfunkcje — `src/Modules/MWP.Dashboard/Public/Get-MwpSystemInfo.ps1`, blok odczytu `Private/Get-MwpSystemInfoScript.ps1` (sekcje System, Cpu, Memory, Gpu, Disks, Board, Battery, Network), `Resolve-MwpSystemInfoData`, `Format-MwpByteSize`, `Format-MwpDuration`
- [x] Obsługa braków danych (np. brak baterii) — każda sekcja osobno, błąd → `Warnings`, brak baterii → `Present = $false`; testy `SystemInfo.Tests.ps1` (brak baterii, błąd klasy CIM, brak `Win32_OperatingSystem`)
- [x] Widok Dashboard z kafelkami — `src/UI/Views/Dashboard.xaml` (kafelek: tytuł, plakietka stanu, sekcje z paskami, stopka), test dymny okna w 5.1 i 7.6.7 (zrzuty obejrzane)
- [x] Odświeżanie w tle bez zawieszania GUI — `Start-MwpWidgetRefresh` → `Start-MwpOperation` (pula `MWP.Remote`) + `Register-MwpUiOperation -Quiet`, wynik w wątku okna (`Complete-MwpWidgetRefresh`); zamknięcie okna w trakcie odświeżania bez pytania i bez czekania (test dymny)
- [x] Eksport JSON / tekst — `ConvertTo-MwpSystemReport`, `Export-MwpSystemReport` (JSON bez BOM, tekst z BOM), przycisk eksportu kafelka (`Export-MwpUiWidget`, okno zapisu pliku); testy na `TestDrive`
- [x] `Get-MwpSystemInfo` działa dla `localhost` i komputera zdalnego — localhost: prawdziwy odczyt w teście i w oknie; komputer zdalny: testy z mockiem `Invoke-MwpOnTarget`, w oknie — izolacja błędu nieistniejącego komputera; **prawdziwy komputer zdalny — DO WERYFIKACJI NA WINDOWS (ręcznie)**
- [x] Kontrakt widgetu opisany w `DECYZJE.md` i `ARCHITEKTURA.md` — D-043, sekcje „Dashboard i widgety” i „Kontrakt modułu” (pole `Widgets`)
- [x] Dashboard: dodawanie i usuwanie widgetów, komputer per widget, odświeżanie ręczne i automatyczne — `Edit-MwpUiWidget` + `Show-MwpWidgetEditor` (rodzaj, komputer, nazwa, częstotliwość, rozmiar, sekcje), `Remove-MwpUiWidget`, `Move-MwpUiWidget`, „Odśwież”, „Odśwież wszystkie”, przełącznik „Odświeżanie automatyczne”, limit `dashboardMaxParallelRefresh`
- [x] Izolacja widgetów (awaria jednego nie zatrzymuje reszty), anulowanie zadań przy usunięciu — `tests/UI/Widgets.Tests.ps1` (własna instancja, awaria funkcji danych, utrata połączenia, usunięcie z anulowaniem i zamknięciem instancji, komputer spoza rejestru, brak poświadczeń)
- [x] Zapis i odtworzenie konfiguracji Dashboardu — `Get-`/`Set-MwpDashboardConfiguration` (klucze `dashboardWidgets`, `dashboardAutoRefresh`, `dashboardMaxParallelRefresh`), `Initialize-MwpUiDashboard`; testy `Dashboard.Tests.ps1`, `Widgets.Tests.ps1` (test architektoniczny 10); test dymny (kolejność po przesunięciu zapisana)
- [x] Usuwanie widgetów odinstalowanego modułu (przy odinstalowaniu i przy odtwarzaniu konfiguracji), testy Pester (D-031) — `Uninstall-MwpModulePackage` (jeden zapis atomowy z rejestrem), `Uninstall-MwpUiModule` (usunięcie z okna), `Repair-MwpDashboardConfiguration`, `Remove-MwpDashboardWidget`; testy `ModulePackage.Tests.ps1`, `Dashboard.Tests.ps1`, `Widgets.Tests.ps1`; baner na Pulpicie w teście dymnym
- [x] Testy Pester, PSScriptAnalyzer — `.\tests\Invoke-Checks.ps1` w 5.1 i 7.6.7 (wyniki niżej)
- [x] Dokumentacja zaktualizowana, commit `FAZA 5: ...`

## Kryteria ukończenia
Dane zgadzają się z narzędziami systemowymi (Menedżer zadań, `winver`, `systeminfo`); dwa widgety dla dwóch komputerów działają niezależnie, a utrata połączenia z jednym nie zatrzymuje drugiego; po odinstalowaniu modułu jego widgety znikają z Dashboardu i z zapisanej konfiguracji.

## Do weryfikacji na Windows 11
Poprawność danych i wygląd widoku, konfiguracja widgetów dla komputera lokalnego i zdalnego, odtworzenie układu po ponownym uruchomieniu.

## Wyniki
Zakończona 2026-10-27.

- **Baza przed zmianami** (każda wersja w nowym procesie): 5.1.26100.9711 — 0 uwag, 959/959; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 959/959.
- **Wynik końcowy:** `.\tests\Invoke-Checks.ps1`, każda wersja w nowym procesie: 5.1.26100.9711 — 0 uwag PSScriptAnalyzer, 1094/1094; 7.6.7 (`C:\Program Files\PowerShell\7\pwsh.exe`) — 0 uwag, 1094/1094 (+135 testów).
- **`MWP.Dashboard` 0.5.0:** `Get-MwpSystemInfo -Context [-Section] [-WidgetParameters] [-AsOperation]` — CIM (`Win32_OperatingSystem`, `Win32_ComputerSystem`, `Win32_Processor`, `Win32_PhysicalMemory`, `Win32_VideoController`, `Win32_LogicalDisk`, `MSFT_PhysicalDisk`/`MSFT_Partition` — typ dysku SSD NVMe/SSD/HDD, `Win32_BaseBoard`, `Win32_BIOS`, `Win32_Battery`, `Win32_NetworkAdapter(Configuration)`) i rejestr (`DisplayVersion`, `UBR`); blok samowystarczalny, zgodny z 5.1, zwraca JSON (serializacja WinRM spłaszcza obiekty głębsze niż 2 poziomy); `ConvertTo-MwpSystemInfoView` (sekcje, paski i progi: dysk i RAM ≥ 80% ostrzeżenie, ≥ 90% krytyczny; bateria ≤ 20/10%), `ConvertTo-MwpSystemReport`, `Export-MwpSystemReport`. Kontrakt: `Capabilities` Read, RemoteTarget; tryby Embedded, SeparateWindow, DashboardWidget; widget `SystemInfo`.
- **`MWP.Core` 0.5.0 (wersja hosta):** opcjonalne pole kontraktu `Widgets` (walidacja w `Test-MwpModuleDefinition`, słownik `WidgetRefreshSeconds`, `WidgetSizes`), `Get-MwpWidgetDefinition`, `Get-`/`Set-MwpDashboardConfiguration`, `Remove-MwpDashboardWidget`, `Repair-MwpDashboardConfiguration`; `Uninstall-MwpModulePackage` usuwa widgety modułu (`Data.RemovedWidgets`); szablon ustawień: `dashboardWidgets` (widget „Informacje o systemie” dla localhost), `dashboardAutoRefresh`, `dashboardMaxParallelRefresh` (bez zmiany `schemaVersion`).
- **`MWP.Remote` 0.5.0:** `Data.ErrorKind` w wyniku błędu `Wait-MwpOperation` (także `Timeout` po limicie czasu) i `CredentialRequired` w `Start-MwpOperation`.
- **`MWP.UI`:** logika widgetów bez WPF (`New-MwpWidgetRuntime`, `Get-MwpWidgetParameterSet`, `Get-MwpWidgetDue`, `Start-`/`Complete-MwpWidgetRefresh`, `Get-MwpWidgetStatus`, `Get-MwpWidgetStateInfo`, `Get-MwpWidgetRow`, `Remove-MwpWidgetRuntime`, `ConvertTo-MwpWidgetConfiguration`), okno (`Initialize-MwpUiDashboard`, `Invoke-MwpUiDashboardTick`, `Update-MwpDashboardWidgets`, `Save-MwpUiDashboard`, `Edit-`/`Remove-`/`Move-`/`Connect-`/`Export-MwpUiWidget`, `Show-MwpWidgetEditor`, `Dialogs/WidgetEditor.xaml`), Pulpit: widgety + dotychczasowe karty komputerów i instancje; zadania ciche (`Register-MwpUiOperation -Quiet`): odświeżenia widgetów nie zajmują paska stanu i nie wstrzymują zamknięcia okna.
- **Paczka przykładowa** `samples/MWP.Przyklad` 1.1.0: widget „Komputer (przykład)” (`Get-MwpPrzykladWidgetData`, `ConvertTo-MwpPrzykladWidgetView`, tryb `DashboardWidget`) do ręcznej weryfikacji widgetu modułu z paczki i jego usuwania przy odinstalowaniu (D-031); `MinimumHostVersion` bez zmian (0.4.0 pomija pole `Widgets`).
- **Testy:** nowe `tests/Modules/MWP.Dashboard/SystemInfo.Tests.ps1` (mocki CIM i rejestru, 18), `tests/Modules/MWP.Core/Dashboard.Tests.ps1` (konfiguracja, odtworzenie, kontrakt widgetu), `tests/UI/Widgets.Tests.ps1` (izolacja, harmonogram, stany, wiersze, odtworzenie konfiguracji, krok zegara na prawdziwych widgetach); rozszerzone `ModulePackage.Tests.ps1` (widgety odinstalowanego modułu), `Samples.Tests.ps1` (widget paczki przykładowej). Odczyt prawdziwych danych w testach — tylko localhost, tylko odczyt.
- **Test dymny okna (automatyczny, kopia aplikacji w katalogu tymczasowym, bez zmian w ustawieniach repozytorium i w systemie)** w 5.1 i 7.6.7, motyw jasny i ciemny: odtworzenie 4 zapisanych widgetów (widget odinstalowanego modułu `Przyklad` pominięty, usunięty z zapisu, baner na Pulpicie), 2 widgety localhost „Aktualne”, widget nieistniejącego komputera zdalnego „Błąd” (TrustedHosts) bez wpływu na pozostałe, usunięcie widgetu zamyka jego instancję, przesunięcie zapisuje kolejność, okno edycji widgetu, zamknięcie okna w trakcie odświeżania — kod wyjścia 0, 0 instancji po zamknięciu; zrzuty obejrzane (bez zapisu w repozytorium).
- **Znalezione i poprawione w trakcie:** (1) w 5.1 `@(...)` na liście `List[object]` utworzonej przez `New-Object` i trzymanej w tabeli kończy się „Niezgodne typy argumentów” (`PSToObjectArrayBinder`) — lista widgetów przez `::new()`, test regresji; (2) okno pytało przy zamykaniu o „zadania w tle”, gdy trwało odświeżenie widgetu — zadania ciche; (3) wiązanie `Width` kafelka nie działało (liczba z podwyrażenia opakowana w PSObject) — `[double]`; (4) `DisplayMemberPath` nie działa ze stylem ComboBox (`SelectionBoxItemTemplate`) — `ItemTemplate`; (5) w testach mocki z `GetNewClosure()` tracą parametry wywołania.
- **Decyzje:** D-043 (kontrakt widgetu, konfiguracja Dashboardu; decyzje użytkownika: zapis w `settings.local.json`, opcjonalne pole `Widgets`, widgety nad dotychczasową zawartością Pulpitu).
- **Ograniczenia:** rozmiar i położenie widgetu to szerokość (Normalny/Szeroki) i kolejność (przesuwanie), bez przeciągania; odświeżanie automatyczne tylko przy widocznym Pulpicie; `AdapterRAM` karty graficznej (UInt32) jest zaniżony powyżej 4 GB, dlatego widok nie pokazuje pamięci GPU; pierwszy odczyt `Get-MwpSystemInfo` na localhost trwa ok. 3–5 s (CIM, `MSFT_*`), w tle.

## Do weryfikacji na Windows 11 — lista dla użytkownika
1. `.\Start-MyWindowsPower.ps1` (5.1 i 7.x): Pulpit z widgetem „Informacje o systemie” (localhost); porównanie z Menedżerem zadań (CPU, RAM, dyski), `winver` (wersja, kompilacja z UBR), `systeminfo` (data instalacji, czas pracy, BIOS, płyta).
2. „+ Dodaj widget” dla komputera zdalnego (sekcje według uznania): przycisk „Połącz”, okno poświadczeń, stan „Aktualne”, dane ze zdalnego komputera.
3. Dwa widgety (localhost i komputer zdalny): odłączenie sieci komputera zdalnego → „Utrata połączenia” tylko w jego kafelku, widget localhost odświeża się dalej; po przywróceniu sieci — „Odśwież”.
4. Ustawienia widgetu (koło zębate): zmiana sekcji, częstotliwości, rozmiaru, nazwy; przesuwanie strzałkami; usunięcie; przełącznik „Odświeżanie automatyczne”.
5. Ponowne uruchomienie aplikacji: ten sam układ widgetów (kolejność, rozmiary, komputery, sekcje).
6. Eksport raportu z kafelka do `.txt` i `.json`; otwarcie w Notatniku (polskie znaki).
7. Paczka przykładowa `samples/MWP.Przyklad` 1.1.0 (instrukcja w `samples/README.md`; przy zainstalowanej wersji 1.0.0 najpierw ją odinstalować): instalacja, **Pulpit → + Dodaj widget → „Komputer (przykład)”** (localhost i komputer zdalny), potem **Moduły → odinstalowanie** — widgety modułu znikają z Pulpitu i z `config/settings.local.json`, pozostałe działają dalej. Wariant: zamknięcie aplikacji z widgetem modułu, ręczne usunięcie folderu modułu z `<katalog danych>\modules`, start — baner o pominiętym widgecie i brak wpisu w zapisie.
8. Motyw ciemny i skalowanie 125–150% (kafelki, paski, okno edycji).

### Korekta D-053 — widget w każdym module i konfiguracja widgetów modułu (2026-10-29)

Powód: w oknie „Dodaj widżet” były tylko 3 typy (pole `Widgets` miały tylko `Dashboard`, `Power`, `Services`). Po korekcie każdy moduł deklaruje widget (13 typów; 11 na liście dodawania — zalążki `Security` i `Tweaks` domyślnie ukryte), a użytkownik w widoku „Moduły” (sekcja „Widżety”) ukrywa typy i ustawia domyślne parametry nowych widgetów. Szczegóły: D-053, `ARCHITEKTURA.md` („Dashboard i widgety”). Zainstalowana u użytkownika paczka `MWP.Przyklad` 1.0.0 nie ma widgetu — to stara wersja, nie błąd; widget „Komputer (przykład)” jest w 1.1.0 (`samples/MWP.Przyklad`). Host nie aktualizuje modułów (D-031): Moduły → „Odinstaluj” 1.0.0, potem „Zainstaluj z pliku .mwpmod…” z paczką 1.1.0 (instrukcja pakowania w `samples/README.md`).

Do weryfikacji na Windows 11 — lista dla użytkownika (prawdziwa aplikacja; hasła tylko w oknie aplikacji, nigdy w rozmowie):
1. Pulpit → „+ Dodaj widżet”: na liście są Windows Update, Sieć, Autostart, Programy, Aktualizacje programów, Miejsce do odzyskania, Dziennik operacji, Komputery oraz dotychczasowe Informacje o systemie, Zasilanie, Status usług; pozycje „tylko ten komputer” (Dziennik operacji, Komputery) nie pozwalają wybrać komputera zdalnego; lista jest czytelna (posortowana po module).
2. Dodaj każdy nowy typ dla `localhost` i dla jednego komputera zdalnego (tam, gdzie się da): stany Ładowanie → Aktualne; odśwież ręcznie i poczekaj na automatyczne; nowy widget pokazuje tylko minimum danych (np. „Sieć” — połączone adaptery z IPv4, „Programy” — same liczby).
3. Widgety kosztowne: „Miejsce do odzyskania” i „Aktualizacje programów” odświeżają się tylko ręcznie i nie blokują okna w trakcie (kilka–kilkanaście sekund); na komputerze zdalnym „Aktualizacje programów” bez konta administratora pokazuje czytelne ostrzeżenie; „Miejsce do odzyskania” niczego nie usuwa (porównaj z widokiem modułu Czyszczenie — te same sumy).
4. Stany błędów: wyłączony komputer zdalny (Utrata połączenia), komputer bez hasła w pamięci (Wymaga poświadczeń → „Połącz”), widget „Komputery” pokazuje komputer jako niedostępny.
5. Moduły → wybierz moduł → sekcja „Widżety”: odznacz „Pokazuj na liście »Dodaj widżet«” dla jednego typu — typ znika z okna „Dodaj widżet”, a dodany wcześniej widget tego typu zostaje na Pulpicie i po restarcie aplikacji też.
6. „Moduł dostępny jako widżet” (odznacz/zaznacz) — wszystkie typy modułu znikają i wracają; dla `Security`/`Tweaks` zaznaczenie pokazuje widget-zalążek.
7. Zmień domyślne parametry (np. „Informacje o systemie” — tylko System i Pamięć RAM), dodaj nowy widget — pokazuje tylko wybrane sekcje i zajmuje mniej miejsca; istniejące widgety bez zmian; „Przywróć domyślne” wraca do manifestu.
8. `config/settings.local.json` ma tylko oczekiwane klucze `modules.<Id>.widgets.<Id>` (`visible`, `defaultParameters`); po odinstalowaniu modułu z paczki jego wpis `modules.<Id>` znika.
9. Istniejące widgety „Zasilanie” i „Status usług” sprzed korekty wyglądają jak dotąd (wszystkie sekcje) — `PreviousDefault`; edycja widgetu pokazuje te sekcje zaznaczone.
10. Paczka przykładowa: odinstaluj 1.0.0, zainstaluj 1.1.0 — pojawia się widget „Komputer (przykład)”.

## Następna faza
FAZA 6 — Zasilanie. Prompt: `docs/04_PROMPTY/PROMPT_FAZA_6.md`.
