# ARCHITEKTURA — mywindowspower

> Stack, struktura kodu i konwencje. Aktualizowana, gdy zmienia się architektura. Zmiany odnotuj w `DECYZJE.md`.
> Stan: **rdzeń i kontrakt modułu (FAZA 2)** + architektura wielokomputerowa z koncepcji pierwotnej przywrócona w D-019, D-020 i D-021. Rdzeń, wzorzec funkcji zmieniającej system i kontrakt modułu są zatwierdzone (D-023…D-029); kontekst wykonania, instancje i widgety dopracowują FAZY 3–5. Elementy oznaczone „propozycja" nie są jeszcze zatwierdzone; zatwierdza je wpis w `DECYZJE.md` w wymienionej fazie.
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
├── data/                           ← (D-032) dane aplikacji: logs/, undo/ (poza repo, `/data/` w .gitignore; miejsce z klucza dataPath)
├── src/
│   ├── Modules/
│   │   ├── MWP.<Obszar>/           ← budowa każdego modułu:
│   │   │   ├── MWP.<Obszar>.psd1   ←   manifest (PowerShellVersion 5.1, Desktop+Core, jawne FunctionsToExport)
│   │   │   ├── MWP.<Obszar>.psm1   ←   ładuje Private/*.ps1 i Public/*.ps1, eksportuje Public
│   │   │   ├── Public/             ←   funkcje eksportowane, jeden plik = jedna funkcja
│   │   │   └── Private/            ←   funkcje wewnętrzne
│   │   ├── MWP.Core/               ← logowanie, konfiguracja, środowisko i elewacja, punkt przywracania, rejestr cofnięć, obiekt wyniku, lista ochronna, kontrakt i odkrywanie modułów (FAZA 2)
│   │   │   └── Data/               ←   protected-items.json (lista ochronna)
│   │   ├── MWP.Remote/             ← (FAZA 3) komputery docelowe, kontekst wykonania, połączenia, instancje modułów
│   │   ├── MWP.Dashboard/          ← informacje o systemie i sprzęcie (dane; układ widgetów w warstwie hosta, FAZA 5)
│   │   ├── MWP.Power/              ← plany zasilania
│   │   ├── MWP.Services/           ← usługi Windows
│   │   ├── MWP.Startup/            ← autostart i zadania harmonogramu
│   │   ├── MWP.Cleanup/            ← czyszczenie dysku
│   │   ├── MWP.Update/             ← Windows Update
│   │   ├── MWP.Network/            ← sieć
│   │   ├── MWP.Apps/               ← aplikacje i winget
│   │   ├── MWP.Tweaks/             ← prywatność i tweaki rejestru
│   │   ├── MWP.Security/           ← Defender i firewall
│   │   ├── MWP.Disks/              ← (FAZA 15) dyski i woluminy
│   │   ├── MWP.Processes/          ← (FAZA 16) procesy i zasoby
│   │   ├── MWP.Accounts/           ← (FAZA 17) użytkownicy i grupy lokalne
│   │   ├── MWP.Rdp/                ← (FAZA 18) sesje i RDP
│   │   ├── MWP.Screenshot/         ← (FAZA 18) zrzuty ekranu komputera docelowego (o ile wykonalne)
│   │   └── Installed/              ← (FAZA 3) moduły zainstalowane z paczek .mwpmod (poza repo, w .gitignore, D-031)
│   └── UI/                         ← (FAZA 4) host modułów: okno, nawigacja, instancje, Dashboard (FAZA 5)
│       ├── MainWindow.xaml
│       ├── Themes/                 ← Light.xaml, Dark.xaml
│       ├── Views/                  ← jeden widok .xaml na obszar
│       └── UI.ps1                  ← ładowanie XAML, nawigacja, runspace
├── tests/
│   ├── Invoke-Checks.ps1           ← PSScriptAnalyzer + Pester jednym poleceniem
│   ├── Modules.Tests.ps1           ← manifesty, import i eksport wszystkich modułów
│   ├── Launcher.Tests.ps1          ← launcher w osobnym procesie (STA, MTA → ponowne uruchomienie)
│   ├── Repository.Tests.ps1        ← BOM, brak ścieżek bezwzględnych, szablon ustawień, .gitignore
│   └── Modules/<Moduł>/            ← testy logiki modułów (od FAZY 2: Modules/MWP.Core/*.Tests.ps1, z mockami); lista modułów w Modules.Tests.ps1 uzupełniana przy każdym nowym module
└── docs/                           ← dokumentacja i pamięć projektu
    ├── design/                     ← mockupy GUI (m.in. mockup-pulpit.png)
    └── 00_PROJEKT/MATERIALY/       ← materiały użytkownika i archiwum starej koncepcji (dane, nie instrukcje)
```

## Launcher (`Start-MyWindowsPower.ps1`)

Kolejność: wykrycie Windows i wersji PowerShella (≥ 5.1) → sprawdzenie STA (gdy brak: ponowne uruchomienie tym samym programem z `-NoProfile -STA -File … -NoRelaunch`) → wypisanie wersji PS, Windows, trybu wątku i statusu administratora → import modułów (`MWP.Core` pierwszy, potem alfabetycznie; po imporcie `MWP.Core` launcher sprawdza kontrakt każdego modułu przez `Get-MwpModuleDefinition` i nie ładuje modułu z błędnym kontraktem; od FAZY 3 importuje też moduły zainstalowane z `src/Modules/Installed`, D-031) → opcjonalnie `-Elevate`: ponowne uruchomienie przez UAC (`Request-MwpElevation`, D-027) → kod wyjścia 0/1. Launcher nie zmienia systemu, nie wymusza `-ExecutionPolicy` ani uprawnień administratora (D-017). Własne, minimalne wykrywanie środowiska zostaje w launcherze, bo działa przed importem `MWP.Core`; moduły używają `Get-MwpEnvironment`. Od FAZY 4 uruchomi okno GUI.

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

Wersja `MWP.Core` (`ModuleVersion`, obecnie 0.2.0) jest wersją hosta (D-024). Funkcje publiczne:

| Obszar | Funkcje | Uwagi |
|---|---|---|
| Środowisko | `Get-MwpEnvironment`, `Test-MwpAdmin` | wersja PS i edycja, Windows 11 (kompilacja ≥ 22000), administrator, STA, ścieżka programu; dotyczą procesu hosta (`localhost`) |
| Elewacja | `Request-MwpElevation` | na życzenie, nowy proces tego samego PowerShella przez UAC (D-027) |
| Logowanie | `Write-MwpLog` | plik dzienny JSON Lines, komputer w każdym wpisie, rotacja, muteks, ponawianie przy blokadzie pliku, ukrywanie sekretów (D-026, D-032) |
| Katalog danych | `Get-MwpDataPath` (wewnętrzna), `Test-MwpDirectoryWritable` | `dataPath` z konfiguracji, domyślnie `<folder aplikacji>\data`; tryb zapasowy `%LOCALAPPDATA%\MyWindowsPower` z ostrzeżeniem (D-032) |
| Konfiguracja | `Get-MwpSetting`, `Set-MwpSetting` | szablon + plik lokalny, zapis atomowy, odporność na uszkodzony plik, migracje `schemaVersion` (D-025) |
| Wynik | `New-MwpResult`, `Format-MwpOperationTarget` | standardowy obiekt wyniku; opis celu z nazwą komputera do potwierdzeń |
| Cofanie | `Save-MwpUndoEntry`, `Get-MwpUndoEntry`, `Invoke-MwpUndo` | rejestr cofnięć w `<katalog danych>\undo\` (D-028, D-032) |
| Punkt przywracania | `New-MwpRestorePoint` | CIM `SystemRestore`; limit częstotliwości i wyłączona ochrona obsłużone (D-029) |
| Lista ochronna | `Test-MwpProtectedItem`, `Get-MwpProtectedItem` | dane w `MWP.Core\Data\protected-items.json` (D-029) |
| Kontrakt modułu | `Get-MwpModuleDefinition`, `Test-MwpModuleDefinition` | odkrywanie bez importu, walidacja wersji i zależności (D-024); w FAZIE 2 tylko `src/Modules`, od FAZY 3 także `src/Modules/Installed` (D-031) |
| Paczki modułów (FAZA 3) | `Test-MwpModulePackage`, `Install-MwpModulePackage`, `Uninstall-MwpModulePackage` | instalacja i odinstalowanie modułów z paczek `.mwpmod`, tylko lokalnie (D-031) |

Funkcje wewnętrzne (`Private/`) ukrywają położenie danych (`Get-MwpDataPath`, `Get-MwpConfigPath` — w testach podmieniane mockami na `TestDrive`), konwersje JSON zgodne z 5.1 i 7.x (`ConvertTo-MwpHashtable`, `ConvertTo-MwpDateTime`) i zapis atomowy (`Write-MwpJsonFile`).

**Komputer w API rdzenia (D-019):** log, wpis cofnięcia, obiekt wyniku, opis celu i punkt przywracania mają parametr `-ComputerName` z wartością domyślną `localhost`. Rdzeń nie ma żadnej zmiennej modułu ani globalnej z „bieżącym komputerem" (sprawdza to `tests/Modules/MWP.Core/Architecture.Tests.ps1`). Operacje systemowe rdzenia (punkt przywracania) działają w FAZIE 2 tylko lokalnie i dla innego komputera zwracają wynik z błędem; w FAZIE 3 `-ComputerName` zastąpi lub uzupełni kontekst wykonania (`-Context`).

## Wzorzec funkcji zmieniającej system (FAZA 2)

Każda funkcja obszaru, która zmienia system, stosuje ten wzorzec; infrastrukturę (log, cofanie, wynik, lista ochronna) daje `MWP.Core`. Działający przykład w repozytorium: `Set-MwpSetting` (zmienia ustawienie aplikacji, a nie system, ale przechodzi przez wszystkie kroki).

```powershell
function Set-MwpExampleThing {
    # Klasa operacji: Zmiana → ConfirmImpact 'Medium'; Destrukcyjna → 'High'; Odczyt → bez SupportsShouldProcess.
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Name,
        [Parameter(Mandatory)] [ValidateSet('A', 'B')] [string] $Value,
        [ValidateNotNullOrEmpty()] [string] $ComputerName = 'localhost'   # od FAZY 3: -Context
    )

    $common = @{ Operation = 'Example.SetThing'; Target = $Name; ComputerName = $ComputerName }

    # 1. Walidacja i lista ochronna — przed jakąkolwiek zmianą.
    if (Test-MwpProtectedItem -Category 'Example' -Name $Name) {
        return New-MwpResult @common -Success $false -Message "Element '$Name' jest na liście ochronnej."
    }
    # 2. Uprawnienia: sprawdzamy, nie podnosimy samodzielnie.
    if (-not (Test-MwpAdmin)) {
        return New-MwpResult @common -Success $false -Message 'Operacja wymaga uprawnień administratora.'
    }
    # 3. Stan przed zmianą; brak różnicy = brak zmiany.
    $before = Get-ExampleThing -Name $Name
    if ($before -eq $Value) {
        return New-MwpResult @common -Success $true -Before $before -After $before -Message 'Bez zmian.'
    }
    # 4. Podgląd (-WhatIf) i potwierdzenie (-Confirm) z nazwą komputera docelowego.
    $target = Format-MwpOperationTarget -Target "element '$Name'" -ComputerName $ComputerName
    if (-not $PSCmdlet.ShouldProcess($target, "Zmiana z '$before' na '$Value'")) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $Value -Message "Podgląd: $Name → $Value."
    }
    # 5. Zmiana, wpis cofnięcia, log i wynik; oczekiwane błędy jako wynik, nie wyjątek.
    try {
        Set-ExampleThing -Name $Name -Value $Value -ErrorAction Stop
        $undo = Save-MwpUndoEntry -Module 'MWP.Example' -Operation $common.Operation -Target $Name -ComputerName $ComputerName `
            -Before $before -After $Value -UndoCommand 'Set-MwpExampleThing' -UndoParameters @{ Name = $Name; Value = $before }
        Write-MwpLog -Level Info -Source 'MWP.Example' -Operation $common.Operation -ComputerName $ComputerName -Message "Zmieniono $Name."
        New-MwpResult @common -Success $true -Changed $true -Before $before -After $Value -UndoId $undo.Id -Message "Zmieniono $Name."
    }
    catch {
        Write-MwpLog -Level Error -Source 'MWP.Example' -Operation $common.Operation -ComputerName $ComputerName -Message $_.Exception.Message
        New-MwpResult @common -Success $false -Before $before -Message "Nie udało się zmienić $Name." -ErrorMessage $_.Exception.Message
    }
}
```

Zasady wzorca:
- **Wynik zawsze jako `MWP.Result`.** Pola: `Success`, `Changed`, `IsPreview`, `RestartRequired`, `Operation`, `Target`, `ComputerName`, `Message`, `Before`, `After`, `UndoId`, `ErrorMessage`, `Data`, `Timestamp`. W podglądzie `Changed` jest zawsze `$false`. Przewidziane błędy (brak uprawnień, lista ochronna, błąd systemu) zwracamy jako `Success = $false` z komunikatem po polsku; wyjątek tylko dla błędów programisty (zła wartość parametru, zatrzymana przez walidację parametrów).
- **Podgląd przed zmianą:** cały odczyt i walidacja dzieją się przed `ShouldProcess`; w gałęzi podglądu nic nie jest zapisywane (ani system, ani rejestr cofnięć, ani log zmiany).
- **Cofnięcie:** wpis zapisujemy po udanej zmianie; polecenie cofające to funkcja `Verb-MwpNoun` (zwykle ta sama, z wartością sprzed zmiany) i musi zwracać `MWP.Result`. Gdy cofnięcie nie jest możliwe, nie zapisujemy wpisu i piszemy to w komunikacie (oraz w opisie funkcji).
- **Punkt przywracania:** przed grupą ryzykownych zmian (np. tweaki rejestru) wywołujący (GUI lub funkcja grupy) tworzy `New-MwpRestorePoint`, o ile ustawienie `createRestorePointBeforeRiskyChanges` jest włączone; pojedyncza funkcja nie tworzy go sama.
- **Komputer:** każde wywołanie rdzenia dostaje komputer docelowy z parametru funkcji (od FAZY 3 z kontekstu); nigdy ze zmiennej globalnej.
- **Sekrety:** nie trafiają do `-Before`/`-After`/`-UndoParameters` ani do logu (log dodatkowo ukrywa pola o nazwach typu `Password`, `Token`).
- **Testy:** każda funkcja ma testy Pester z mockami poleceń systemowych, w tym test `-WhatIf` (polecenie zmieniające nie zostało wywołane) i test cofnięcia.

## Host i moduły (propozycja, FAZA 2–4)

Host (okno główne) odpowiada za: nawigację (`Pulpit` z Dashboardem, obszary, `Moduły`, `Ustawienia`, `O programie`), wykrywanie, ładowanie i uruchamianie modułów, instalację i odinstalowanie modułów z paczek (D-031), zarządzanie instancjami i ich cyklem życia, konfigurację i logowanie, zarządzanie komputerami docelowymi, umieszczanie widoków modułów (okno główne, osobne okno, Dashboard), zapis konfiguracji Dashboardu, obsługę błędów i statusów połączeń, kontrolę uprawnień i potwierdzeń. Host nie zawiera szczegółowej logiki obszarów.

Każdy moduł: ma unikalny identyfikator, nazwę i wersję; udostępnia kontrakt integracyjny (manifest); oddziela widok od logiki; deklaruje obsługiwane tryby prezentacji, wymagane uprawnienia i zależności; waliduje dane wejściowe i zgłasza czytelne błędy; jest testowalny bez hosta.

## Definicja modułu a instancja modułu

**Definicja modułu nie jest jego instancją.** Definicja opisuje funkcjonalność, instancja jest konkretnym uruchomieniem w określonym kontekście. Przykład: moduł `Services` ma jednocześnie dwie instancje, „Usługi — localhost" i „Usługi — komputer zdalny". Obie używają tej samej implementacji, ale mają niezależne konteksty, stan widoku, parametry, status połączenia i cykl życia.

Wymagania:
- jedna definicja, wiele instancji; każda instancja ma własny identyfikator i jawny kontekst wykonania,
- stan instancji nie jest przypadkowo współdzielony; zmiana komputera w jednej instancji nie zmienia kontekstu innych,
- zamknięcie jednej instancji nie zamyka pozostałych i zwalnia jej zasoby (zadania, sesje),
- instancje mogą współdzielić tylko bezpieczne, niemodyfikowalne zasoby o jawnie zdefiniowanych zasadach,
- sesje zdalne i zasoby zależne od uprawnień mają określony zakres i cykl życia.

## Kontekst wykonania i komputer docelowy (propozycja, FAZA 3)

Nie zakładaj, że moduł działa na komputerze lokalnym. Kontekst wykonania (`New-MwpExecutionContext`) określa co najmniej:
- komputer docelowy (`localhost` albo nazwa zdalnego komputera z rejestru komputerów),
- tryb: `Local` (bezpośrednio) lub `Remote` (przez transport),
- tożsamość lub odwołanie do poświadczeń (nigdy sam sekret),
- stan połączenia: `Connected`, `Connecting`, `Disconnected`, `Unauthorized`, `Error`,
- parametry specyficzne dla modułu,
- politykę limitów czasu i obsługi błędów.

Kontekst jest niezmienny w obrębie instancji. Nazwy pól do potwierdzenia w FAZIE 3.

Rozdzielone są: reprezentacja komputera docelowego, nawiązywanie i utrzymywanie połączenia, wykonywanie operacji, prezentacja stanu połączenia w UI. Rozdzielone są też uwierzytelnienie, autoryzacja i dostępność połączenia. Błędy połączenia obsługiwane są na poziomie kontekstu lub instancji, nigdy jako błąd całej aplikacji.

## Połączenia zdalne (propozycja, FAZA 3)

- Rejestr komputerów docelowych w `config/settings.local.json` (poza repozytorium); `localhost` zawsze obecny.
- Wykonanie operacji: `Invoke-MwpOnTarget -Context -ScriptBlock -ArgumentList` — lokalnie bezpośrednio, zdalnie przez sesję. Wynik w standardowym obiekcie `New-MwpResult`.
- Transport (ADR w FAZIE 3): propozycja — PowerShell Remoting (WinRM) dla operacji i sesje CIM dla odczytu; nie wszystkie moduły muszą używać tego samego transportu (kontrakt adaptera). Tylko kanały wbudowane w Windows, bez własnego agenta.
- Uwierzytelnianie (ADR w FAZIE 3): bez haseł i sekretów w jawnym tekście, w repozytorium i w logach; opcje: bieżący użytkownik, `Get-Credential` na życzenie, poświadczenia z ochroną DPAPI. Nie osłabiamy zabezpieczeń Windows (np. brak `TrustedHosts = *`).
- Izolacja: awaria, limit czasu lub brak uprawnień dla jednego komputera nie wpływa na pozostałe instancje i widgety; limit równoległych zadań; anulowanie i zwalnianie zasobów.
- Znane ograniczenia zdalne do zbadania w fazach obszarów: profil użytkownika (HKCU) i `winget` w sesji nieinteraktywnej, Windows Update Agent (COM) w sesji zdalnej, zrzuty ekranu i dostęp do pulpitu użytkownika, ryzyko utraty łączności przy zmianie sieci i zapory.

## Tryby prezentacji (propozycja, FAZA 4, 5, 19)

Moduł deklaruje, które tryby obsługuje (nie każdy musi wszystkie):

1. **Embedded** — widok w oknie głównym.
2. **SeparateWindow** — widok w osobnym oknie.
3. **DashboardWidget** — uproszczony widok danych na Dashboardzie.
4. **Standalone** — samodzielne uruchomienie bez hosta.
5. **CLI** — uruchomienie z linii poleceń.

Miejsce prezentacji nie określa logiki modułu. Widoki mogą się różnić, ale używają wspólnych usług aplikacyjnych. Tryb samodzielny nie omija zabezpieczeń, walidacji ani kontroli uprawnień.

## Dashboard i widgety (propozycja, FAZA 5)

Dashboard to konfigurowalna przestrzeń robocza z wieloma widokami modułów dla różnych komputerów jednocześnie (np. status usług na jednym komputerze, dyski na drugim, informacje o systemie lokalnym, status RDP). Dashboard jest kompozycją niezależnych widgetów, a nie zbiorem specjalnie napisanych ekranów.

- Widget to osobny kontrakt prezentacji danych (nie miniaturowe okno): własna konfiguracja, jawne powiązanie z instancją modułu lub źródłem danych i komputerem, wspólne usługi aplikacyjne z pełnym widokiem.
- Stany widgetu: ładowanie, błąd, brak danych, utrata połączenia. Odświeżanie ręczne i automatyczne z kontrolowaną częstotliwością; limit równoległych zadań w tle.
- Izolacja: błąd jednego widgetu lub utrata połączenia z jednym komputerem nie zatrzymuje pozostałych; usunięcie widgetu anuluje zadania i zwalnia zasoby.
- Konfiguracja Dashboardu (widgety, komputery, parametry, układ) jest zapisywana i odtwarzana po ponownym uruchomieniu (miejsce zapisu: ADR w FAZIE 5, propozycja — plik lokalny poza repozytorium).

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
    }
    PSData = @{ ... }
}
```

Słownik dozwolonych wartości jest w jednym miejscu (`Get-MwpContractVocabulary` w `MWP.Core`); jego zmiana wymaga wpisu w `DECYZJE.md`. `Capabilities` i `SupportedPresentationModes` modułów obszarów są puste, dopóki faza obszaru nie doda funkcji i widoków.

Odkrywanie i walidacja: `Get-MwpModuleDefinition` czyta manifesty `MWP.*/MWP.*.psd1` w dwóch katalogach: `src/Modules` (moduły wbudowane) i `src/Modules/Installed` (moduły zainstalowane z paczek, D-031; w FAZIE 2 był tylko pierwszy katalog, drugi dochodzi w FAZIE 3 jako lista katalogów zamiast jednego `-ModulesRoot`, ze zgodnością wsteczną) i zwraca definicje z polami `IsValid` i `Errors`. `Test-MwpModuleDefinition` sprawdza: obecność pól, wersję kontraktu, słownik wartości, `EntryPoint` wśród `FunctionsToExport`, `MinimumHostVersion` względem wersji hosta, unikalność `Id`, obecność i minimalne wersje zależności, zależność od samego siebie i cykle. Uszkodzony manifest daje błąd walidacji tego modułu, a nie przerywa odkrywania innych. Launcher nie ładuje modułu z błędnym kontraktem.

Cykl życia (D-024): **odkrycie** → **walidacja** → **import** (raz na proces lub runspace) → od FAZY 3: **utworzenie instancji** z kontekstem → **inicjalizacja** → **działanie** → **zamknięcie** i zwolnienie zasobów (zadania, sesje). Definicja jest niezmienna; stan należy do instancji.

Kontrakt określa: odkrywanie i ładowanie modułu (`src/Modules` i `src/Modules/Installed`, instalacja i odinstalowanie z paczki — D-031, sekcja „Paczki modułów"), tworzenie, inicjalizację i zamykanie instancji, przekazywanie kontekstu wykonania, dostęp do usług hosta, udostępnianie pełnego widoku i widgetu, obsługę i walidację konfiguracji, zasady anulowania zadań i zwalniania zasobów, raportowanie błędów i statusów, zgodność wersji i brakujące zależności. Moduł nie zależy od prywatnych klas hosta bez jawnego kontraktu.

## Paczki modułów (D-031)

Moduły tworzy użytkownik w PowerShellu i dostarcza je jako paczki. Host instaluje je i odinstalowuje; aktualizacji modułów przez host nie ma (wersję podnosi autor przy tworzeniu modułu). Implementacja logiki: FAZA 3 (`MWP.Core`), widok „Moduły": FAZA 4, usuwanie widgetów: FAZA 5.

- **Format `.mwpmod`:** archiwum ZIP z dokładnie jednym folderem głównym `MWP.<Obszar>/` o budowie modułu (manifest `.psd1` z kontraktem `PrivateData.MWP`, `.psm1`, `Public/`, `Private/`). Bez podpisu cyfrowego (D-015); integralność potwierdza użytkownik po sumie SHA-256 paczki.
- **Moduł wbudowany** leży w `src/Modules/` (repozytorium), **moduł zainstalowany** w `src/Modules/Installed/` (poza repozytorium, `.gitignore`). `Get-MwpModuleDefinition`, launcher, host i `apprun` skanują oba katalogi po manifeście.
- **Instalacja** (`Install-MwpModulePackage`, klasa **Zmiana**: `-WhatIf`, log): rozpakowanie do katalogu tymczasowego → walidacja (`Test-MwpModulePackage`: dokładnie jeden folder główny, żadna ścieżka w archiwum nie wychodzi poza folder docelowy, manifest i pola kontraktu, `MinimumHostVersion`, zależności, kolizja `Id` i nazwy folderu z modułem wbudowanym lub zainstalowanym) → okno potwierdzenia z nazwą, wersją, `RequiredPermissions` i SHA-256 paczki → atomowe przeniesienie do `src/Modules/Installed/` → wpis w rejestrze. Błąd na dowolnym etapie usuwa katalog tymczasowy i nie zostawia niczego w połowie. Paczka z `Id` już zainstalowanego modułu jest odrzucana (nowa wersja = odinstalowanie starej, potem instalacja).
- **Odinstalowanie** (`Uninstall-MwpModulePackage`, klasa **Destrukcyjna**: `ConfirmImpact = 'High'`, potwierdzenie z nazwą modułu): zamknięcie instancji modułu → usunięcie jego widgetów z Dashboardu → usunięcie folderu z `src/Modules/Installed/`, sekcji konfiguracji modułu i wpisu w rejestrze. Zostają logi operacji i rejestr cofnięć (audyt zmian w systemie). Odinstalowanie nie jest cofane przez rejestr cofnięć (ponowna instalacja z paczki).
- **Moduły nieusuwalne:** bazowe (`MWP.Core`, `MWP.Remote`) i wszystkie wbudowane — odinstalowanie zwraca wynik z błędem.
- **Rejestr zainstalowanych modułów** w `config/settings.local.json`: `Id`, wersja, data instalacji, SHA-256 paczki.
- **Tylko lokalnie:** instalacja i usuwanie dotyczą komputera, na którym działa host; na komputerach zdalnych nic się nie instaluje (moduły wykonują tam operacje przez kontekst wykonania, D-019).

## Samodzielne uruchamianie (propozycja, FAZA 19)

Moduły deklarujące tryb Standalone lub CLI uruchamiają się bez głównego okna. Przykładowa składnia (nie jest zatwierdzona): `apprun "Services"`, `apprun "Services" -ComputerName "<nazwa>"`. Launcher znajduje i weryfikuje moduł, sprawdza zależności, przekazuje parametry i kontekst, uruchamia widok lub CLI, zachowuje walidację, autoryzację i logowanie i zwraca czytelne błędy. Nie powstaje osobna logika biznesowa na potrzeby trybu samodzielnego.

## Model procesów i współbieżność (rozstrzygnięty w FAZIE 2, D-023)

Moduły działają **w procesie hosta** jako zwykłe moduły PowerShella. Długie i zdalne operacje działają w **puli runspace'ów** z limitem równoległości, anulowaniem i limitem czasu na operację (implementacja: FAZA 3 dla operacji zdalnych, FAZA 4 dla GUI). Osobny proces tylko z uzasadnieniem: elewacja (nowy proces przez UAC, D-027) albo izolacja kodu, który może zawiesić lub zamknąć proces. Każda operacja ma zasady anulowania, limitów czasu, obsługi błędów i zwalniania zasobów.

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
- Lista ochronna (D-029): `src/Modules/MWP.Core/Data/protected-items.json` (kategoria, nazwa lub wzorzec `-like`, powód); funkcja obszaru odmawia zmiany elementu, dla którego `Test-MwpProtectedItem` zwraca `$true`.

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

- Katalog danych (D-032): klucz `dataPath` w konfiguracji; pusty (domyślnie) = `<folder aplikacji>\data`; ścieżka względna liczona od folderu aplikacji (`$PSScriptRoot`, nie bieżący katalog); bezwzględna (dysk lub UNC) może zawierać zmienne środowiskowe. Zna go wyłącznie `Get-MwpDataPath` (`-Kind Root|Logs|Undo|Fallback`, `-Detailed`). Katalog niezapisywalny (próba utworzenia i usunięcia pliku, wynik pamiętany do końca procesu) lub ścieżka niepoprawna → tryb zapasowy `%LOCALAPPDATA%\MyWindowsPower` z ostrzeżeniem w wyniku i w logu (`DataPath.Fallback`, raz na proces). W trybie zapasowym także `settings.local.json` (gdy folder `config` jest niezapisywalny; istniejący plik w `config` ma pierwszeństwo). Bez automatycznej migracji starych danych. Moduły z paczek zostają w `src/Modules/Installed` do FAZY 4.
- Logi (D-026, D-032): `<katalog danych>\logs\mwp-RRRR-MM-DD.log`, jeden wpis JSON na linię (UTF-8 bez BOM): `timestamp`, `level`, `computer`, `source`, `operation`, `message`, `user`, `processId`, opcjonalnie `data`. Próg `logLevel` (Debug/Info/Warning/Error), rotacja przy pierwszym wpisie dnia wg `logRetentionDays`. Operacje na komputerze zdalnym są logowane na hoście z nazwą komputera. Chwilowa blokada pliku (np. OneDrive) → do 5 ponowień (ok. 1,5 s), potem ostrzeżenie bez przerywania operacji.
- Rejestr cofnięć (D-028, D-032): `<katalog danych>\undo\<GUID>.json`.
- Konfiguracja użytkownika: `config/settings.local.json` (poza repozytorium; w trybie zapasowym `%LOCALAPPDATA%\MyWindowsPower\settings.local.json`, D-032); szablon `config/settings.example.json` z polem `schemaVersion` jest jednocześnie źródłem wartości domyślnych (D-025). Od FAZY 3 zawiera sekcję `targets` (komputery docelowe: `localhost` i zdalne); nazwy prawdziwych komputerów, adresy i poświadczenia nigdy nie trafiają do repozytorium ani do szablonu.
- Zasady (D-015, wdrożone w FAZIE 2, D-025): zapis atomowy (plik tymczasowy, potem `File.Replace`/`File.Move`); uszkodzony plik nie blokuje startu — wartości domyślne, ostrzeżenie i log, a plik zostaje zachowany jako `settings.local.json.corrupt-RRRRMMDD-GGmmss`; nowsza `schemaVersion` niż obsługiwana → wartości domyślne, plik bez zmian; starsza → migracje krok po kroku (`Invoke-MwpSettingsMigration`); `Set-MwpSetting` przyjmuje tylko klucze z szablonu i wartość zgodnego typu.

## Testy

- Pester dla modułów logiki; GUI testowane ręcznie wg checklist w plikach faz.
- Testy nie mogą zmieniać realnego systemu: używaj mocków i `-WhatIf`.
- Uruchamianie: `.\tests\Invoke-Checks.ps1` (opcje `-SkipAnalyzer`, `-SkipTests`); kod wyjścia 0 = analiza bez uwag i wszystkie testy zaliczone.
- Pliki testów zaczynają się od `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }` i atrybutu tłumiącego `PSUseDeclaredVarsMoreThanAssignments` (zakresy Pestera).

## Testy architektoniczne (FAZY 3–5 dodają je stopniowo, FAZA 20 domyka)

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
