# ARCHITEKTURA — mywindowspower

> Stack, struktura kodu i konwencje. Aktualizowana, gdy zmienia się architektura. Zmiany odnotuj w `DECYZJE.md`.
> Stan: **rdzeń i kontrakt modułu (FAZA 2)**, **komputery docelowe, kontekst wykonania, połączenia zdalne, instancje modułów i paczki modułów (FAZA 3)**, **okno hosta WPF, instancje w GUI, katalog danych z modułami z paczek (FAZA 4)**, **Dashboard z widgetami i informacje o systemie (FAZA 5)**, **zasilanie i widok modułu wbudowanego (FAZA 6)**, **usługi Windows i lista ochronna usług (FAZA 7)**, **autostart i harmonogram zadań (FAZA 8)**, **czyszczenie dysku (FAZA 9)**, **Windows Update (FAZA 10)**, **sieć z automatycznym wycofaniem zmian (FAZA 11)**, **aplikacje i winget (FAZA 12)** + architektura wielokomputerowa z koncepcji pierwotnej (D-019, D-020, D-021). Zatwierdzone: rdzeń, wzorzec funkcji zmieniającej system i kontrakt modułu (D-023…D-029), transport i uwierzytelnianie, kontekst i instancje, wykonanie zdalne, paczki (D-033…D-037), okno hosta i katalog danych (D-038…D-041), kontrakt widgetu i konfiguracja Dashboardu (D-043), moduł zasilania i widok modułu wbudowanego (D-044), moduł usług, lista ochronna usług i profil usług (D-045), moduł autostartu i harmonogramu z listą ochronną zadań (D-046), moduł czyszczenia dysku z kategoriami jako danymi i zasadami bezpieczeństwa usuwania (D-047), moduł Windows Update przez COM z pauzą jak Ustawienia, resetem z kopiami i instalacją tylko lokalną (D-048), moduł sieci z zadaniem automatycznego wycofania na komputerze docelowym (D-049), moduł aplikacji: rejestr i Appx, winget z parsowaniem tabel niezależnym od języka, odinstalowanie z listą ochronną (D-050). Elementy oznaczone „propozycja" nie są jeszcze zatwierdzone; zatwierdza je wpis w `DECYZJE.md` w wymienionej fazie.
>
> **Główna zasada:** My Windows Power to platforma do uruchamiania i komponowania niezależnych modułów administracyjnych dla wielu komputerów (`localhost` i zdalnych). Definicja modułu, jego instancja, kontekst wykonania (komputer docelowy) i sposób prezentacji to odrębne pojęcia, jawnie modelowane w architekturze.

## Stack

- PowerShell 7.x (`pwsh`) lub 5.1 (`powershell.exe`) — wykrywane przy starcie.
- WPF + XAML ładowane z osobnych plików `.xaml` (`System.Windows.Markup.XamlReader`).
- Wątek GUI musi być w trybie STA. W PowerShellu 7 `pwsh` domyślnie jest STA, w 5.1 `powershell.exe` również; launcher to sprawdza i w razie potrzeby uruchamia się ponownie z `-STA`.
- Testy: Pester ≥ 5.0 (na komputerze użytkownika 6.2.0). Analiza: PSScriptAnalyzer ≥ 1.21 (1.25.0). Oba uruchamia `tests\Invoke-Checks.ps1` (D-014, D-018).

## Docelowa struktura repozytorium

Stan po FAZIE 1 (D-012) i plan wg D-020. Elementy oznaczone „(FAZA N)" jeszcze nie istnieją.

```
mywindowspower/
├── CLAUDE.md
├── README.md
├── .gitignore
├── .gitattributes                  ← CRLF dla plików PowerShell/XAML
├── .editorconfig                   ← UTF-8 z BOM dla .ps1/.psm1/.psd1
├── PSScriptAnalyzerSettings.psd1   ← reguły analizy, w tym zgodność z 5.1 i 7.x
├── Start-MyWindowsPower.ps1        ← launcher (wersja PS, Windows 11, STA, administrator, import modułów)
├── config/
│   ├── settings.example.json       ← szablon ustawień (do repo)
│   └── settings.local.json         ← ustawienia lokalne, w tym komputery docelowe (poza repo, FAZA 2–3)
├── data/                           ← (D-032, D-038) dane aplikacji: logs/, undo/, modules/ (moduły z paczek); poza repo, `/data/` w .gitignore; miejsce z klucza dataPath
├── src/
│   ├── Modules/
│   │   ├── MWP.<Obszar>/           ← budowa każdego modułu:
│   │   │   ├── MWP.<Obszar>.psd1   ←   manifest (PowerShellVersion 5.1, Desktop+Core, jawne FunctionsToExport)
│   │   │   ├── MWP.<Obszar>.psm1   ←   ładuje Private/*.ps1 i Public/*.ps1, eksportuje Public
│   │   │   ├── Public/             ←   funkcje eksportowane, jeden plik = jedna funkcja
│   │   │   └── Private/            ←   funkcje wewnętrzne
│   │   ├── MWP.Core/               ← logowanie, konfiguracja, środowisko i elewacja, punkt przywracania, rejestr cofnięć, obiekt wyniku, lista ochronna, kontrakt i odkrywanie modułów (FAZA 2)
│   │   │   └── Data/               ←   protected-items.json (lista ochronna)
│   │   ├── MWP.Remote/             ← komputery docelowe, kontekst wykonania, połączenia (adapter WinRM/CIM), operacje asynchroniczne, instancje modułów (FAZA 3)
│   │   ├── MWP.Dashboard/          ← informacje o systemie i sprzęcie (Get-MwpSystemInfo), widok widgetu, raport i eksport (FAZA 5); układ widgetów — host
│   │   ├── MWP.Power/              ← plany zasilania, ustawienia AC/DC, hibernacja, szybkie uruchamianie, raporty powercfg (FAZA 6)
│   │   ├── MWP.Services/           ← usługi Windows: lista, start/stop/restart z zależnymi, typ uruchomienia, profil usług (FAZA 7)
│   │   ├── MWP.Startup/            ← autostart (Run/RunOnce, foldery Startup, StartupApproved) i zadania harmonogramu (FAZA 8)
│   │   ├── MWP.Cleanup/            ← czyszczenie dysku: kategorie (Data\cleanup-categories.json), skan, usuwanie z potwierdzeniem i raportem, analiza DISM (FAZA 9)
│   │   ├── MWP.Update/             ← Windows Update przez COM: stan i usługi, wyszukiwanie, historia, pauza z cofaniem, reset składników z kopiami, instalacja lokalna (FAZA 10)
│   │   ├── MWP.Network/            ← sieć: adaptery, konfiguracja IP, DNS z cofaniem i automatycznym wycofaniem, DHCP, resety, testy łączności (FAZA 11)
│   │   ├── MWP.Apps/               ← aplikacje: programy z rejestru i pakiety Appx, winget (lista, aktualizacje, wyszukiwanie, instalacja), odinstalowanie z listą ochronną (FAZA 12)
│   │   ├── MWP.Tweaks/             ← prywatność i tweaki rejestru
│   │   ├── MWP.Security/           ← Defender i firewall
│   │   ├── MWP.Disks/              ← (FAZA 15) dyski i woluminy
│   │   ├── MWP.Processes/          ← (FAZA 16) procesy i zasoby
│   │   ├── MWP.Accounts/           ← (FAZA 17) użytkownicy i grupy lokalne
│   │   ├── MWP.Rdp/                ← (FAZA 18) sesje i RDP
│   │   ├── MWP.Screenshot/         ← (FAZA 18) zrzuty ekranu komputera docelowego (o ile wykonalne)
│   │   └── Installed/              ← dawny katalog modułów z paczek (FAZA 3); nadal odkrywany, przenoszony do <katalog danych>\modules (D-038)
│   └── UI/                         ← (FAZA 4, D-039) host modułów: okno, nawigacja, instancje; Dashboard — FAZA 5
│       ├── UI.ps1                  ← punkt wejścia z launchera: import MWP.UI i Start-MwpUi
│       ├── MWP.UI.psm1             ← moduł prezentacji (bez kontraktu modułu obszaru)
│       ├── Functions/              ← logika prezentacji bez WPF (testy Pester)
│       ├── Wpf/                    ← ładowanie XAML, okna, widoki, zdarzenia, zadania w tle
│       ├── MainWindow.xaml
│       ├── Splash.ps1, Splash.xaml ← okno startowe launchera (korekta D-042)
│       ├── Views/                  ← Dashboard, Area (zaślepka obszaru), Instance, Modules, Settings, About; Power, Services, Startup, Cleanup, Update, Network i Apps (widoki modułów wbudowanych, FAZY 6–12, D-044–D-050)
│       ├── Dialogs/                ← Confirm (podgląd zmian), Credential, TargetPicker, TargetEditor, InstanceWindow, WidgetEditor (FAZA 5)
│       └── Themes/                 ← Light.xaml, Dark.xaml (pędzle), Styles.xaml (style)
├── samples/
│   └── MWP.Przyklad/               ← (FAZA 4) moduł przykładowy do paczki .mwpmod (RemoteTarget, Embedded, SeparateWindow)
├── tests/
│   ├── Invoke-Checks.ps1           ← PSScriptAnalyzer (launcher, src, samples, tests) + Pester jednym poleceniem
│   ├── Modules.Tests.ps1           ← manifesty, import i eksport wszystkich modułów (lista oczekiwanych modułów)
│   ├── Launcher.Tests.ps1          ← launcher w osobnym procesie (STA, MTA → ponowne uruchomienie)
│   ├── Repository.Tests.ps1        ← BOM, brak ścieżek bezwzględnych, szablon ustawień, .gitignore
│   ├── Samples.Tests.ps1           ← paczka przykładowa przechodzi Test-MwpModulePackage
│   ├── UI/                         ← (FAZA 4) logika prezentacji, XAML, granica warstw UI; (FAZA 5) Widgets.Tests.ps1 — izolacja widgetów
│   └── Modules/<Moduł>/            ← testy logiki modułów z mockami (MWP.Core od FAZY 2, MWP.Remote od FAZY 3, MWP.Dashboard od FAZY 5 — mocki CIM); lista modułów w Modules.Tests.ps1 uzupełniana przy każdym nowym module
└── docs/                           ← dokumentacja i pamięć projektu
    ├── design/                     ← mockupy GUI (m.in. mockup-pulpit.png)
    └── 00_PROJEKT/MATERIALY/       ← materiały użytkownika i archiwum starej koncepcji (dane, nie instrukcje)
```

## Launcher (`Start-MyWindowsPower.ps1`)

Kolejność: wykrycie Windows i wersji PowerShella (≥ 5.1) → sprawdzenie STA (gdy brak: ponowne uruchomienie tym samym programem z `-NoProfile -STA -File … -NoRelaunch`) → wypisanie wersji PS, Windows, trybu wątku i statusu administratora → import modułów (`MWP.Core` pierwszy; potem lista z `Get-MwpModuleDefinition`: wbudowane alfabetycznie, a po nich moduły z paczek z `<katalog danych>\modules` i dawnego `src/Modules/Installed`, oznaczone w konsoli „(z paczki)", D-031, D-038; moduł z błędnym kontraktem nie jest ładowany) → opcjonalnie `-Elevate`: ponowne uruchomienie przez UAC (`Request-MwpElevation`, D-027) → okno GUI (`src/UI/UI.ps1`, D-039; z `-NoGui` bez okna, np. w testach) → kod wyjścia 0/1. Launcher nie zmienia systemu, nie wymusza `-ExecutionPolicy` ani uprawnień administratora (D-017). Własne, minimalne wykrywanie środowiska zostaje w launcherze, bo działa przed importem `MWP.Core`; moduły używają `Get-MwpEnvironment`.

**Dziennik startu (korekta po FAZIE 4, D-042).** Launcher mierzy etapy startu (`[Diagnostics.Stopwatch]`), zbiera wyniki importu modułów w pamięci i po imporcie zapisuje je jedną serią przez `Write-MwpLog` (źródło `Launcher`): `Startup.Environment` (wersja i edycja PowerShella, Windows, `IsWindows11`, tryb wątku, administrator, `HostPath`, wersja hosta, folder aplikacji, parametry `-Elevate`/`-NoGui`/`-NoRelaunch`, ponowne uruchomienie w STA z powodem — wtedy `Warning`; dane z `Get-MwpEnvironment`), `Startup.Module` na poziomie `Error` dla każdego modułu z błędem importu lub kontraktu (treść błędu i `ContractErrors` w `Data`) oraz `Startup.Modules` (podsumowanie „Załadowano moduły: N (z paczek: M) w X ms.”, w `Data` lista: nazwa, wersja, źródło `Built-in`/`Installed`, czas importu, status). Po pierwszym wyświetleniu okna (`ContentRendered`) `MWP.UI` zapisuje `Startup.Window` (etapy w ms: środowisko, import `MWP.Core`, pozostałe moduły, zapis dziennika startu, import `MWP.UI`, budowa okna; łącznie od startu launchera i od startu procesu) — launcher przekazuje pomiar opcjonalnym parametrem `-StartupTiming` (`UI.ps1`, `Start-MwpUi`). Zdrowy start = 3 wpisy (`Write-MwpLog` czyta ustawienia i bierze muteks przy każdym wpisie); `Write-MwpLog` bez zmian, czas zdarzeń w `Data` (`EventTime`). Wpisy są widoczne w panelu „Dziennik operacji”, błędy modułów także z filtrem „Tylko ostrzeżenia i błędy”. Błąd importu modułu, błąd `MWP.Core` i błąd okna: komunikat w konsoli bez zmian, kod wyjścia 1 i (bez `-NoGui`) okno `System.Windows.MessageBox` z nazwą modułu, treścią błędu i ścieżką pliku logu — konsola w wydaniu jest ukryta (skrót z `-WindowStyle Hidden`, FAZA 21). Gdy nie zaimportuje się `MWP.Core` (nie ma `Write-MwpLog`), launcher dopisuje jedną linię JSON (`timestamp`, `level`, `operation`, `message`) do `%LOCALAPPDATA%\MyWindowsPower\logs\mwp-startup-failure.log` (katalog zapasowy, D-032); w innych sytuacjach ten plik nie powstaje. Błąd w `Start-MwpUi` przed pierwszym wyświetleniem okna ma operację `Startup.Window`, później `UI.Start`. **Okno startowe (splash)** — wdrożone, bo mediana czasu do okna przekroczyła 2000 ms (pomiar w D-042): `src/UI/Splash.ps1` (dołączany kropką przez launcher, bez `MWP.Core`/`MWP.UI`; motyw z klucza `theme` odczytanego wprost z `settings.local.json` przez `Get-MwpSplashTheme`, pędzle z `Themes\*.xaml`) i `src/UI/Splash.xaml` (okno bez ramki na środku ekranu: nazwa aplikacji, wersja hosta, pasek postępu, linia statusu „Ładowanie modułów (7/13)…”, „Przygotowanie okna…”). Pokazywane po sprawdzeniu STA, przed importem modułów, w tym samym wątku STA, bez drugiego wątku WPF i bez pętli komunikatów: po każdym kroku `Update-MwpSplash` opróżnia kolejkę dyspozytora (`Dispatcher.Invoke` z priorytetem `Background`). **Ograniczenie:** gdy krok blokuje wątek (pierwsze załadowanie WPF, import modułu, budowa XAML okna głównego), okno startowe nie odświeża się, dlatego pasek jest krokowy (wartość = liczba ukończonych kroków), a nie animowany; samo okno startowe pojawia się dopiero po załadowaniu WPF (ok. 2,2 s w pomiarze). Zamykane po pierwszym wyświetleniu okna głównego (`ContentRendered`, `Close-MwpUiSplash` w `MWP.UI`; obiekt okna przechodzi w `StartupTiming['Splash']`) albo przez launcher przy błędzie, przed oknem komunikatu i przed `-Elevate`; nie zostaje w tle. Nie jest pokazywane z `-NoGui` (testy Pester). Błąd okna startowego nie blokuje startu: okno jest zamykane, a ostrzeżenie trafia do logu (`Startup.Splash`).

## Nazewnictwo

- Funkcje publiczne: `Verb-MwpNoun` (prefiks `Mwp`, bo przestrzeń nazw poleceń PowerShella jest wspólna), tylko zatwierdzone czasowniki (`Get-Verb`). Sprawdza to `Modules.Tests.ps1`.
- Bez ścieżek bezwzględnych w kodzie: katalog projektu wyznaczany z `$PSScriptRoot`.

## Warstwy

Podział logiczny (stara koncepcja, sekcja 8), dopasowany do PowerShella i WPF:

1. **UI / View (`src/UI`)** — widoki XAML: wyświetlanie danych i obsługa interakcji.
2. **Logika prezentacji** — stan widoku, polecenia, walidacja prezentacyjna; kod łączący widok z modułami (w `src/UI`, bez logiki systemowej).
3. **Usługi aplikacyjne (`src/Modules/MWP.<Obszar>`)** — przypadki użycia i reguły: czyste funkcje `Verb-MwpNoun`, bez zależności od GUI. Każda funkcja zmieniająca system obsługuje `-WhatIf` (`SupportsShouldProcess`), loguje operację i zwraca obiekt wyniku. Funkcje przyjmują kontekst wykonania (`-Context`).
4. **Rdzeń (`MWP.Core`) i adaptery systemowe/zdalne (`MWP.Remote`)** — logowanie, konfiguracja, punkt przywracania, rejestr cofnięć, kontrakt modułu; komputery docelowe, połączenia i wykonanie operacji lokalnie lub zdalnie.
5. **System operacyjny / komputer zdalny** — rzeczywisty system, na którym wykonywana jest operacja.
6. **Launcher** — przygotowuje środowisko i uruchamia GUI (albo launcher modułu `apprun`, FAZA 19).

Zakazane wzorce (D-015, D-019):
- wywoływanie poleceń systemowych wprost z obsługi kliknięcia w GUI,
- logika systemowa lub **logika połączeń zdalnych** w kodzie widoku,
- odczyt lub zmiana kontrolek GUI z modułów logiki,
- uzależnianie logiki aplikacyjnej od konkretnego okna lub widgetu,
- **globalny, zmienny „bieżący komputer"** używany niejawnie przez wszystkie moduły.

## Rdzeń `MWP.Core` (FAZA 2)

Wersja `MWP.Core` (`ModuleVersion`, obecnie 0.12.0) jest wersją hosta (D-024). Funkcje publiczne:

| Obszar | Funkcje | Uwagi |
|---|---|---|
| Środowisko | `Get-MwpEnvironment`, `Test-MwpAdmin` | wersja PS i edycja, Windows 11 (kompilacja ≥ 22000), administrator, STA, ścieżka programu; dotyczą procesu hosta (`localhost`) |
| Elewacja | `Request-MwpElevation` | na życzenie, nowy proces tego samego PowerShella przez UAC (D-027) |
| Logowanie | `Write-MwpLog` | plik dzienny JSON Lines, komputer w każdym wpisie, rotacja, muteks, ponawianie przy blokadzie pliku, ukrywanie sekretów (D-026, D-032) |
| Katalog danych | `Get-MwpDataLocation`, `Move-MwpDataDirectory`; wewnętrzne `Get-MwpDataPath`, `Resolve-MwpDataPath`, `Test-MwpDirectoryWritable` | `dataPath` z konfiguracji, domyślnie `<folder aplikacji>\data` (`logs`, `undo`, `modules`); tryb zapasowy `%LOCALAPPDATA%\MyWindowsPower` z ostrzeżeniem; stan i podgląd nowej ścieżki, „Przenieś dane” (D-032, D-038) |
| Konfiguracja | `Get-MwpSetting`, `Set-MwpSetting` | szablon + plik lokalny, zapis atomowy, odporność na uszkodzony plik, migracje `schemaVersion` (D-025; schemat 2 od FAZY 3, D-037) |
| Wynik | `New-MwpResult`, `Format-MwpOperationTarget` | standardowy obiekt wyniku; opis celu z nazwą komputera do potwierdzeń |
| Cofanie | `Save-MwpUndoEntry`, `Get-MwpUndoEntry`, `Invoke-MwpUndo` | rejestr cofnięć w `<katalog danych>\undo\` (D-028, D-032) |
| Punkt przywracania | `New-MwpRestorePoint` | CIM `SystemRestore`; limit częstotliwości i wyłączona ochrona obsłużone (D-029); komputer zdalny przez `-Context` (D-035) |
| Lista ochronna | `Test-MwpProtectedItem`, `Get-MwpProtectedItem` | dane w `MWP.Core\Data\protected-items.json` (D-029) + opcjonalny `protected.local.json` obok `settings.local.json` (poza repozytorium, tylko dodaje; pole `Source` BuiltIn/Local; D-045); kategorie: `Service` (D-045), `PowerPlan` (D-044), `Task` i `TaskRemoval` (D-046), `App` i `AppxPackage` (D-050) |
| Kontrakt modułu | `Get-MwpModuleDefinition`, `Test-MwpModuleDefinition` | odkrywanie bez importu w `src/Modules`, `<katalog danych>\modules` i dawnym `src/Modules/Installed` (pola `Source`, `IsBase`), walidacja wersji i zależności (D-024, D-031, D-037, D-038) |
| Paczki modułów | `Test-MwpModulePackage`, `Install-MwpModulePackage`, `Uninstall-MwpModulePackage`, `Get-MwpInstalledModule`, `Move-MwpInstalledModule` | instalacja i odinstalowanie modułów z paczek `.mwpmod` w katalogu danych, rejestr instalacji, przeniesienie instalacji z FAZY 3, tylko lokalnie; odinstalowanie usuwa też widgety modułu z konfiguracji Dashboardu (D-031, D-037, D-038, D-043) |
| Dashboard | `Get-MwpWidgetDefinition`, `Get-MwpDashboardConfiguration`, `Set-MwpDashboardConfiguration`, `Remove-MwpDashboardWidget`, `Repair-MwpDashboardConfiguration` | katalog widgetów z pola `Widgets` kontraktu, konfiguracja Dashboardu w ustawieniach lokalnych (bez rejestru cofnięć), usuwanie widgetów modułów, których nie ma (D-031, D-043) |

Funkcje wewnętrzne (`Private/`) ukrywają położenie danych i modułów (`Get-MwpDataPath`, `Get-MwpConfigPath`, `Get-MwpModuleRoot` — w testach podmieniane mockami na `TestDrive`), konwersje JSON zgodne z 5.1 i 7.x (`ConvertTo-MwpHashtable`, `ConvertTo-MwpDateTime`), zapis atomowy (`Write-MwpJsonFile`, `Write-MwpLocalSetting`) przeniesienie katalogu (`Move-MwpDirectory`) i kopia między woluminami (`Copy-MwpDirectory`).

**Komputer w API rdzenia (D-019, D-035):** log, wpis cofnięcia, obiekt wyniku i opis celu mają parametr `-ComputerName` (domyślnie `localhost`) — to tylko etykieta komputera w zapisie. Operacje wykonywane na komputerze docelowym przyjmują kontekst wykonania `-Context` (`New-MwpRestorePoint`, `Invoke-MwpUndo`); sama nazwa (`-ComputerName`) w `New-MwpRestorePoint` oznacza wyłącznie komputer lokalny (zgodność wsteczna), a nazwa komputera zdalnego bez kontekstu daje wynik z błędem. Rdzeń nie ma żadnej zmiennej modułu ani globalnej z „bieżącym komputerem" (sprawdza to `tests/Modules/MWP.Core/Architecture.Tests.ps1`). `MWP.Core` korzysta z `MWP.Remote` (instancje, `Invoke-MwpOnTarget`) przez późne wiązanie (`Get-Command`), bez zależności cyklicznej przy imporcie.

## Wzorzec funkcji zmieniającej system (FAZA 2, kontekst od FAZY 3)

Każda funkcja obszaru, która zmienia system, stosuje ten wzorzec; infrastrukturę (log, cofanie, wynik, lista ochronna) daje `MWP.Core`, a komputer docelowy i wykonanie — `MWP.Remote` (kontekst wykonania, `Invoke-MwpOnTarget`). Działające przykłady w repozytorium: `Set-MwpSetting` (ustawienie aplikacji, wszystkie kroki) i `New-MwpRestorePoint -Context` (operacja na komputerze docelowym, lokalnym albo zdalnym).

```powershell
function Set-MwpExampleThing {
    # Klasa operacji: Zmiana → ConfirmImpact 'Medium'; Destrukcyjna → 'High'; Odczyt → bez SupportsShouldProcess.
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Name,
        [Parameter(Mandatory)] [ValidateSet('A', 'B')] [string] $Value,
        [PSTypeName('MWP.ExecutionContext')] [object] $Context = (New-MwpExecutionContext)   # domyślnie localhost
    )

    $ComputerName = $Context.ComputerName
    $common = @{ Operation = 'Example.SetThing'; Target = $Name; ComputerName = $ComputerName }

    # 1. Walidacja i lista ochronna — przed jakąkolwiek zmianą.
    if (Test-MwpProtectedItem -Category 'Example' -Name $Name) {
        return New-MwpResult @common -Success $false -Message "Element '$Name' jest na liście ochronnej."
    }
    # 2. Uprawnienia: sprawdzamy (na komputerze docelowym), nie podnosimy samodzielnie.
    #    Lokalnie: Test-MwpAdmin; zdalnie: blok sprawdzający w Invoke-MwpOnTarget (jak w New-MwpRestorePoint).
    # 3. Stan przed zmianą — odczyt na komputerze docelowym; brak różnicy = brak zmiany.
    #    Blok skryptu jest samowystarczalny (dane przez -ArgumentList) i zgodny z 5.1.
    $read = Invoke-MwpOnTarget -Context $Context -Operation 'Example.GetThing' -ArgumentList $Name -ScriptBlock { param($N) (Get-ExampleThing -Name $N).Value }
    if (-not $read.Success) {
        return New-MwpResult @common -Success $false -Message $read.Message -ErrorMessage $read.ErrorMessage   # np. brak połączenia
    }
    $before = @($read.Data)[0]
    if ($before -eq $Value) {
        return New-MwpResult @common -Success $true -Before $before -After $before -Message 'Bez zmian.'
    }
    # 4. Podgląd (-WhatIf) i potwierdzenie (-Confirm) z nazwą komputera docelowego.
    $target = Format-MwpOperationTarget -Target "element '$Name'" -ComputerName $ComputerName
    if (-not $PSCmdlet.ShouldProcess($target, "Zmiana z '$before' na '$Value'")) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $Value -Message "Podgląd: $Name → $Value."
    }
    # 5. Zmiana na komputerze docelowym, wpis cofnięcia, log (na hoście, z nazwą komputera) i wynik;
    #    oczekiwane błędy jako wynik, nie wyjątek. Kontekstu nie zapisujemy w UndoParameters —
    #    Invoke-MwpUndo dostaje go od wywołującego (-Context) i sprawdza zgodność komputera.
    $change = Invoke-MwpOnTarget -Context $Context -Operation $common.Operation -ArgumentList $Name, $Value `
        -ScriptBlock { param($N, $V) Set-ExampleThing -Name $N -Value $V -ErrorAction Stop }
    if (-not $change.Success) {
        Write-MwpLog -Level Error -Source 'MWP.Example' -Operation $common.Operation -ComputerName $ComputerName -Message $change.Message
        return New-MwpResult @common -Success $false -Before $before -Message "Nie udało się zmienić $Name." -ErrorMessage $change.ErrorMessage
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Example' -Operation $common.Operation -Target $Name -ComputerName $ComputerName `
        -Before $before -After $Value -UndoCommand 'Set-MwpExampleThing' -UndoParameters @{ Name = $Name; Value = $before }
    Write-MwpLog -Level Info -Source 'MWP.Example' -Operation $common.Operation -ComputerName $ComputerName -Message "Zmieniono $Name."
    New-MwpResult @common -Success $true -Changed $true -Before $before -After $Value -UndoId $undo.Id -Message "Zmieniono $Name."
}
```

Zasady wzorca:
- **Wynik zawsze jako `MWP.Result`.** Pola: `Success`, `Changed`, `IsPreview`, `RestartRequired`, `Operation`, `Target`, `ComputerName`, `Message`, `Before`, `After`, `UndoId`, `ErrorMessage`, `Data`, `Timestamp`. W podglądzie `Changed` jest zawsze `$false`. Przewidziane błędy (brak uprawnień, lista ochronna, błąd systemu) zwracamy jako `Success = $false` z komunikatem po polsku; wyjątek tylko dla błędów programisty (zła wartość parametru, zatrzymana przez walidację parametrów).
- **Podgląd przed zmianą:** cały odczyt i walidacja dzieją się przed `ShouldProcess`; w gałęzi podglądu nic nie jest zapisywane (ani system, ani rejestr cofnięć, ani log zmiany).
- **Cofnięcie:** wpis zapisujemy po udanej zmianie; polecenie cofające to funkcja `Verb-MwpNoun` (zwykle ta sama, z wartością sprzed zmiany) i musi zwracać `MWP.Result`. Gdy cofnięcie nie jest możliwe, nie zapisujemy wpisu i piszemy to w komunikacie (oraz w opisie funkcji).
- **Punkt przywracania:** przed grupą ryzykownych zmian (np. tweaki rejestru) wywołujący (GUI lub funkcja grupy) tworzy `New-MwpRestorePoint`, o ile ustawienie `createRestorePointBeforeRiskyChanges` jest włączone; pojedyncza funkcja nie tworzy go sama.
- **Komputer:** funkcja obszaru przyjmuje `-Context` (domyślnie kontekst `localhost`); komputer do logu, wpisu cofnięcia i wyniku pochodzi z `$Context.ComputerName`, nigdy ze zmiennej globalnej. Operacja na komputerze zdalnym wymaga, by moduł deklarował `RemoteTarget` w `Capabilities`; potwierdzenie (`ShouldProcess`) zawiera nazwę komputera (`Format-MwpOperationTarget`).
- **Wykonanie:** odczyt i zmiana przez `Invoke-MwpOnTarget` (lokalnie bezpośrednio, zdalnie przez WinRM); odczyt CIM może użyć `Get-MwpCimSessionParameter -Context` (`Get-CimInstance … @cim`). Długie operacje w GUI — `Start-MwpOperation` (FAZA 4). Operacje nie są ponawiane automatycznie (D-036).
- **Sekrety:** nie trafiają do `-Before`/`-After`/`-UndoParameters` ani do logu (log dodatkowo ukrywa pola o nazwach typu `Password`, `Token`).
- **Testy:** każda funkcja ma testy Pester z mockami poleceń systemowych, w tym test `-WhatIf` (polecenie zmieniające nie zostało wywołane) i test cofnięcia; ścieżkę zdalną testuje się mockami adaptera transportu `MWP.Remote` (`New-MwpPSSession`, `Invoke-MwpSessionCommand`; przykład: `tests/Modules/MWP.Core/RestorePointRemote.Tests.ps1`).

## Host i moduły (FAZA 2–4; okno hosta: D-039)

Host (okno główne) odpowiada za: nawigację (`Pulpit` z Dashboardem, obszary, `Moduły`, `Ustawienia`, `O programie`), wykrywanie, ładowanie i uruchamianie modułów, instalację i odinstalowanie modułów z paczek (D-031), zarządzanie instancjami i ich cyklem życia, konfigurację i logowanie, zarządzanie komputerami docelowymi, umieszczanie widoków modułów (okno główne, osobne okno, Dashboard), zapis konfiguracji Dashboardu, obsługę błędów i statusów połączeń, kontrolę uprawnień i potwierdzeń. Host nie zawiera szczegółowej logiki obszarów.

**Okno hosta (FAZA 4, D-039, D-040):** `Start-MyWindowsPower.ps1` → `src/UI/UI.ps1` → `Start-MwpUi` (moduł `MWP.UI`). Nawigacja: Pulpit (zaślepka Dashboardu, FAZA 5), obszary z katalogu obszarów (`Get-MwpAreaCatalog`; obszar bez modułu — zaślepka z numerem fazy), moduły z paczek spoza katalogu, sekcja „Otwarte instancje”, na dole Moduły, Dziennik operacji (panel logu), Ustawienia, O programie; wyszukiwanie (Ctrl+K). Widok obszaru otwiera instancję przez okno wyboru komputera i trybu (komputery niedostępne dla modułu są wyłączone z powodem). Widok instancji: kontekst wykonania, plakietka stanu połączenia, Połącz/Rozłącz (w tle, poświadczenia z okna UI), diagnostyka (`Test-MwpTarget`), odczyt testowy (`Get-MwpTargetInfo -AsOperation`), notatka w `State` instancji, przeniesienie do osobnego okna i z powrotem, zamknięcie. Pasek stanu: administrator, PowerShell, Windows, katalog danych (tryb zapasowy na czerwono), instancja widoczna w oknie głównym ze stanem połączenia, zadania w tle z postępem i „Anuluj”. Ustawienia: motyw (System/Jasny/Ciemny), komputery docelowe (dodanie, edycja, usunięcie, diagnostyka), katalog danych (podgląd ścieżki, „Przenieś dane”, „Zapisz tylko ścieżkę”). Moduły: tabela modułów, instalacja z `.mwpmod` (sprawdzenie w tle, potwierdzenie z nazwą, wersją, uprawnieniami i SHA-256), odinstalowanie (wpisanie nazwy modułu, zamknięcie instancji), przeniesienie modułów z dawnego katalogu. O programie: wersje, środowisko, katalog danych, zadanie testowe w tle. Zadania w tle: pula runspace'ów GUI z `MWP.Core`/`MWP.Remote`, wyniki odbierane zegarem okna (D-039).

Każdy moduł: ma unikalny identyfikator, nazwę i wersję; udostępnia kontrakt integracyjny (manifest); oddziela widok od logiki; deklaruje obsługiwane tryby prezentacji, wymagane uprawnienia i zależności; waliduje dane wejściowe i zgłasza czytelne błędy; jest testowalny bez hosta.

## Definicja modułu a instancja modułu

**Definicja modułu nie jest jego instancją.** Definicja opisuje funkcjonalność, instancja jest konkretnym uruchomieniem w określonym kontekście. Przykład: moduł `Services` ma jednocześnie dwie instancje, „Usługi — localhost" i „Usługi — komputer zdalny". Obie używają tej samej implementacji, ale mają niezależne konteksty, stan widoku, parametry, status połączenia i cykl życia.

Wymagania:
- jedna definicja, wiele instancji; każda instancja ma własny identyfikator i jawny kontekst wykonania,
- stan instancji nie jest przypadkowo współdzielony; zmiana komputera w jednej instancji nie zmienia kontekstu innych,
- zamknięcie jednej instancji nie zamyka pozostałych i zwalnia jej zasoby (zadania, sesje),
- instancje mogą współdzielić tylko bezpieczne, niemodyfikowalne zasoby o jawnie zdefiniowanych zasadach,
- sesje zdalne i zasoby zależne od uprawnień mają określony zakres i cykl życia.

Implementacja (FAZA 3, D-035, `MWP.Remote`): `New-MwpModuleInstance -ModuleId -ComputerName [-Credential] [-ModuleParameters]` tworzy instancję (`MWP.ModuleInstance`: `Id`, `ModuleId`, `ModuleName`, `ModuleVersion`, `Name`, `Context`, `State`, `Status`, daty) z **własnym** kontekstem wykonania (`InstanceId` = `Id` instancji) i nową tabelą `State`; `Initialize-MwpModuleInstance [-Connect]` importuje moduł (raz na proces) i opcjonalnie łączy; `Close-MwpModuleInstance` anuluje operacje instancji, zamyka jej sesje, czyści stan i usuwa ją z rejestru; `Get-MwpModuleInstance [-Id] [-ModuleId] [-ComputerName]` czyta rejestr instancji procesu. Fabryką jest host — moduł nie dostarcza własnej (kontrakt w wersji 1 bez zmian). Instancja dla komputera zdalnego wymaga `RemoteTarget` w `Capabilities`; moduły bazowe (`Core`, `Remote`) nie tworzą instancji.

## Kontekst wykonania i komputer docelowy (FAZA 3, D-035)

Nie zakładaj, że moduł działa na komputerze lokalnym. Kontekst wykonania (`New-MwpExecutionContext [-ComputerName] [-Credential] [-InstanceId] [-ModuleParameters] [-ConnectTimeoutSeconds] [-OperationTimeoutSeconds] [-ErrorPolicy Stop|Continue] [-NoAutoConnect]`, typ `MWP.ExecutionContext`) zawiera:

| Pole | Znaczenie |
|---|---|
| `Id`, `InstanceId`, `CreatedAt` | identyfikator kontekstu, instancja modułu, do której należy (może być pusty), data |
| `ComputerName`, `DisplayName` | komputer docelowy (`localhost` albo nazwa z rejestru komputerów) |
| `Mode`, `Transport`, `Port`, `UseSsl` | `Local` (bezpośrednio, `Transport = Local`) albo `Remote` (`WinRM`, port 5985/5986) |
| `Identity` | `Authentication` (`Credential` \| `CurrentUser`) i `UserName` — **nigdy hasło** |
| `Connection` | obiekt połączenia `MWP.Connection`: `State` (`Connected`, `Connecting`, `Disconnected`, `Unauthorized`, `Error`), `ErrorKind`, `LastError`, `StateChangedAt`, sesje WinRM/CIM i poświadczenie w pamięci |
| `ModuleParameters` | parametry modułu (słownik tylko do odczytu) |
| `Policy` | `ConnectTimeoutSeconds`, `OperationTimeoutSeconds` (domyślnie z ustawień), `ErrorPolicy` (`Stop` \| `Continue`), `AutoConnect` |

Kontekst jest **niezmienny**: właściwości są zmiennymi tylko do odczytu, przypisanie kończy się błędem; zmiana komputera = nowy kontekst (zwykle nowa instancja). Jedynym zmiennym elementem jest obiekt połączenia, zarządzany wyłącznie przez `MWP.Remote`; stan czyta się jako `$Context.Connection.State`. Komputer zdalny musi być w rejestrze komputerów. Nazwy `localhost`, `.`, `127.0.0.1`, `::1` i nazwa tego komputera dają tryb `Local`.

Rozdzielone są: reprezentacja komputera (rejestr, `MWP.Target`), nawiązywanie i utrzymywanie połączenia (`Connect-`/`Disconnect-MwpTarget`), wykonywanie operacji (`Invoke-MwpOnTarget`, `Start-MwpOperation`), prezentacja stanu w UI (FAZA 4, z `Context.Connection`). Rozdzielone są też uwierzytelnienie, autoryzacja i dostępność (`Test-MwpTarget`: `Reachable`, `Authenticated`, `Authorized`, `IsAdministrator`). Błędy połączenia są obsługiwane na poziomie kontekstu (stan połączenia + `MWP.Result`), nigdy jako błąd całej aplikacji.

## Komputery docelowe i połączenia zdalne (FAZA 3, D-033, D-034, D-036)

**Rejestr komputerów** — klucz `targets` w `config/settings.local.json` (poza repozytorium): `name`, `displayName`, `transport` (`WinRM`), `port`, `useSsl`, `authentication` (`Credential` \| `CurrentUser`), `userName` (podpowiedź, bez hasła). `localhost` jest zawsze obecny i nie jest zapisywany. Szablon ma jeden wpis przykładowy `NAZWA-KOMPUTERA` z `isExample: true`, który jest pomijany.

| Funkcja (`MWP.Remote`) | Klasa | Opis |
|---|---|---|
| `Get-MwpTarget [-Name]` | Odczyt | `localhost` + komputery z rejestru (niepoprawne wpisy pomijane z ostrzeżeniem) |
| `Add-MwpTarget`, `Set-MwpTarget`, `Remove-MwpTarget` | Zmiana | rejestr komputerów przez `Set-MwpSetting` (podgląd, log, cofnięcie); `Set-MwpTarget` zmienia tylko podane pola (D-041); bez zmian w konfiguracji WinRM |
| `New-MwpExecutionContext` | — | kontekst wykonania (wyżej) |
| `Connect-MwpTarget [-Credential]`, `Disconnect-MwpTarget` | — | sesja WinRM kontekstu; stan połączenia; poświadczenie tylko w pamięci, czyszczone przy rozłączeniu i odmowie dostępu |
| `Test-MwpTarget` | Odczyt | diagnoza: sieć (zapytanie WS-Management bez uwierzytelnienia) → uwierzytelnienie (sesja) → autoryzacja (polecenie w sesji, `IsAdministrator`, wersja PowerShella) |
| `Invoke-MwpOnTarget -Context -ScriptBlock [-ArgumentList] [-Operation] [-TimeoutSeconds]` | — | wykonanie lokalnie bezpośrednio albo zdalnie w sesji; `MWP.Result` z wyjściem w `Data` |
| `Get-MwpCimSessionParameter -Context` | Odczyt | `@{}` lokalnie albo `@{ CimSession = … }` (WSMan) do rozwinięcia w poleceniach CIM |
| `Get-MwpTargetInfo -Context [-AsOperation]` | Odczyt | nazwa komputera, system, PowerShell, czas na komputerze docelowym; synchronicznie albo jako operacja w tle (D-041) |
| `Wait-MwpOperation` — wynik błędu | — | od 0.5.0 `Data.ErrorKind` (Unauthorized, Configuration, Timeout, Network, Other; CredentialRequired z `Start-MwpOperation`) — widgety odróżniają utratę połączenia od błędu danych (D-043) |
| `Start-`, `Wait-`, `Stop-MwpOperation` | — | operacje asynchroniczne w puli runspace'ów (limit równoległości, limit czasu, anulowanie) |
| `New-`, `Initialize-`, `Close-`, `Get-MwpModuleInstance` | — | instancje modułów (sekcja „Definicja modułu a instancja modułu") |

Zasady wykonania (D-036):
- **Transport:** WinRM (PowerShell Remoting) dla operacji, CIM po WSMan dla odczytu; tylko kanały wbudowane w Windows, bez agenta. Polecenia WinRM/CIM są wyłącznie w adapterze transportu (prywatne funkcje `New-MwpPSSession`, `Invoke-MwpSessionCommand`, `New-MwpCimSession`, `Test-MwpWsMan`, `Remove-MwpPSSession`, `Remove-MwpCimSession`; wyjątek: wywołanie w runspace w `Start-MwpOperation`) — sprawdza to test architektoniczny. Inny transport dla wybranej funkcji = nowy adapter.
- **Blok skryptu** dla `Invoke-MwpOnTarget` i `Start-MwpOperation` jest samowystarczalny: dane przez `-ArgumentList` (bez `$using:` i zmiennych wywołującego), tylko polecenia wbudowane, zgodność z Windows PowerShell 5.1 (domyślny punkt końcowy WinRM). Lokalnie blok jest wykonywany tak samo (odtworzony z tekstu, bez trybu ścisłego), więc błędy założeń widać już na `localhost`.
- **Izolacja:** każdy kontekst ma własne połączenie (także dwa konteksty dla tego samego komputera). Odmowa dostępu → `Unauthorized`; brak poświadczeń → `Unauthorized` (`CredentialRequired`); niedostępność, limit czasu, konfiguracja klienta (`TrustedHosts`) → `Error`; utrata połączenia w trakcie → `Disconnected` (`ConnectionLost`), a następne wywołanie łączy ponownie. Operacja nie jest ponawiana automatycznie.
- **Współbieżność:** `Start-MwpOperation` używa puli runspace'ów (`remoteMaxParallelOperations`, domyślnie 4; nadmiar czeka w kolejce), każda operacja ma limit czasu (`TimedOut`) i może być anulowana (`Stop-MwpOperation`, `Cancelled`); zasoby są zwalniane po zakończeniu, operacje instancji są anulowane przy jej zamknięciu, a usunięcie modułu zamyka pulę. Zdalnie operacja asynchroniczna otwiera własne, krótkotrwałe połączenie z poświadczeniem kontekstu.
- **Uwierzytelnianie (D-034):** `Credential` — `Get-Credential` na żądanie (okno wyświetla warstwa UI albo użytkownik w CLI; logika nie pyta sama), `PSCredential` tylko w pamięci; `CurrentUser` — konto procesu (Kerberos w domenie). Bez DPAPI, CredSSP i zapisu haseł. Log ukrywa `PSCredential`; hasła nie trafiają do wyniku, rejestru cofnięć ani pliku ustawień.
- **Zmiany zdalne:** wzorzec funkcji zmieniającej system (wyżej) — `-WhatIf`/`-Confirm` z nazwą komputera, log na hoście z nazwą komputera (`<katalog danych>\logs`, D-032; na komputerze zdalnym nic nie zapisujemy), wpis cofnięcia z nazwą komputera, cofnięcie przez `Invoke-MwpUndo -Context`. Punkt przywracania tworzony na komputerze docelowym (`New-MwpRestorePoint -Context`).
- **Znane ograniczenia zdalne** do zbadania w fazach obszarów: profil użytkownika (HKCU) i `winget` w sesji nieinteraktywnej (FAZA 12, D-050: Appx i rejestr działają; winget niedostępny, gdy konto połączenia nie ma zarejestrowanego App Installer — sprawdzone sondą; `WindowsApps` — odmowa dostępu), Windows Update Agent (COM) w sesji zdalnej (FAZA 10, D-048: pobieranie i instalacja niedostępne — instalacja zdalna odroczona; odczyt, pauza i reset działają), zrzuty ekranu i dostęp do pulpitu użytkownika, ryzyko utraty łączności przy zmianie zapory (sieć: FAZA 11, D-049 — zadanie automatycznego wycofania na komputerze docelowym).

### Konfiguracja komputera zdalnego (instrukcja; aplikacja jej nie wykonuje)

Środowisko użytkownika (D-033): Windows 11, grupa robocza, WinRM HTTP 5985, logowanie kontem z `Get-Credential`. Kroki wykonuje użytkownik ręcznie, jako administrator, świadomie:

1. **Komputer zdalny:** `Enable-PSRemoting` (już wykonane: WinRM nasłuchuje na 5985). Profil sieci prywatny, reguła zapory „Zarządzanie zdalne systemu Windows (HTTP-In)" dopuszcza ruch z sieci lokalnej. Konto do logowania: lokalny administrator; dla konta innego niż wbudowany Administrator w grupie roboczej wymagane `LocalAccountTokenFilterPolicy = 1` (ustawia je `Enable-PSRemoting`), inaczej sesja nie ma uprawnień administratora (`Test-MwpTarget` pokaże `IsAdministrator = False`).
2. **Komputer lokalny (grupa robocza, NTLM):** wpis **tylko tej jednej nazwy** w `TrustedHosts` klienta WinRM, np. `Set-Item WSMan:\localhost\Client\TrustedHosts -Value '<NAZWA>' -Concatenate` (wymaga działającej usługi WinRM); nigdy `*`. Alternatywa bez `TrustedHosts`: HTTPS (5986) z certyfikatem na komputerze zdalnym i `Add-MwpTarget -UseSsl`.
3. **Aplikacja:** `Add-MwpTarget -Name '<NAZWA>' -UserName '<NAZWA>\<konto>'`, potem `$c = New-MwpExecutionContext -ComputerName '<NAZWA>' -Credential (Get-Credential)` i `(Test-MwpTarget -Context $c).Data`.

## Tryby prezentacji (Embedded i SeparateWindow — FAZA 4, D-039; DashboardWidget — FAZA 5, D-043; pozostałe: FAZA 19)

Moduł deklaruje, które tryby obsługuje (nie każdy musi wszystkie):

1. **Embedded** — widok w oknie głównym.
2. **SeparateWindow** — widok w osobnym oknie.
3. **DashboardWidget** — uproszczony widok danych na Dashboardzie.
4. **Standalone** — samodzielne uruchomienie bez hosta.
5. **CLI** — uruchomienie z linii poleceń.

Moduł z pustą listą trybów (moduły obszarów przed swoją fazą) dostaje w hoście widok-zaślepkę w trybach Embedded i SeparateWindow; moduł z listą — tylko w zadeklarowanych trybach (`Test-MwpPresentationMode`). Miejsce prezentacji nie określa logiki modułu. Widoki mogą się różnić, ale używają wspólnych usług aplikacyjnych. Tryb samodzielny nie omija zabezpieczeń, walidacji ani kontroli uprawnień.

## Dashboard i widgety (FAZA 5, D-043)

Dashboard to konfigurowalna przestrzeń robocza z wieloma widokami modułów dla różnych komputerów jednocześnie (np. status usług na jednym komputerze, dyski na drugim, informacje o systemie lokalnym, status RDP). Dashboard jest kompozycją niezależnych widgetów, a nie zbiorem specjalnie napisanych ekranów.

Na Pulpicie widgety są na górze, pod nimi karty komputerów i otwarte instancje (FAZA 4).

- **Kontrakt widgetu** — opcjonalne pole `Widgets` kontraktu modułu (sekcja „Kontrakt modułu”). Widget to kontrakt prezentacji danych, nie miniaturowe okno: funkcja danych (`-Context -AsOperation -WidgetParameters` → `MWP.Operation`; ta sama usługa aplikacyjna co pełny widok i CLI), funkcja widoku (`-Data -WidgetParameters` → `MWP.WidgetView`: `Summary`, `Sections` z wierszami `Label`/`Value`/`Percent`/`Tone`, `Warnings`; czysta, bez WPF) i opcjonalnie funkcja eksportu (`-Data -Path [-Format Json|Text]` → `MWP.Result`). Host renderuje widok ogólnym szablonem kafelka (`Views/Dashboard.xaml`), więc moduł z paczki dostarcza widget bez kodu WPF. Katalog: `Get-MwpWidgetDefinition`.
- **Widget w oknie** (`src/UI/Functions`, testowalne bez WPF): wpis konfiguracji + definicja + **własna instancja modułu** (`New-MwpWidgetRuntime`; własny kontekst i połączenie, także dla tego samego komputera). Stany (`Get-MwpWidgetStatus`, `Get-MwpWidgetStateInfo`): Oczekuje, Ładowanie, Aktualne, Brak danych, Błąd, Utrata połączenia, Wymaga poświadczeń (z `Data.ErrorKind` wyniku operacji). Przy błędzie widget zachowuje ostatni widok z komunikatem.
- **Odświeżanie:** w tle (`Start-MwpWidgetRefresh` → funkcja danych → `Register-MwpUiOperation`; wynik w wątku okna `Complete-MwpWidgetRefresh`), ręczne (przycisk widgetu, „Odśwież wszystkie”) i automatyczne (częstotliwość per widget: ręcznie, 30 s, 1, 5, 15 min; tylko przy widocznym Pulpicie i włączonym przełączniku „Odświeżanie automatyczne”). Harmonogram `Get-MwpWidgetDue` w zegarze okna (`Invoke-MwpUiDashboardTick`) z limitem `dashboardMaxParallelRefresh` (domyślnie 2); operacje na komputerach dodatkowo ogranicza pula `remoteMaxParallelOperations`. Odświeżanie automatyczne nie otwiera okna poświadczeń — widget komputera zdalnego bez poświadczeń ma przycisk „Połącz” (`Connect-MwpUiWidget`).
- **Izolacja:** wyjątek funkcji danych lub widoku, błąd albo utrata połączenia zmienia stan tylko tego widgetu; usunięcie widgetu anuluje jego zadanie i zamyka jego instancję (`Remove-MwpWidgetRuntime`); zmiana komputera w widgecie = nowa instancja (kontekst jest niezmienny).
- **Konfiguracja** — klucze `dashboardWidgets` (lista w kolejności wyświetlania: `id`, `moduleId`, `widgetId`, `computerName`, `title`, `refreshSeconds`, `size` Normal/Wide, `parameters`), `dashboardAutoRefresh`, `dashboardMaxParallelRefresh` w `config/settings.local.json`; bez wpisu lokalnego obowiązuje szablon (widget „Informacje o systemie” dla localhost). Zapis po każdej zmianie (`Set-MwpDashboardConfiguration`: zapis atomowy, log, bez rejestru cofnięć). Rozmiar = szerokość kafelka, położenie = kolejność (przesuwanie wcześniej/dalej). Odtworzenie przy otwarciu Pulpitu: `Repair-MwpDashboardConfiguration` pomija i usuwa z zapisu widgety modułów, których nie ma (D-031), z ostrzeżeniem na Pulpicie i w logu.
- **Odinstalowanie modułu (D-031):** okno usuwa widgety modułu z Dashboardu (anulowanie zadań, zamknięcie instancji), `Uninstall-MwpModulePackage` usuwa je z zapisu w tym samym zapisie atomowym co rejestr modułów.
- **Pierwszy widget:** „Informacje o systemie” (`MWP.Dashboard`): `Get-MwpSystemInfo` czyta CIM i rejestr na komputerze docelowym blokiem zgodnym z 5.1, który zwraca JSON (serializacja WinRM spłaszcza obiekty głębsze niż 2 poziomy); sekcje System, Cpu, Memory, Gpu, Disks, Board, Battery, Network (parametr widgetu `Sections`); błąd sekcji → `Warnings`, brak danych → `$null`/pusta lista. Eksport raportu: `Export-MwpSystemReport` (JSON bez BOM, tekst z BOM).

## Zasilanie — moduł MWP.Power (FAZA 6, D-044)

Pierwszy moduł obszaru, który zmienia system. Wszystkie funkcje przyjmują `-Context` (domyślnie `localhost`); `powercfg` i rejestr są wywoływane na komputerze docelowym przez `Invoke-MwpOnTarget` / `Start-MwpOperation`, log i rejestr cofnięć zostają na hoście z nazwą komputera.

| Funkcja | Klasa | Opis |
|---|---|---|
| `Get-MwpPowerStatus [-AsOperation]`, `Resolve-MwpPowerStatus` | Odczyt | plany, plan aktywny, 6 ustawień AC/DC planu aktywnego (ekran, uśpienie, hibernacja po, pokrywa, przyciski zasilania i uśpienia), hibernacja, szybkie uruchamianie, bateria, administrator; jedno wywołanie na komputerze docelowym; `-AsOperation` daje surowy JSON parsowany przez `Resolve-MwpPowerStatus` |
| `Get-MwpPowerPlan [-Guid]` | Odczyt | lista planów (GUID, nazwa w języku systemu, aktywny, wbudowany) |
| `Set-MwpActivePowerPlan`, `Copy-MwpPowerPlan`, `Add-MwpUltimatePowerPlan`, `Rename-MwpPowerPlan`, `Import-MwpPowerPlan` | Zmiana | `/setactive`, `/duplicatescheme` (+`/changename`), szablon `e9a42b02-…` „Najwyższa wydajność”, `/changename`, `/import` (Base64 albo plik .pow) |
| `Remove-MwpPowerPlan` | Destrukcyjna | odmowa dla planu aktywnego i planów wbudowanych (lista ochronna `PowerPlan`), eksport przed usunięciem = dane cofnięcia |
| `Set-MwpPowerSetting -Setting -PowerSource AC\|DC -Value [-PlanGuid]` | Zmiana | `/setacvalueindex`/`/setdcvalueindex` po GUID-ach, `/setactive` dla planu aktywnego; czasy w sekundach (0 = nigdy), akcje 0–4 |
| `Set-MwpHibernation`, `Set-MwpFastStartup` | Zmiana | `/hibernate on/off`, `HiberbootEnabled`; wymagają administratora na komputerze docelowym |
| `New-MwpPowerReport -Kind Battery\|Energy [-DurationSeconds] [-AsOperation]`, `Save-MwpPowerReport`, `Open-MwpPowerReport`, `Get-MwpPowerReportDirectory` | Odczyt / zapis pliku | raport powstaje na komputerze docelowym w katalogu tymczasowym, treść wraca połączeniem, zapis w `<katalog danych>\reports` (albo wskazanym folderze), otwarcie lokalnie |
| `ConvertTo-MwpPowerStatusView` | — | widok widgetu `PowerStatus` (D-043) |

Zasady (D-044): bloki komputera docelowego (`Get-MwpPowerScript`) nie interpretują tekstu `powercfg` — zwracają linie i kod wyjścia; parsowanie na hoście po GUID-ach i strukturze (`ConvertFrom-MwpPowercfgOutput`), więc działa przy polskim i angielskim języku systemu; argumenty `powercfg` zawsze jako osobne elementy tablicy; odczyt ustawień przez `/qh` (ustawienia ukryte). Testy: `tests/Modules/MWP.Power/Power.Tests.ps1` — symulator `powercfg.exe` (Pester `Mock` w `MWP.Remote`, `MWP.Power` i zakresie pliku) z komunikatami po polsku i angielsku; ścieżka zdalna przez mock adaptera transportu.

**Widok modułu wbudowanego (D-044):** XAML widoków modułów wbudowanych należy do hosta (`src/UI/Views/<Moduł>.xaml`); katalog `Get-MwpModuleViewCatalog` mapuje Id modułu na plik i funkcje `Initialize-`/`Update-` (`MWP.UI`). Widok instancji (`Instance.xaml`) wstawia go w `ModuleHost` zamiast zaślepki i odczytu testowego; nagłówek (stan połączenia, Połącz/Rozłącz, diagnostyka, osobne okno, zamknięcie) i kontekst zostają. Zmiany z widoku modułu: `Invoke-MwpUiInstanceChange` (kroki = funkcje logiki; podgląd `-WhatIf` w puli zadań GUI → okno potwierdzenia z komputerem docelowym → wykonanie w tle → `-AfterCommand`). Moduły z paczek nadal dostają widok ogólny.

## Usługi — moduł MWP.Services (FAZA 7, D-045)

Wszystkie funkcje przyjmują `-Context` (domyślnie `localhost`); odczyt i zmiany wykonują bloki na komputerze docelowym (`Get-MwpServiceScript`: `List`, `Control`, `StartupType`; zgodne z 5.1, wynik JSON), log i rejestr cofnięć zostają na hoście z nazwą komputera. Nazwy usług są walidowane przed użyciem (`Test-MwpServiceName`).

| Funkcja | Klasa | Opis |
|---|---|---|
| `Get-MwpService [-Name] [-Status] [-StartupType] [-Search] [-ProtectedOnly] [-IncludeDependencies] [-AsOperation]`, `Resolve-MwpServiceList`, `Select-MwpService` | Odczyt | `Win32_Service` (+ `Win32_DependentService`), typ uruchomienia z opóźnionym startem, konto, ścieżka, opis, zależności, oznaczenie listy ochronnej; filtry jako czysta funkcja (CLI i widok) |
| `Start-MwpService [-DependentService]`, `Stop-MwpService`, `Restart-MwpService` | Zmiana | `ServiceController` z limitem 30 s na usługę; zatrzymanie i restart z działającymi usługami zależnymi (od najdalszej), po błędzie ponowne uruchomienie zatrzymanych; cofnięcie zatrzymania = start z tymi samymi zależnymi; restart bez wpisu cofnięcia |
| `Set-MwpServiceStartupType -StartupType Automatic\|AutomaticDelayedStart\|Manual\|Disabled` | Zmiana | `sc.exe config … start=` (argumenty jako tablica) i ponowny odczyt typu; cofnięcie = poprzedni typ |
| `Export-MwpServiceProfile`, `Read-MwpServiceProfile`, `Compare-MwpServiceProfile`, `Import-MwpServiceProfile` | Zapis pliku / Odczyt / Zmiana | profil JSON (typ i stan usług); różnice Change/Same/Missing/Protected/Blocked; import zmienia tylko typy uruchomienia (każda zmiana z własnym wpisem cofnięcia) |
| `ConvertTo-MwpServiceStatusView`, `Get-MwpServiceStartupTypeList`, `Test-MwpServiceName` | — | widok widgetu `ServiceStatus` (D-043); słownik typów uruchomienia (`AllowedWhenProtected`); walidacja nazwy usługi |

Lista ochronna usług (D-045): usługa chroniona — dozwolone uruchomienie i typ automatyczny; zablokowane zatrzymanie, restart, typ ręczny i wyłączony; zablokowane także zatrzymanie usługi, od której zależy działająca usługa chroniona, i wyłączenie usługi, od której zależy usługa chroniona. Wszystkie zmiany wymagają administratora na komputerze docelowym. Widok `Views/Services.xaml` (katalog widoków hosta, D-044) wyłącza przyciski i zawęża listę typów dla usług chronionych (`Get-MwpServiceActionState`, `Get-MwpServiceViewOption`), ale blokadę egzekwują funkcje logiki (GUI, CLI, komputer zdalny). Testy: `tests/Modules/MWP.Services/Services.Tests.ps1` — symulator usług (mocki `Get-CimInstance`, `Get-Service` z kontrolerem i `sc.exe` w `MWP.Remote`, `MWP.Services` i zakresie pliku; fikcyjne nazwy `MwpTest*`), ścieżka zdalna przez mock adaptera transportu; `tests/UI/ServicesView.Tests.ps1`.

## Autostart i harmonogram — moduł MWP.Startup (FAZA 8, D-046)

Wszystkie funkcje przyjmują `-Context` (domyślnie `localhost`); odczyt i zmiany wykonują bloki na komputerze docelowym (`Get-MwpStartupScript`: `ItemList`, `ItemState`, `TaskList`, `TaskControl`; zgodne z 5.1, wynik JSON), log, rejestr cofnięć i eksport XML zadań zostają na hoście z nazwą komputera.

| Funkcja | Klasa | Opis |
|---|---|---|
| `Get-MwpStartupItem [-Scope] [-State] [-Risk] [-Search] [-NoSignature] [-AsOperation]`, `Resolve-MwpStartupItemList`, `Select-MwpStartupItem` | Odczyt | Run/RunOnce (HKLM z `WOW6432Node`, użytkownik), foldery Startup (wspólny, użytkownika; cel skrótów), stan `StartupApproved` z datą wyłączenia, plik, podpis i wydawca; pozycje użytkowników: lokalnie HKCU, zdalnie profile zalogowanych (`HKEY_USERS\<SID>`) |
| `Set-MwpStartupItemState -Id -Enabled` | Zmiana | wartość `StartupApproved` jak Menedżer zadań (02… / 03 + FILETIME), wpis i plik zostają; RunOnce — odmowa; komputer i inni użytkownicy — administrator; cofnięcie = poprzedni stan |
| `Get-MwpScheduledTask [-State] [-HideMicrosoft] [-ProtectedOnly] [-Search] [-NoSignature] [-AsOperation]`, `Resolve-MwpScheduledTaskList`, `Select-MwpScheduledTask` | Odczyt | `Get-ScheduledTask` + `Get-ScheduledTaskInfo`: stan, akcje, wyzwalacze, konto, ostatnie/następne uruchomienie i wynik, podpis (poza `\Microsoft\`), lista ochronna (`Task`, `TaskRemoval`) |
| `Set-MwpScheduledTaskState -Enabled`, `Start-MwpScheduledTask` | Zmiana | włącz/wyłącz z ponownym odczytem (cofnięcie = poprzedni stan); uruchomienie teraz bez wpisu cofnięcia |
| `Remove-MwpScheduledTask [-ExportDirectory]`, `Restore-MwpScheduledTask -XmlPath` | Destrukcyjna / Zmiana | eksport XML do `<katalog danych>\exports\tasks` przed `Unregister-ScheduledTask`; cofnięcie = odtworzenie z XML (bez zadań z zapisanym hasłem) |
| `Get-MwpSignatureRisk`, `Test-MwpScheduledTaskName` | — | ocena podpisu (Signed, Unsigned, Invalid, Missing, NotChecked, NotApplicable, Unknown) i wydawca z tematu certyfikatu; walidacja folderu i nazwy zadania |

Wszystkie zmiany zadań wymagają administratora na komputerze docelowym. Lista ochronna (D-046): `Task` — zadania krytyczne (nie wyłączać, nie usuwać), `TaskRemoval` — `\Microsoft\*` (nie usuwać). Widok `Views/Startup.xaml` (zakładki Autostart i Harmonogram, katalog widoków hosta, D-044) blokuje przyciski jak logika (`Get-MwpStartupActionState`), ale reguły egzekwują funkcje logiki (GUI, CLI, komputer zdalny). Testy: `tests/Modules/MWP.Startup/Startup.Tests.ps1` — symulator rejestru, folderów, skrótów, podpisów, zalogowanych użytkowników i harmonogramu (mocki w `MWP.Remote` i `MWP.Startup`, filtry obejmują wszystkie ścieżki `Registry::`; w Pester 6 domyślne mocki przekazują pozostałe wywołania do oryginałów przez nazwę z modułem i `$PesterBoundParameters`), ścieżka zdalna przez mock adaptera transportu; `tests/UI/StartupView.Tests.ps1`.

## Czyszczenie dysku — moduł MWP.Cleanup (FAZA 9, D-047)

Jedyny obszar z trwałym usuwaniem plików: bezpieczeństwo ma pierwszeństwo przed funkcjonalnością. Wszystkie funkcje przyjmują `-Context` (domyślnie `localhost`); skan i usuwanie wykonuje blok `Process` na komputerze docelowym (`Get-MwpCleanupScript`: `Environment`, `Process`, `ComponentStore`; zgodne z 5.1, wynik JSON), log zostaje na hoście z nazwą komputera.

| Funkcja | Klasa | Opis |
|---|---|---|
| `Get-MwpCleanupCategory [-Id] [-IncludeInvalid]` | Odczyt | definicje kategorii z `Data\cleanup-categories.json` po walidacji (biała lista ścieżek z tokenami `{SystemRoot}`, `{ProgramData}`, `{UserProfile}`, `{RecycleBin}`) |
| `Measure-MwpCleanupCategory [-Category] [-IncludeUserProfiles] [-Progress]` | Odczyt | skan: liczba plików, rozmiar i pominięcia z powodem na kategorię (`MWP.CleanupScan`), lokalizacje niedostępne z powodem (administrator, profile niewybrane, odrzucone) |
| `Clear-MwpCleanupCategory -Category [-IncludeUserProfiles] [-Progress]` | Destrukcyjna | `ConfirmImpact High`; skan → `ShouldProcess` z liczbą plików, rozmiarem i komputerem → usuwanie tym samym blokiem zasad; wynik na kategorię (`MWP.CleanupCategoryResult`), log początku i wyniku, bez wpisu cofnięcia |
| `ConvertTo-MwpCleanupReport`, `Format-MwpCleanupSize` | — | raport po czyszczeniu (zwolniono, pominięto według powodu, kategorie, tekst); rozmiar po polsku |
| `Get-MwpComponentStoreAnalysis [-AsOperation] [-TimeoutSeconds]`, `Resolve-MwpComponentStoreAnalysis` | Odczyt | `DISM /Online /Cleanup-Image /AnalyzeComponentStore /English` (administrator), parsowanie rozmiarów, daty ostatniego czyszczenia, pakietów do odzyskania i zalecenia; czyszczenia magazynu aplikacja nie wykonuje |

Zasady (D-047): trzy linie obrony — walidacja definicji (biała lista), `Test-MwpCleanupRoot` na hoście po rozwinięciu tokenów (pełna kanoniczna ścieżka wewnątrz dozwolonej bazy, poza lokalizacjami chronionymi) i kontrola w bloku (`ReparsePoint` katalogu głównego i przodków, każdy wpis wewnątrz katalogu głównego, dowiązania pomijane bez wchodzenia, katalogi chronione pomijane, pliki usuwane pojedynczo, puste katalogi bez rekurencji, pliki w użyciu pomijane). Lokalizacje chronione: pulpit, dokumenty, pobrane, obrazy, muzyka, wideo, ulubione i OneDrive każdego profilu oraz foldery znane bieżącego konta. Profile: lokalnie domyślnie bieżące konto, zdalnie domyślnie żadne (tylko lokalizacje systemowe), `-IncludeUserProfiles` — wszystkie profile; lokalizacje systemowe i cudze profile wymagają administratora na komputerze docelowym. `-Progress` (tabela Percent/Message/CancelRequested) daje postęp i anulowanie bez zależności od GUI (lokalnie także w trakcie kategorii). Widok `Views/Cleanup.xaml` (katalog widoków hosta, D-044): skan w tle z postępem i anulowaniem, wielokrotne zaznaczenie, okno potwierdzenia destrukcyjnego z listą kategorii i rozmiarem oraz wpisaniem nazwy komputera, raport, analiza DISM (`Get-MwpCleanupActionState`, `Get-MwpCleanupRow`, `Get-MwpCleanupDetail`, `Get-MwpUiCleanupScript`). Testy: `tests/Modules/MWP.Cleanup/Cleanup.Tests.ps1` — wyłącznie katalogi w `TestDrive` (fikcyjny „komputer” z profilami, Koszem, junction do katalogu spoza kategorii; dane komputera docelowego z mocka `Get-MwpCleanupEnvironment`), kryterium „żadna operacja nie wychodzi poza zdefiniowane ścieżki”, ścieżka zdalna przez mock adaptera transportu, DISM bez uruchamiania (mock); `tests/UI/CleanupView.Tests.ps1`.

## Windows Update — moduł MWP.Update (FAZA 10, D-048)

Wszystkie funkcje przyjmują `-Context` (domyślnie `localhost`); odczyt i zmiany wykonują bloki na komputerze docelowym (`Get-MwpUpdateScript`: `Status`, `Search`, `History`, `PauseWrite`, `Install`, `Reset`; zgodne z 5.1, wynik JSON) przez Windows Update Agent (COM `Microsoft.Update.*`), rejestr i `ServiceController`; log i rejestr cofnięć zostają na hoście z nazwą komputera. Klucze, usługi i foldery są stałe (`Get-MwpUpdateTargetConfig`).

| Funkcja | Klasa | Opis |
|---|---|---|
| `Get-MwpUpdateStatus [-AsOperation]`, `Resolve-MwpUpdateStatus` | Odczyt | usługi `wuauserv`, `bits`, `cryptsvc`, `usosvc`; wymagany restart (`Microsoft.Update.SystemInfo`, klucze `RebootRequired`/`RebootPending`); ostatnie wyszukiwanie i instalacja (`Microsoft.Update.AutoUpdate`); pauza (`MWP.UpdatePause`), zasady grupy (ostrzeżenie), kopie z resetu, administrator |
| `Find-MwpUpdate [-Type All\|Software\|Driver] [-AsOperation] [-TimeoutSeconds]`, `Resolve-MwpUpdateSearch` | Odczyt | `IUpdateSearcher.Search` ze stałymi kryteriami (oczekujące, nieukryte): tytuł, KB, kategorie, rodzaj, ważność, rozmiar, pobrana, restart, `IsInstallable` z powodem; błąd z HRESULT i opisem |
| `Get-MwpUpdateHistory [-First] [-AsOperation]`, `Resolve-MwpUpdateHistory` | Odczyt | `QueryHistory`: data lokalna, operacja, wynik, HRESULT z opisem, KB z tytułu, od najnowszego |
| `Suspend-MwpUpdate -Weeks 1–5`, `Resume-MwpUpdate`, `Restore-MwpUpdatePause -StateJson` | Zmiana | wartości pauzy jak przycisk w Ustawieniach (`HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings`, REG_SZ ISO 8601 UTC); administrator; ponowny odczyt; cofnięcie = wartości sprzed zmiany |
| `Reset-MwpUpdateComponent`, `Get-MwpUpdateResetStep`, `Restore-MwpUpdateComponent -Suffix` | Destrukcyjna / Zmiana | zatrzymanie usług → zmiana nazw `SoftwareDistribution` i `System32\catroot2` na `*.mwp-RRRRMMDD-GGmmss` (zostają) → uruchomienie usług, które działały; podgląd kroków; wycofanie przy błędzie; cofnięcie przywraca kopie (bieżące → `*.mwp-replaced-*`) |
| `Install-MwpUpdate -UpdateId\|-Update [-Progress]` | Destrukcyjna | tylko lokalnie i jako administrator: ponowne wyszukanie, pobranie i instalacja po jednej aktualizacji (postęp, anulowanie między aktualizacjami), pomijanie wymagających interakcji i licencji, bez restartu (`RestartRequired`), bez wpisu cofnięcia |
| `Open-MwpUpdatePage`, `Format-MwpUpdateSize` | — | otwarcie `ms-settings:windowsupdate` (lokalnie); rozmiar po polsku |

Zasady (D-048): komputer zdalny — stan, wyszukiwanie, historia, pauza i reset przez WinRM; instalacja zdalna odroczona (WUA odmawia `IUpdateDownloader`/`IUpdateInstaller` w sesji zdalnej). Widok `Views/Update.xaml` (katalog widoków hosta, D-044): stan i usługi, wyszukiwanie w tle (pasek stanu), instalacja zaznaczonych z oknem potwierdzenia, postępem i „Anuluj”, pauza 1–5 tygodni, reset z podglądem kroków i wpisaniem nazwy komputera, historia z filtrem niepowodzeń, cofnięcia (`Get-MwpUpdateRow`, `Get-MwpUpdateActionState`, `Get-MwpUpdateDetail`, `Get-MwpUpdateViewOption`, `Get-MwpUiUpdateScript`). Testy: `tests/Modules/MWP.Update/Update.Tests.ps1` — symulator Windows Update Agent (mock `New-Object -ComObject` w `MWP.Remote` i `MWP.Update`; domyślny mock przekazujący inne wywołania `New-Object` tylko w zakresach modułów — w zakresie pliku daje rekurencję), usługi przez mock `Get-Service`/`Get-CimInstance`, rejestr w `TestRegistry`, foldery w `TestDrive` (mock `Get-MwpUpdateTargetConfig`), ścieżka zdalna przez mock adaptera transportu; `tests/UI/UpdateView.Tests.ps1`.

## Sieć — moduł MWP.Network (FAZA 11, D-049)

Wszystkie funkcje przyjmują `-Context` (domyślnie `localhost`); odczyt i zmiany wykonują bloki na komputerze docelowym (`Get-MwpNetworkScript`: `Status`, `Change`, `Approve`, `FlushDns`, `RenewDhcp`, `ResetStack`, `Test`; zgodne z 5.1, wynik JSON), log i rejestr cofnięć zostają na hoście z nazwą komputera. Stałe (folder i prefiks zadań wycofania, ścieżka `netsh`, limity) — `Get-MwpNetworkTargetConfig`.

| Funkcja | Klasa | Opis |
|---|---|---|
| `Get-MwpNetworkStatus [-AsOperation]`, `Resolve-MwpNetworkStatus` | Odczyt | adaptery (także wyłączone), IPv4/IPv6, bramy, DNS w użyciu i statyczne (rejestr `Tcpip`/`Tcpip6`), DHCP z dzierżawą, profil sieci, adapter połączenia zdalnego (TCP na porcie WinRM), zmiany czekające na zatwierdzenie, administrator |
| `Get-MwpDnsPreset` | — | DHCP, Cloudflare, Google, Quad9 (IPv4 i IPv6) |
| `Set-MwpDnsServer -InterfaceIndex [-InterfaceGuid] -Preset\|-ServerAddress [-RollbackSeconds]` | Zmiana | reset do DHCP, potem lista statyczna; zadanie wycofania; cofnięcie = tryb sprzed zmiany |
| `Disable-MwpNetAdapter [-AllowConnectionAdapter] [-RollbackSeconds]`, `Enable-MwpNetAdapter` | Zmiana (`ConfirmImpact High` dla wyłączenia) | adapter połączenia tylko z `-AllowConnectionAdapter`; zadanie wycofania włącza adapter |
| `Approve-MwpNetworkChange -ChangeId` | Zmiana | zatwierdzenie = usunięcie zadania wycofania (przez działające połączenie) |
| `Clear-MwpDnsCache`, `Update-MwpDhcpLease` | Zmiana bez cofnięcia | `Clear-DnsClientCache`; `Win32_NetworkAdapterConfiguration.RenewDHCPLease` (bez zwalniania adresu) |
| `Reset-MwpNetworkStack -Component Winsock\|IP` | Destrukcyjna | `netsh winsock reset` / `netsh int ip reset` ze stałymi argumentami, `RestartRequired`, bez cofnięcia; także zdalnie |
| `Test-MwpNetworkConnection [-ExternalHost] [-DnsName] [-PortHost -Port] [-AsOperation]`, `Resolve-MwpNetworkTest` | Odczyt | z komputera docelowego: ping bramy i hosta (.NET `Ping`), `Resolve-DnsName -DnsOnly`, port TCP (`TcpClient` z limitem) |

**Automatyczne wycofanie (D-049):** zmiana DNS i wyłączenie adaptera (lokalnie i zdalnie, domyślnie 120 s) najpierw rejestrują na komputerze docelowym jednorazowe zadanie `\MyWindowsPower\MWP-NetworkRollback-<ChangeId>` (SYSTEM, `powershell.exe -EncodedCommand` ze stałym blokiem `Get-MwpNetworkRollbackScript` i stanem sprzed zmiany w Base64 — bez plików). Bez `Approve-MwpNetworkChange` w limicie zadanie przywraca stan i usuwa się samo, także po utracie połączenia; błąd zmiany uruchamia ten sam blok od razu. Na adapterze z niezatwierdzoną zmianą kolejna zmiana jest odrzucana. Widok `Views/Network.xaml` (katalog widoków hosta, D-044): baner zmian oczekujących z odliczaniem (zegar okna, czas od odczytu na hoście) i „Zatwierdź”, adaptery ze szczegółami, włącz/wyłącz (adapter połączenia — wpisanie nazwy komputera), DHCP, DNS z presetami i czasem na zatwierdzenie, flush DNS, testy łączności, resety z wpisaniem nazwy komputera, cofnięcia (`Get-MwpNetworkRow`, `Get-MwpNetworkActionState`, `Get-MwpNetworkDetail`, `Get-MwpNetworkViewOption`). Testy: `tests/Modules/MWP.Network/Network.Tests.ps1` — symulator sieci, rejestru i harmonogramu (mocki w `MWP.Remote`; parametry `CimInstance` przez `-RemoveParameterType`), blok wycofania wykonywany z argumentów zarejestrowanego zadania, atrapa `netsh` w `TestDrive`, ping 127.0.0.1 i lokalny `TcpListener`, ścieżka zdalna przez mock adaptera transportu (także zerwanie połączenia w trakcie wyłączenia adaptera); `tests/UI/NetworkView.Tests.ps1`.

## Aplikacje — moduł MWP.Apps (FAZA 12, D-050)

Wszystkie funkcje przyjmują `-Context` (domyślnie `localhost`); bloki na komputerze docelowym (`Get-MwpAppsScript`: `Inventory`, `Winget`, `RemoveAppx`; zgodne z 5.1, wynik JSON), log i rejestr cofnięć zostają na hoście z nazwą komputera. Stałe (źródło `winget`, limity czasu, wzorce środowisk uruchomieniowych; w testach ścieżka atrapy winget) — `Get-MwpAppsTargetConfig`.

| Funkcja | Klasa | Opis |
|---|---|---|
| `Get-MwpInstalledApp [-UserSid] [-NoCurrentUser] [-NoAppx] [-AsOperation]`, `Resolve-MwpInstalledApp`, `Select-MwpInstalledApp` | Odczyt | klucze Uninstall (HKLM 64/32 bit przez .NET `RegistryKey`, użytkownik: lokalnie HKCU, zdalnie tylko wskazane załadowane profile `HKEY_USERS\<SID>`), pakiety Appx konta sesji z nazwą z menu Start (`Get-StartApps`); identyfikator, Id lokalne winget (`ARP\<Machine|User>\<X64|X86>\<klucz>`, `MSIX\<pakiet>`), składnik systemowy, ochrona, ostrzeżenie; filtry i sortowanie jako czysta funkcja (CLI i widok) |
| `Get-MwpWingetInfo`, `Get-MwpWingetPackage [-UpgradeAvailable] [-Id] [-AsOperation]`, `Find-MwpWingetPackage -Query [-Count] [-AsOperation]`, `Resolve-MwpWingetPackage`, `ConvertFrom-MwpWingetOutput`, `Join-MwpAppWinget` | Odczyt | `winget --version`, `winget list --source winget [--upgrade-available]`, `winget search --source winget`; zawsze `--disable-interactivity`, bez akceptacji umów; tabela czytana po strukturze; łączenie z inwentarzem po nazwie i wersji (identyfikator źródła, dostępna wersja) |
| `Install-MwpWingetPackage -Id [-Version]` | Zmiana | wyszukanie dokładne, „bez zmian”, gdy zainstalowany; po potwierdzeniu `winget install --exact --source winget --silent --accept-package-agreements --accept-source-agreements`; ponowny odczyt; cofnięcie = `Uninstall-MwpApp -WingetId`; polecenie cofające odinstalowanie |
| `Update-MwpWingetPackage -Id` | Zmiana | tylko z dostępną aktualizacją; `winget upgrade` jak wyżej; ponowny odczyt wersji; bez wpisu cofnięcia (wersja sprzed zmiany w logu i wyniku) |
| `Uninstall-MwpApp -AppId \| -WingetId` | Destrukcyjna | `ConfirmImpact High`; lista ochronna i składniki systemu przed podglądem; program z rejestru — `winget uninstall --id <Id lokalne> --exact --silent`, Appx — `Remove-AppxPackage` (konto sesji); log przed i po (nazwa, wersja, wydawca, identyfikatory); sprawdzenie ponownym odczytem; cofnięcie tylko z identyfikatorem w repozytorium winget (`Install-MwpWingetPackage`) |

Zasady (D-050): **winget bez trybu maszynowego** — blok `Winget` uruchamia `winget.exe` (`ProcessStartInfo`, argumenty sprawdzone na hoście i przekazywane osobno, ze spacją w cudzysłowie, bez cudzysłowów w wartościach; limit czasu z zabiciem procesu) i dekoduje wyjście stroną kodową OEM komputera docelowego (`HKLM\…\Nls\CodePage\OEMCP` — winget przy przekierowanym wyjściu pisze w OEM, nie w UTF-8); host czyta tabelę `ConvertFrom-MwpWingetOutput`: linia kresek = tabela, początki słów nagłówka = kolumny w komórkach ekranu (znaki szerokie liczone podwójnie), słowo nagłówka „przecięte” przez wiersz nie jest kolumną, a gdy nic go nie przecina — wygrywa podział z największą liczbą poprawnych wierszy (Id bez spacji, wersja); znaczenie kolumn z kolejności przy stałych przełącznikach (`--source winget`); linie poza tabelą (zgody źródła, postęp z `\r`, stopki) pomijane. Kody HRESULT `0x8A15…` z opisem po polsku tylko dla sprawdzonych, inne jako kod z ostatnią linią wyjścia (`Get-MwpWingetErrorText`). winget szukany jako alias użytkownika, potem w pakiecie `Microsoft.DesktopAppInstaller` konta sesji. **Ochrona** (`Get-MwpAppProtection`, egzekwowana w logice): Appx z podpisem System, struktury, zasobów i `NonRemovable`; z rejestru `SystemComponent`, `NoRemove` i aktualizacje; kategorie listy ochronnej `AppxPackage` (Store, App Installer, VCLibs, UI.Xaml, WindowsAppRuntime, NET.Native, Edge, zabezpieczenia Windows) i `App` (Edge, WebView2, Edge Update, App Installer, pakiety sterowników, Id lokalne MSIX tych pakietów); środowiska uruchomieniowe (VC++ Redistributable, .NET) — tylko ostrzeżenie (decyzja użytkownika). **Profil innego użytkownika:** podgląd jego programów (zalogowany profil), bez odinstalowania. **Komputer zdalny:** lista z rejestru (HKLM, wskazane zalogowane profile) i pakiety Appx konta połączenia działają przez WinRM; odinstalowanie Appx i zmiany winget wymagają administratora w sesji. **Sonda 2026-10-29** (komputer zdalny użytkownika, Windows 11, PowerShell 5.1, konto lokalnego administratora przez WinRM): `Get-AppxPackage` — 49 pakietów konta, `-AllUsers` — 164; App Installer niezarejestrowany dla konta połączenia (brak aliasu `winget.exe`), a `winget.exe` z `C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_…` — „Odmowa dostępu”. Dlatego winget zdalnie działa tylko, gdy konto połączenia ma zarejestrowany App Installer (alias albo plik z jego pakietu); inaczej lista, aktualizacje, wyszukiwanie, instalacja i odinstalowanie programów z rejestru dają czytelny komunikat „winget niedostępny”, a odinstalowanie pakietów Appx działa. Obejście (zadanie harmonogramu w sesji zalogowanego użytkownika albo jako SYSTEM) — poza zakresem, nowy ADR. Widok `Views/Apps.xaml` (katalog widoków hosta, D-044): zakładki Zainstalowane (wyszukiwanie, źródło, zakres, składniki systemowe, tylko z aktualizacją, sortowanie kolumnami, profil użytkownika na komputerze zdalnym, szczegóły, Aktualizuj, Odinstaluj — okno destrukcyjne, zdalnie z wpisaniem nazwy komputera), Aktualizacje (wielokrotne zaznaczenie, osobny krok na pakiet z postępem na pasku stanu), Wyszukaj i zainstaluj, cofnięcia (`Get-MwpAppsRow`, `Get-MwpAppsActionState`, `Get-MwpAppsDetail`, `Get-MwpAppsViewOption`). Testy: `tests/Modules/MWP.Apps/Apps.Tests.ps1` — atrapa `winget.cmd` w `TestDrive` (wyjście w stronie kodowej OEM, polskie nagłówki, kody HRESULT, stan po instalacji/odinstalowaniu), atrapy bloków inwentarza i usuwania Appx na pliku JSON, parsowanie (polskie i CJK, nagłówek dwuwyrazowy, stopki, kilka tabel), prawdziwy blok inwentarza tylko do odczytu, ścieżka zdalna przez mock adaptera transportu (administrator, zerwanie połączenia); `tests/UI/AppsView.Tests.ps1`.

## Kontrakt modułu (zatwierdzony w FAZIE 2, D-024)

Kontrakt jest w manifeście modułu, w sekcji `PrivateData.MWP` (PowerShell ignoruje nieznane klucze `PrivateData`, a `Import-PowerShellDataFile` czyta je bez importu modułu). `Version` i `Description` pochodzą z `ModuleVersion` i `Description` manifestu, żeby nie dublować danych.

```powershell
PrivateData = @{
    MWP = @{
        ContractVersion            = 1                        # wersja kontraktu (obsługiwana: 1)
        Id                         = 'Services'               # unikalny, litery i cyfry
        Name                       = 'Usługi Windows'         # nazwa wyświetlana
        EntryPoint                 = 'Get-MwpServicesModuleInfo'  # eksportowana funkcja wejścia
        MinimumHostVersion         = '0.2.0'                  # minimalna wersja hosta (= MWP.Core)
        Dependencies               = @(@{ Id = 'Core'; MinimumVersion = '0.2.0' })
        Capabilities               = @()                      # HostServices, Read, Change, Destructive, Undo, RestorePoint, RemoteTarget
        SupportedPresentationModes = @()                      # Embedded, SeparateWindow, DashboardWidget, Standalone, CLI
        RequiredPermissions        = @('User')                # User, Administrator (co najmniej jedna)
        ConfigurationSchema        = @{}                      # @{ klucz = @{ Type = 'String|Int|Bool|StringArray'; Default = ... } }
        Widgets                    = @(                       # opcjonalne (FAZA 5, D-043); wymaga trybu DashboardWidget
            @{ Id = 'SystemInfo'; Name = 'Informacje o systemie'; DataCommand = 'Get-MwpSystemInfo'; ViewCommand = 'ConvertTo-MwpSystemInfoView'
               ExportCommand = 'Export-MwpSystemReport'; DefaultRefreshSeconds = 60   # 0, 30, 60, 300, 900
               Parameters = @{ Sections = @{ Type = 'StringArray'; Default = @('System'); Values = @('System', 'Cpu'); Label = 'Sekcje' } } }
        )
    }
    PSData = @{ ... }
}
```

Słownik dozwolonych wartości jest w jednym miejscu (`Get-MwpContractVocabulary` w `MWP.Core`); jego zmiana wymaga wpisu w `DECYZJE.md`. `Capabilities` i `SupportedPresentationModes` modułów obszarów są puste, dopóki faza obszaru nie doda funkcji i widoków.

Odkrywanie i walidacja: `Get-MwpModuleDefinition` czyta manifesty `MWP.*/MWP.*.psd1` w katalogach: `src/Modules` (moduły wbudowane), `<katalog danych>\modules` (moduły zainstalowane z paczek, D-038) i dawny `src/Modules/Installed` (instalacje z FAZY 3 do przeniesienia; D-031; lista katalogów zamiast jednego `-ModulesRoot` od FAZY 3, ze zgodnością wsteczną) i zwraca definicje z polami `IsValid` i `Errors`. `Test-MwpModuleDefinition` sprawdza: obecność pól, wersję kontraktu, słownik wartości, `EntryPoint` wśród `FunctionsToExport`, `MinimumHostVersion` względem wersji hosta, unikalność `Id`, obecność i minimalne wersje zależności, zależność od samego siebie i cykle. Uszkodzony manifest daje błąd walidacji tego modułu, a nie przerywa odkrywania innych. Launcher nie ładuje modułu z błędnym kontraktem.

Cykl życia (D-024): **odkrycie** → **walidacja** → **import** (raz na proces lub runspace) → od FAZY 3: **utworzenie instancji** z kontekstem → **inicjalizacja** → **działanie** → **zamknięcie** i zwolnienie zasobów (zadania, sesje). Definicja jest niezmienna; stan należy do instancji.

Kontrakt określa: odkrywanie i ładowanie modułu (`src/Modules` i katalog modułów z paczek, instalacja i odinstalowanie z paczki — D-031, sekcja „Paczki modułów"), tworzenie, inicjalizację i zamykanie instancji, przekazywanie kontekstu wykonania, dostęp do usług hosta, udostępnianie pełnego widoku i widgetu, obsługę i walidację konfiguracji, zasady anulowania zadań i zwalniania zasobów, raportowanie błędów i statusów, zgodność wersji i brakujące zależności. Moduł nie zależy od prywatnych klas hosta bez jawnego kontraktu.

## Paczki modułów (D-031)

Moduły tworzy użytkownik w PowerShellu i dostarcza je jako paczki. Host instaluje je i odinstalowuje; aktualizacji modułów przez host nie ma (wersję podnosi autor przy tworzeniu modułu). Implementacja logiki: FAZA 3 (`MWP.Core`), widok „Moduły": FAZA 4, usuwanie widgetów: FAZA 5.

- **Format `.mwpmod`:** archiwum ZIP z dokładnie jednym folderem głównym `MWP.<Obszar>/` o budowie modułu (manifest `.psd1` z kontraktem `PrivateData.MWP`, `.psm1`, `Public/`, `Private/`). Bez podpisu cyfrowego (D-015); integralność potwierdza użytkownik po sumie SHA-256 paczki.
- **Moduł wbudowany** leży w `src/Modules/` (repozytorium), **moduł zainstalowany** w `<katalog danych>\modules\` (poza repozytorium, D-038; w FAZIE 3 — `src/Modules/Installed/`, nadal odkrywany do przeniesienia przez `Move-MwpInstalledModule`). `Get-MwpModuleDefinition`, launcher, host i `apprun` skanują te katalogi po manifeście.
- **Instalacja** (`Install-MwpModulePackage`, klasa **Zmiana**: `-WhatIf`, log): rozpakowanie do katalogu tymczasowego → walidacja (`Test-MwpModulePackage`: dokładnie jeden folder główny, żadna ścieżka w archiwum nie wychodzi poza folder docelowy, manifest i pola kontraktu, `MinimumHostVersion`, zależności, kolizja `Id` i nazwy folderu z modułem wbudowanym lub zainstalowanym) → okno potwierdzenia z nazwą, wersją, `RequiredPermissions` i SHA-256 paczki → atomowe przeniesienie do `<katalog danych>\modules\` → wpis w rejestrze. Błąd na dowolnym etapie usuwa katalog tymczasowy i nie zostawia niczego w połowie. Paczka z `Id` już zainstalowanego modułu jest odrzucana (nowa wersja = odinstalowanie starej, potem instalacja).
- **Odinstalowanie** (`Uninstall-MwpModulePackage`, klasa **Destrukcyjna**: `ConfirmImpact = 'High'`, potwierdzenie z nazwą modułu): zamknięcie instancji modułu → usunięcie jego widgetów z Dashboardu → usunięcie folderu modułu (z katalogu, w którym leży), sekcji konfiguracji modułu i wpisu w rejestrze. Zostają logi operacji i rejestr cofnięć (audyt zmian w systemie). Odinstalowanie nie jest cofane przez rejestr cofnięć (ponowna instalacja z paczki).
- **Moduły nieusuwalne:** bazowe (`MWP.Core`, `MWP.Remote`) i wszystkie wbudowane — odinstalowanie zwraca wynik z błędem.
- **Rejestr zainstalowanych modułów** w `config/settings.local.json` (klucz `installedModules`): `id`, `moduleName`, `version`, `installedAt`, `sha256`; odczyt `Get-MwpInstalledModule`. Ustawienia modułu — klucz `modules.<Id>` (usuwany przy odinstalowaniu).
- **Implementacja (FAZA 3, D-037):** archiwum sprawdzane w całości przed rozpakowaniem; katalogi robocze `.mwp-install-*`/`.mwp-remove-*` w katalogu modułów z paczek (ten sam wolumin, nie są odkrywane); błąd zapisu rejestru wycofuje przeniesiony folder; odinstalowanie odrzuca moduł wymagany przez inny moduł. W GUI moduł jest odkrywany od razu po instalacji (import przy pierwszej instancji); launcher importuje go przy następnym uruchomieniu.
- **Tylko lokalnie:** instalacja i usuwanie dotyczą komputera, na którym działa host; na komputerach zdalnych nic się nie instaluje (moduły wykonują tam operacje przez kontekst wykonania, D-019).

## Samodzielne uruchamianie (propozycja, FAZA 19)

Moduły deklarujące tryb Standalone lub CLI uruchamiają się bez głównego okna. Przykładowa składnia (nie jest zatwierdzona): `apprun "Services"`, `apprun "Services" -ComputerName "<nazwa>"`. Launcher znajduje i weryfikuje moduł, sprawdza zależności, przekazuje parametry i kontekst, uruchamia widok lub CLI, zachowuje walidację, autoryzację i logowanie i zwraca czytelne błędy. Nie powstaje osobna logika biznesowa na potrzeby trybu samodzielnego.

## Model procesów i współbieżność (rozstrzygnięty w FAZIE 2, D-023)

Moduły działają **w procesie hosta** jako zwykłe moduły PowerShella. Długie i zdalne operacje działają w **puli runspace'ów** z limitem równoległości, anulowaniem i limitem czasu na operację (implementacja w FAZIE 3: `Start-`/`Wait-`/`Stop-MwpOperation`, D-036; użycie w GUI: FAZA 4). Osobny proces tylko z uzasadnieniem: elewacja (nowy proces przez UAC, D-027) albo izolacja kodu, który może zawiesić lub zamknąć proces. Każda operacja ma zasady anulowania, limitów czasu, obsługi błędów i zwalniania zasobów.

Konsekwencje dla kodu (obowiązują od FAZY 2):
- funkcje logiki są bezstanowe: wszystko, co dotyczy komputera i instancji, przychodzi w parametrach; brak zmiennych modułu z kontekstem,
- runspace importuje moduły z manifestów; między runspace'ami nie ma współdzielonego, zmiennego stanu w pamięci,
- wspólne zasoby rdzenia są bezpieczne przy równoległym użyciu: log chroniony muteksem `Local\MyWindowsPower.Log`, zapisy plików atomowe, każdy wpis cofnięcia w osobnym pliku, konfiguracja czytana z pliku przy każdym odczycie (bez pamięci podręcznej).

## Zasady bezpieczeństwa zmian

- Domyślnie **podgląd**: GUI pokazuje, co zostanie zmienione, zanim to zrobi.
- Każda zmiana: wpis w logu operacji (co, kiedy, stan przed, stan po).
- Cofanie: tam, gdzie możliwe, zapisujemy stan przed zmianą i oferujemy przywrócenie.
- Punkt przywracania systemu przed grupą ryzykownych zmian (np. tweaki rejestru).
- Operacje wymagające administratora są jawnie oznaczone; launcher potrafi poprosić o podniesienie uprawnień.
- Lista ochronna: elementy krytyczne dla działania systemu (np. wybrane usługi) są oznaczone i domyślnie zablokowane przed wyłączeniem.
- Walidacja parametrów przekazywanych do poleceń systemowych; żadnego budowania poleceń przez sklejanie tekstu wejściowego (D-015).
- Nie osłabiamy zabezpieczeń Windows dla wygody; w logach nie zapisujemy sekretów.
- Komputery zdalne (D-019): potwierdzenie operacji zmieniającej system zawiera nazwę komputera docelowego; log i wpis cofnięcia zapisują komputer; punkt przywracania tworzony na komputerze docelowym; operacje mogące odciąć łączność (sieć, zapora) mają dodatkowe ostrzeżenie i, gdzie się da, automatyczne wycofanie po limicie czasu.
- Uprawnienia: nie traktuj obecności użytkownika w aplikacji jako dowodu uprawnień administracyjnych; rozróżniaj uwierzytelnienie, autoryzację i dostępność połączenia; stosuj najmniejsze wymagane uprawnienia.
- Klasy operacji (zatwierdzone w FAZIE 2, D-027): **Odczyt** (bez `SupportsShouldProcess`, bez potwierdzenia), **Zmiana** (odwracalna: `ConfirmImpact = 'Medium'`, podgląd, log, cofanie), **Destrukcyjna** (trudna do cofnięcia: `ConfirmImpact = 'High'`, przy domyślnym `$ConfirmPreference` zawsze pyta; potwierdzenie z nazwą celu i komputera); operacja o niejasnej klasie traktowana jak wyższa.
- Lista ochronna (D-029, D-045): `src/Modules/MWP.Core/Data/protected-items.json` (kategoria, nazwa lub wzorzec `-like`, powód) i opcjonalny `protected.local.json` obok `settings.local.json` (poza repozytorium; może tylko dodawać elementy); funkcja obszaru odmawia zmiany elementu, dla którego `Test-MwpProtectedItem` zwraca `$true`.

## Zgodność PowerShell 5.1 / 7.x

- Unikaj składni dostępnej tylko w 7.x (np. `??`, `?.`, ternary, `ForEach-Object -Parallel`) w kodzie, który ma działać w 5.1, albo zapewnij wariant.
- Zapisuj pliki `.ps1`/`.psm1`/`.psd1` jako UTF-8 z BOM (5.1 źle czyta polskie znaki bez BOM — potwierdzone w FAZIE 1: plik bez BOM nie parsuje się). Pliki JSON: UTF-8 bez BOM, czytane przez `Get-Content -Raw -Encoding UTF8`.
- Kontrolę zgodności wykonuje PSScriptAnalyzer (`PSUseCompatibleSyntax`, `PSUseCompatibleCommands`, `PSUseCompatibleTypes`, D-018). Testy (`tests\Invoke-Checks.ps1`) uruchamiane są w 5.1 i 7.x, każda wersja w nowym procesie (D-022).
- Kod wykonywany na komputerze zdalnym musi działać w Windows PowerShell 5.1: komputer zdalny nie ma PowerShell 7, a domyślny punkt końcowy WinRM (`Microsoft.PowerShell`) to 5.1. Nie zakładaj PowerShell 7 na komputerze docelowym.
- Cmdlety CIM zamiast WMI. Ścieżki przez `Join-Path`. Poleceń dostępnych tylko w 5.1 (np. `Checkpoint-Computer`, `Get-ComputerRestorePoint`) nie używamy — zamiennik przez CIM.
- Różnice wersji zbierz w jednym miejscu (`MWP.Core`: `Test-MwpIsWindows`, `ConvertTo-MwpHashtable`, `ConvertTo-MwpDateTime`).
- Pułapki potwierdzone w FAZIE 2:
  - `ConvertFrom-Json` w 7.x zamienia tekst ISO 8601 na `[datetime]`, w 5.1 zostawia tekst — daty zapisujemy jako tekst (`ToString('o')`) i ujednolicamy przy odczycie; 5.1 nie ma `-AsHashtable` (stąd `ConvertTo-MwpHashtable`); liczby całkowite to `[int]` w 5.1 i `[long]` w 7.x.
  - W 5.1 pojedynczy `PSCustomObject` nie ma właściwości `Count` — wynik potoku liczymy jako `@(...).Count`.
  - `$null` przekazany do parametru `[string]` metody .NET staje się pustym tekstem; brak wartości to `[NullString]::Value` (np. `[IO.File]::Replace`).
  - `$PSBoundParameters` wewnątrz bloku `Where-Object`/`ForEach-Object` dotyczy bloku, nie funkcji — odczytaj go wcześniej do zmiennej.

## Logi i konfiguracja

- Katalog danych (D-032): klucz `dataPath` w konfiguracji; pusty (domyślnie) = `<folder aplikacji>\data`; ścieżka względna liczona od folderu aplikacji (`$PSScriptRoot`, nie bieżący katalog); bezwzględna (dysk lub UNC) może zawierać zmienne środowiskowe. Zna go wyłącznie `Get-MwpDataPath` (`-Kind Root|Logs|Undo|Modules|Fallback`, `-Detailed`; zasady ścieżki w `Resolve-MwpDataPath`); stan dla GUI i CLI daje publiczna `Get-MwpDataLocation`. Katalog niezapisywalny (próba utworzenia i usunięcia pliku, wynik pamiętany do końca procesu) lub ścieżka niepoprawna → tryb zapasowy `%LOCALAPPDATA%\MyWindowsPower` z ostrzeżeniem w wyniku i w logu (`DataPath.Fallback`, raz na proces). W trybie zapasowym także `settings.local.json` (gdy folder `config` jest niezapisywalny; istniejący plik w `config` ma pierwszeństwo). Bez automatycznej migracji starych danych. Zmiana miejsca: „Przenieś dane” (`Move-MwpDataDirectory`: kopia `logs`/`undo`/`modules`, zapis `dataPath`, usunięcie starych danych; bez wpisu cofnięcia, D-038) albo tylko zapis `dataPath` (dane zostają w starym miejscu). Moduły z paczek leżą w `<katalog danych>\modules` (D-038).
- Logi (D-026, D-032): `<katalog danych>\logs\mwp-RRRR-MM-DD.log`, jeden wpis JSON na linię (UTF-8 bez BOM): `timestamp`, `level`, `computer`, `source`, `operation`, `message`, `user`, `processId`, opcjonalnie `data`. Próg `logLevel` (Debug/Info/Warning/Error), rotacja przy pierwszym wpisie dnia wg `logRetentionDays`. Operacje na komputerze zdalnym są logowane na hoście z nazwą komputera. Chwilowa blokada pliku (np. OneDrive) → do 5 ponowień (ok. 1,5 s), potem ostrzeżenie bez przerywania operacji. Start aplikacji zapisuje operacje `Startup.*` (źródło `Launcher`, opis w sekcji „Launcher”, D-042); awaryjny `mwp-startup-failure.log` w katalogu zapasowym tylko przy nieudanym imporcie `MWP.Core`.
- Rejestr cofnięć (D-028, D-032): `<katalog danych>\undo\<GUID>.json`.
- Dashboard (FAZA 5, D-043): klucze `dashboardWidgets`, `dashboardAutoRefresh`, `dashboardMaxParallelRefresh` — nowe klucze z wartościami domyślnymi w szablonie, bez zmiany `schemaVersion`.
- Konfiguracja użytkownika: `config/settings.local.json` (poza repozytorium; w trybie zapasowym `%LOCALAPPDATA%\MyWindowsPower\settings.local.json`, D-032); szablon `config/settings.example.json` z polem `schemaVersion` jest jednocześnie źródłem wartości domyślnych (D-025). Schemat 2 (FAZA 3, D-037) dodaje: `targets` (komputery zdalne; `localhost` jest zawsze obecny bez wpisu), `installedModules` (rejestr modułów z paczek), `modules` (ustawienia modułów), `remoteMaxParallelOperations`, `remoteConnectTimeoutSeconds`, `remoteOperationTimeoutSeconds`; migracja 1 → 2 zachowuje pozostałe klucze, w tym `dataPath`. Nazwy prawdziwych komputerów, adresy i poświadczenia nigdy nie trafiają do repozytorium ani do szablonu.
- Zasady (D-015, wdrożone w FAZIE 2, D-025): zapis atomowy (plik tymczasowy, potem `File.Replace`/`File.Move`); uszkodzony plik nie blokuje startu — wartości domyślne, ostrzeżenie i log, a plik zostaje zachowany jako `settings.local.json.corrupt-RRRRMMDD-GGmmss`; nowsza `schemaVersion` niż obsługiwana → wartości domyślne, plik bez zmian; starsza → migracje krok po kroku (`Invoke-MwpSettingsMigration`); `Set-MwpSetting` przyjmuje tylko klucze z szablonu i wartość zgodnego typu.

## Testy

- Pester dla modułów logiki; GUI testowane ręcznie wg checklist w plikach faz.
- Testy nie mogą zmieniać realnego systemu: używaj mocków i `-WhatIf`.
- Uruchamianie: `.\tests\Invoke-Checks.ps1` (opcje `-SkipAnalyzer`, `-SkipTests`); kod wyjścia 0 = analiza bez uwag i wszystkie testy zaliczone.
- Pliki testów zaczynają się od `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }` i atrybutu tłumiącego `PSUseDeclaredVarsMoreThanAssignments` (zakresy Pestera).

## Testy architektoniczne (FAZY 3–5 dodają je stopniowo, FAZA 20 domyka)

Stan po FAZIE 12: jak po FAZIE 11, plus 12 dla aplikacji (odinstalowanie, instalacja i aktualizacja na komputerze zdalnym: brak administratora w sesji = odmowa przed podglądem), 7 (zerwanie połączenia w trakcie odinstalowania — błąd tylko tej instancji, bez wpisu cofnięcia), lista ochronna identyczna lokalnie i zdalnie oraz kryteria FAZY 12: pakietów systemowych nie da się usunąć (także z CLI), parsowanie winget przy polskim systemie (`tests/Modules/MWP.Apps/Apps.Tests.ps1`), logika widoku (`tests/UI/AppsView.Tests.ps1`). Stan po FAZIE 11: jak po FAZIE 10, plus 12 dla sieci (każda zmiana: brak administratora na komputerze docelowym = odmowa przed podglądem, także w sesji zdalnej), 7 (zerwanie połączenia w trakcie wyłączenia adaptera połączenia — błąd tylko tej instancji, zadanie wycofania przywraca adapter) oraz kryterium FAZY 11: zmiana DNS cofana jednym wywołaniem, bez zatwierdzenia wycofywana automatycznie (`tests/Modules/MWP.Network/Network.Tests.ps1`), logika widoku (`tests/UI/NetworkView.Tests.ps1`). Stan po FAZIE 10: jak po FAZIE 9, plus 12 dla Windows Update (pauza, reset i instalacja: brak administratora na komputerze docelowym = odmowa przed podglądem, sprawdzenie w sesji zdalnej), 7 (utrata połączenia w trakcie resetu — błąd tylko tej instancji, foldery bez zmian), 8 (anulowanie instalacji z tabeli postępu) oraz kryterium FAZY 10: reset odwracalny — stare foldery zachowane i przywracane cofnięciem (`tests/Modules/MWP.Update/Update.Tests.ps1`), logika widoku (`tests/UI/UpdateView.Tests.ps1`). Stan po FAZIE 9: jak po FAZIE 8, plus 12 dla czyszczenia dysku (brak administratora na komputerze docelowym = kategoria systemowa odrzucona przed podglądem), 7 (utrata połączenia w trakcie czyszczenia — błąd tylko tej instancji, pliki zostają), 8 (anulowanie skanu i czyszczenia z tabeli postępu, także w trakcie kategorii) oraz kryterium FAZY 9: żadna operacja nie wychodzi poza zdefiniowane ścieżki (`tests/Modules/MWP.Cleanup/Cleanup.Tests.ps1`), logika widoku (`tests/UI/CleanupView.Tests.ps1`). Stan po FAZIE 8: jak po FAZIE 7, plus 12 dla obszaru autostartu i harmonogramu (pozycja komputera lub innego użytkownika i każda zmiana zadania: brak administratora na komputerze docelowym = odmowa przed podglądem, sprawdzenie w sesji zdalnej), 7 (utrata połączenia w trakcie zmiany zadania), lista ochronna zadań identyczna lokalnie i zdalnie (`tests/Modules/MWP.Startup/Startup.Tests.ps1`) oraz logika widoku (`tests/UI/StartupView.Tests.ps1`). Stan po FAZIE 7: jak po FAZIE 6, plus 12 dla obszaru usług (każda zmiana usługi: brak administratora na komputerze docelowym = odmowa przed podglądem), 7 dla instancji usług (utrata połączenia w trakcie zatrzymania), lista ochronna identyczna lokalnie i zdalnie (`tests/Modules/MWP.Services/Services.Tests.ps1`) oraz logika widoku Usługi (`tests/UI/ServicesView.Tests.ps1`). Stan po FAZIE 6: jak po FAZIE 5, plus 12 dla obszaru zasilania (hibernacja i szybkie uruchamianie: brak administratora na komputerze docelowym = odmowa przed zmianą, `tests/Modules/MWP.Power/Power.Tests.ps1`), 7 dla instancji modułu obszaru (utrata połączenia w trakcie zmiany planu) oraz logika widoku modułu (`tests/UI/PowerView.Tests.ps1`). Stan po FAZIE 5: jak po FAZIE 4, plus 5 (na poziomie kontraktu i katalogu widgetów), 6, 7 (widgety) i 10 — `tests/UI/Widgets.Tests.ps1` (własna instancja widgetu, awaria funkcji danych i utrata połączenia jednego widgetu bez wpływu na drugi, usunięcie widgetu anuluje zadanie i zamyka instancję, zapis i odtworzenie konfiguracji), `tests/Modules/MWP.Core/Dashboard.Tests.ps1`, `ModulePackage.Tests.ps1` (widgety odinstalowanego modułu); w oknie — automatyczny test dymny i weryfikacja ręczna. Stan po FAZIE 4: jak po FAZIE 3, plus granica warstw UI (`tests/UI/Xaml.Tests.ps1`: kod `src/UI` wywołuje tylko funkcje Mwp i dozwolone polecenia wbudowane), zadania w tle GUI (`tests/UI/UiFunctions.Tests.ps1`) oraz 2, 3 i 9 w oknie — weryfikacja ręczna na Windows 11 (paczka `samples/MWP.Przyklad`). Stan po FAZIE 3 (testy Pester z mockami): 3, 4, 7 (na poziomie kontekstów i instancji), 8, 9 i 11 — `tests/Modules/MWP.Remote/*.Tests.ps1`, `tests/Modules/MWP.Core/ModuleContract.Tests.ps1`, `ModulePackage.Tests.ps1`; 12 częściowo (`New-MwpRestorePoint -Context`). Dodatkowo `Architecture.Tests.ps1`: funkcje komputera docelowego przyjmują `-Context`, polecenia WinRM/CIM tylko w adapterze, brak zmian `TrustedHosts`, brak zmiennych modułu z komputerem lub poświadczeniami.

1. Uruchomienie modułu samodzielnie bez hosta.
2. Uruchomienie modułu wewnątrz hosta.
3. Dwie instancje tego samego modułu dla dwóch komputerów.
4. Instancje nie współdzielą przypadkowo zmiennego stanu.
5. Widgety różnych modułów na Dashboardzie.
6. Kilka widgetów powiązanych z różnymi komputerami.
7. Utrata połączenia z jednym komputerem bez zatrzymywania pozostałych widgetów.
8. Anulowanie długiej operacji i zwolnienie zasobów.
9. Zamknięcie jednej instancji bez wpływu na inne.
10. Odtworzenie konfiguracji Dashboardu po ponownym uruchomieniu.
11. Niezgodna wersja modułu lub brakująca zależność.
12. Weryfikacja wymaganych uprawnień przed operacją administracyjną.

Testy z komputerem zdalnym używają mocków; realne połączenie jest weryfikowane ręcznie na Windows 11 (punkty „DO WERYFIKACJI NA WINDOWS" w plikach faz).
