# ARCHITEKTURA — mywindowspower

> Stack, struktura kodu i konwencje. Aktualizowana, gdy zmienia się architektura. Zmiany odnotuj w `DECYZJE.md`.
> Stan: **założenia projektowe (FAZA 0)**. Szczegóły dopracowują FAZY 1–3.

## Stack

- PowerShell 7.x (`pwsh`) lub 5.1 (`powershell.exe`) — wykrywane przy starcie.
- WPF + XAML ładowane z osobnych plików `.xaml` (`System.Windows.Markup.XamlReader`).
- Wątek GUI musi być w trybie STA. W PowerShellu 7 `pwsh` domyślnie jest STA, w 5.1 `powershell.exe` również; launcher to sprawdza i w razie potrzeby uruchamia się ponownie z `-STA`.
- Testy: Pester (5.x). Analiza: PSScriptAnalyzer.

## Docelowa struktura repozytorium

```
mywindowspower/
├── CLAUDE.md
├── README.md
├── .gitignore
├── Start-MyWindowsPower.ps1        ← launcher (STA, wersja PS, elewacja, import modułów)
├── config/
│   ├── settings.example.json       ← szablon ustawień (do repo)
│   └── settings.local.json         ← ustawienia lokalne (poza repo)
├── src/
│   ├── Modules/
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
│   └── UI/
│       ├── MainWindow.xaml
│       ├── Themes/                 ← Light.xaml, Dark.xaml
│       ├── Views/                  ← jeden widok .xaml na obszar
│       └── UI.ps1                  ← ładowanie XAML, nawigacja, runspace
├── tests/                          ← Pester (lustrzana struktura do src/)
└── docs/                           ← dokumentacja i pamięć projektu
```

Nazwa i układ mogą zostać skorygowane w FAZIE 1 (wpis w `DECYZJE.md`).

## Warstwy

1. **Moduły logiki (`src/Modules`)** — czyste funkcje `Verb-Noun`, bez zależności od GUI. Każda funkcja zmieniająca system obsługuje `-WhatIf` (`SupportsShouldProcess`), loguje operację i zwraca obiekt wyniku.
2. **Rdzeń (`MWP.Core`)** — wspólne usługi: logowanie, konfiguracja, wykrywanie wersji PS i uprawnień, punkt przywracania, rejestr cofnięć.
3. **GUI (`src/UI`)** — widoki XAML i kod łączący je z modułami. GUI nie zawiera logiki systemowej.
4. **Launcher** — przygotowuje środowisko i uruchamia GUI.

## Zasady bezpieczeństwa zmian

- Domyślnie **podgląd**: GUI pokazuje, co zostanie zmienione, zanim to zrobi.
- Każda zmiana: wpis w logu operacji (co, kiedy, stan przed, stan po).
- Cofanie: tam, gdzie możliwe, zapisujemy stan przed zmianą i oferujemy przywrócenie.
- Punkt przywracania systemu przed grupą ryzykownych zmian (np. tweaki rejestru).
- Operacje wymagające administratora są jawnie oznaczone; launcher potrafi poprosić o podniesienie uprawnień.
- Lista ochronna: elementy krytyczne dla działania systemu (np. wybrane usługi) są oznaczone i domyślnie zablokowane przed wyłączeniem.

## Zgodność PowerShell 5.1 / 7.x

- Unikaj składni dostępnej tylko w 7.x (np. `??`, `?.`, ternary, `ForEach-Object -Parallel`) w kodzie, który ma działać w 5.1, albo zapewnij wariant.
- Zapisuj pliki `.ps1`/`.psm1` jako UTF-8 z BOM (5.1 źle czyta polskie znaki bez BOM).
- Cmdlety CIM zamiast WMI. Ścieżki przez `Join-Path`.
- Różnice wersji zbierz w jednym miejscu (`MWP.Core`).

## Logi i konfiguracja

- Logi: `%LOCALAPPDATA%\MyWindowsPower\logs\`
- Konfiguracja użytkownika: `config/settings.local.json` (poza repozytorium)

## Testy

- Pester dla modułów logiki; GUI testowane ręcznie wg checklist w plikach faz.
- Testy nie mogą zmieniać realnego systemu: używaj mocków i `-WhatIf`.
