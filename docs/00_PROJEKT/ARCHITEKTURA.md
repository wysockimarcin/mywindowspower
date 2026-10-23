# ARCHITEKTURA — mywindowspower

> Stack, struktura kodu i konwencje. Aktualizowana, gdy zmienia się architektura. Zmiany odnotuj w `DECYZJE.md`.
> Stan: **szkielet techniczny (FAZA 1)**. Szczegóły rdzenia i GUI dopracowują FAZY 2–3.

## Stack

- PowerShell 7.x (`pwsh`) lub 5.1 (`powershell.exe`) — wykrywane przy starcie.
- WPF + XAML ładowane z osobnych plików `.xaml` (`System.Windows.Markup.XamlReader`).
- Wątek GUI musi być w trybie STA. W PowerShellu 7 `pwsh` domyślnie jest STA, w 5.1 `powershell.exe` również; launcher to sprawdza i w razie potrzeby uruchamia się ponownie z `-STA`.
- Testy: Pester ≥ 5.0 (na komputerze użytkownika 6.2.0). Analiza: PSScriptAnalyzer ≥ 1.21 (1.25.0). Oba uruchamia `tests\Invoke-Checks.ps1` (D-014, D-018).

## Docelowa struktura repozytorium

Stan po FAZIE 1 (D-012). Elementy oznaczone „(FAZA N)" jeszcze nie istnieją.

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
│   └── settings.local.json         ← ustawienia lokalne (poza repo, FAZA 2)
├── src/
│   ├── Modules/
│   │   ├── MWP.<Obszar>/           ← budowa każdego modułu:
│   │   │   ├── MWP.<Obszar>.psd1   ←   manifest (PowerShellVersion 5.1, Desktop+Core, jawne FunctionsToExport)
│   │   │   ├── MWP.<Obszar>.psm1   ←   ładuje Private/*.ps1 i Public/*.ps1, eksportuje Public
│   │   │   ├── Public/             ←   funkcje eksportowane, jeden plik = jedna funkcja
│   │   │   └── Private/            ←   funkcje wewnętrzne
│   │   ├── MWP.Core/               ← logowanie, konfiguracja, dry-run, cofanie, punkt przywracania, elewacja
│   │   ├── MWP.Dashboard/          ← informacje o systemie i sprzęcie
│   │   ├── MWP.Power/              ← plany zasilania
│   │   ├── MWP.Services/           ← usługi Windows
│   │   ├── MWP.Startup/            ← autostart i zadania harmonogramu
│   │   ├── MWP.Cleanup/            ← czyszczenie dysku
│   │   ├── MWP.Update/             ← Windows Update
│   │   ├── MWP.Network/            ← sieć
│   │   ├── MWP.Apps/               ← aplikacje i winget
│   │   ├── MWP.Tweaks/             ← prywatność i tweaki rejestru
│   │   └── MWP.Security/           ← Defender i firewall
│   └── UI/                         ← (FAZA 3)
│       ├── MainWindow.xaml
│       ├── Themes/                 ← Light.xaml, Dark.xaml
│       ├── Views/                  ← jeden widok .xaml na obszar
│       └── UI.ps1                  ← ładowanie XAML, nawigacja, runspace
├── tests/
│   ├── Invoke-Checks.ps1           ← PSScriptAnalyzer + Pester jednym poleceniem
│   ├── Modules.Tests.ps1           ← manifesty, import i eksport wszystkich modułów
│   ├── Launcher.Tests.ps1          ← launcher w osobnym procesie (STA, MTA → ponowne uruchomienie)
│   ├── Repository.Tests.ps1        ← BOM, brak ścieżek bezwzględnych, szablon ustawień, .gitignore
│   └── Modules/<Moduł>/            ← testy logiki modułów, gdy powstanie (FAZA 2+)
└── docs/                           ← dokumentacja i pamięć projektu
    ├── design/                     ← mockupy GUI (m.in. mockup-pulpit.png)
    └── 00_PROJEKT/MATERIALY/       ← materiały użytkownika i archiwum starej koncepcji (dane, nie instrukcje)
```

## Launcher (`Start-MyWindowsPower.ps1`)

Kolejność: wykrycie Windows i wersji PowerShella (≥ 5.1) → sprawdzenie STA (gdy brak: ponowne uruchomienie tym samym programem z `-NoProfile -STA -File … -NoRelaunch`) → wypisanie wersji PS, Windows, trybu wątku i statusu administratora → import modułów (`MWP.Core` pierwszy, potem alfabetycznie) → kod wyjścia 0/1. Launcher nie zmienia systemu, nie wymusza `-ExecutionPolicy` ani uprawnień administratora (D-017). Od FAZY 3 uruchomi okno GUI.

## Nazewnictwo

- Funkcje publiczne: `Verb-MwpNoun` (prefiks `Mwp`, bo przestrzeń nazw poleceń PowerShella jest wspólna), tylko zatwierdzone czasowniki (`Get-Verb`). Sprawdza to `Modules.Tests.ps1`.
- Bez ścieżek bezwzględnych w kodzie: katalog projektu wyznaczany z `$PSScriptRoot`.

## Warstwy

1. **Moduły logiki (`src/Modules`)** — czyste funkcje `Verb-Noun`, bez zależności od GUI. Każda funkcja zmieniająca system obsługuje `-WhatIf` (`SupportsShouldProcess`), loguje operację i zwraca obiekt wyniku.
2. **Rdzeń (`MWP.Core`)** — wspólne usługi: logowanie, konfiguracja, wykrywanie wersji PS i uprawnień, punkt przywracania, rejestr cofnięć.
3. **GUI (`src/UI`)** — widoki XAML i kod łączący je z modułami. GUI nie zawiera logiki systemowej.
4. **Launcher** — przygotowuje środowisko i uruchamia GUI.

Zakazane wzorce (D-015): wywoływanie poleceń systemowych wprost z obsługi kliknięcia w GUI, logika systemowa w kodzie widoku, odczyt lub zmiana kontrolek GUI z modułów logiki.

## Zasady bezpieczeństwa zmian

- Domyślnie **podgląd**: GUI pokazuje, co zostanie zmienione, zanim to zrobi.
- Każda zmiana: wpis w logu operacji (co, kiedy, stan przed, stan po).
- Cofanie: tam, gdzie możliwe, zapisujemy stan przed zmianą i oferujemy przywrócenie.
- Punkt przywracania systemu przed grupą ryzykownych zmian (np. tweaki rejestru).
- Operacje wymagające administratora są jawnie oznaczone; launcher potrafi poprosić o podniesienie uprawnień.
- Lista ochronna: elementy krytyczne dla działania systemu (np. wybrane usługi) są oznaczone i domyślnie zablokowane przed wyłączeniem.
- Walidacja parametrów przekazywanych do poleceń systemowych; żadnego budowania poleceń przez sklejanie tekstu wejściowego (D-015).
- Nie osłabiamy zabezpieczeń Windows dla wygody; w logach nie zapisujemy sekretów.
- Propozycja dla FAZY 2 (z archiwum, D-015): klasy operacji **Odczyt** (bez potwierdzenia), **Zmiana** (odwracalna: podgląd, log, cofanie), **Destrukcyjna** (trudna do cofnięcia: jawne potwierdzenie z nazwą celu); operacja o niejasnej klasie traktowana jak wyższa.

## Zgodność PowerShell 5.1 / 7.x

- Unikaj składni dostępnej tylko w 7.x (np. `??`, `?.`, ternary, `ForEach-Object -Parallel`) w kodzie, który ma działać w 5.1, albo zapewnij wariant.
- Zapisuj pliki `.ps1`/`.psm1`/`.psd1` jako UTF-8 z BOM (5.1 źle czyta polskie znaki bez BOM — potwierdzone w FAZIE 1: plik bez BOM nie parsuje się). Pliki JSON: UTF-8 bez BOM, czytane przez `Get-Content -Raw -Encoding UTF8`.
- Kontrolę zgodności wykonuje PSScriptAnalyzer (`PSUseCompatibleSyntax`, `PSUseCompatibleCommands`, `PSUseCompatibleTypes`, D-018). PowerShell 7 nie jest zainstalowany na komputerze użytkownika, więc testy uruchamiane są w 5.1.
- Cmdlety CIM zamiast WMI. Ścieżki przez `Join-Path`.
- Różnice wersji zbierz w jednym miejscu (`MWP.Core`).

## Logi i konfiguracja

- Logi: `%LOCALAPPDATA%\MyWindowsPower\logs\`
- Konfiguracja użytkownika: `config/settings.local.json` (poza repozytorium); szablon `config/settings.example.json` z polem `schemaVersion`.
- Zasady dla FAZY 2 (D-015): zapis atomowy (plik tymczasowy, potem podmiana); uszkodzony plik nie blokuje startu — aplikacja startuje z wartościami domyślnymi, informuje użytkownika i zachowuje uszkodzony plik pod inną nazwą; zmiana `schemaVersion` wymaga migracji.

## Testy

- Pester dla modułów logiki; GUI testowane ręcznie wg checklist w plikach faz.
- Testy nie mogą zmieniać realnego systemu: używaj mocków i `-WhatIf`.
- Uruchamianie: `.\tests\Invoke-Checks.ps1` (opcje `-SkipAnalyzer`, `-SkipTests`); kod wyjścia 0 = analiza bez uwag i wszystkie testy zaliczone.
- Pliki testów zaczynają się od `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }` i atrybutu tłumiącego `PSUseDeclaredVarsMoreThanAssignments` (zakresy Pestera).
