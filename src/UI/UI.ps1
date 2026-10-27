#Requires -Version 5.1
<#
.SYNOPSIS
    Uruchamia okno GUI hosta modułów My Windows Power (FAZA 4).

.DESCRIPTION
    Punkt wejścia warstwy UI, wywoływany przez Start-MyWindowsPower.ps1 po imporcie modułów
    (MWP.Core, MWP.Remote, moduły obszarów i z paczek). Ładuje moduł prezentacji MWP.UI
    (src\UI\MWP.UI.psm1): ładowanie XAML i mapowanie kontrolek (Import-MwpXaml), nawigację
    (Show-MwpView), motywy, zadania w tle i instancje modułów — i otwiera okno główne (Start-MwpUi).
    Kod okna jest modułem, a nie skryptem, bo obsługa zdarzeń WPF wywoływana po zakończeniu
    funkcji musi widzieć funkcje i stan powłoki (D-039).

.PARAMETER StartView
    Widok startowy: dashboard (domyślnie), modules, settings, about albo area:<Id modułu>.

.PARAMETER StartupTiming
    Pomiar startu z launchera (Stopwatch, Stages, ProcessStart) do wpisu Startup.Window (D-042).
    Opcjonalny: bez niego okno nie zapisuje czasu startu.

.OUTPUTS
    Kod wyjścia: 0 — okno zamknięte normalnie, 1 — błąd okna.
#>
[CmdletBinding()]
[OutputType([int])]
param(
    [ValidateNotNullOrEmpty()]
    [string] $StartView = 'dashboard',

    [AllowNull()]
    [hashtable] $StartupTiming
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in @('MWP.Core', 'MWP.Remote')) {
    if ($null -eq (Get-Module -Name $required)) {
        throw ("Moduł {0} nie jest załadowany; uruchom aplikację przez Start-MyWindowsPower.ps1." -f $required)
    }
}

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'MWP.UI.psm1') -Force
$appRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Start-MwpUi -AppRoot $appRoot -StartView $StartView -StartupTiming $StartupTiming
