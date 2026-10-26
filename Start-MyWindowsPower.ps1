#Requires -Version 5.1
<#
.SYNOPSIS
    Uruchamia panel MyWindowsPower.

.DESCRIPTION
    Launcher przygotowuje środowisko i ładuje moduły aplikacji:
    - wykrywa wersję PowerShella (Windows PowerShell 5.1 lub PowerShell 7.x),
    - sprawdza system (Windows 11; starsze wersje tylko z ostrzeżeniem),
    - sprawdza tryb STA wymagany przez WPF i w razie potrzeby uruchamia się ponownie z -STA,
    - wypisuje status uprawnień administratora,
    - importuje moduły z src/Modules (najpierw MWP.Core), a po nich moduły zainstalowane z paczek
      (<katalog danych>/modules oraz dawny src/Modules/Installed, D-031, D-038), sprawdzając kontrakt
      każdego modułu (Get-MwpModuleDefinition: wersja hosta, zależności); moduł z błędnym kontraktem
      nie jest ładowany,
    - z parametrem -Elevate uruchamia się ponownie z uprawnieniami administratora (monit UAC),
    - otwiera okno GUI hosta modułów (src/UI/UI.ps1, FAZA 4), chyba że podano -NoGui.

    Launcher niczego nie zmienia w systemie.

.PARAMETER NoRelaunch
    Wyłącza ponowne uruchomienie w trybie STA. Ustawiany automatycznie przy ponownym
    uruchomieniu, żeby nie dopuścić do pętli.

.PARAMETER Elevate
    Prosi o uprawnienia administratora: gdy ich brak, uruchamia launcher ponownie przez UAC
    (Request-MwpElevation) i kończy bieżący proces.

.PARAMETER NoGui
    Tylko przygotowanie środowiska i import modułów, bez okna (testy, diagnostyka w konsoli).

.OUTPUTS
    Kod wyjścia 0, gdy wszystkie moduły się zaimportowały i okno zamknięto normalnie; 1 w przypadku błędu.

.EXAMPLE
    .\Start-MyWindowsPower.ps1

.EXAMPLE
    .\Start-MyWindowsPower.ps1 -Elevate

.EXAMPLE
    .\Start-MyWindowsPower.ps1 -NoGui
#>
[CmdletBinding()]
param(
    [switch] $NoRelaunch,

    [switch] $Elevate,

    [switch] $NoGui
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-LauncherMessage {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Launcher wypisuje komunikaty dla użytkownika w konsoli, z kolorami.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Message,

        [ValidateSet('Info', 'Ok', 'Warning', 'Error')]
        [string] $Level = 'Info'
    )

    $colors = @{ Info = 'Gray'; Ok = 'Green'; Warning = 'Yellow'; Error = 'Red' }
    Write-Host $Message -ForegroundColor $colors[$Level]
}

function Get-LauncherEnvironment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    # W 5.1 zmienna $IsWindows nie istnieje, a edycja Desktop działa tylko na Windows.
    $onWindows = $PSVersionTable.PSEdition -eq 'Desktop'
    if (-not $onWindows -and (Test-Path -LiteralPath 'Variable:IsWindows')) {
        $onWindows = Get-Variable -Name IsWindows -ValueOnly
    }

    $isAdmin = $false
    $osBuild = 0
    if ($onWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $osBuild = [Environment]::OSVersion.Version.Build
    }

    [pscustomobject]@{
        PSVersion      = $PSVersionTable.PSVersion
        PSEdition      = $PSVersionTable.PSEdition
        IsWindows      = $onWindows
        OSVersion      = [Environment]::OSVersion.Version
        IsWindows11    = $onWindows -and ($osBuild -ge 22000)
        IsAdmin        = $isAdmin
        ApartmentState = [Threading.Thread]::CurrentThread.GetApartmentState()
        HostPath       = (Get-Process -Id $PID).Path
    }
}

$environment = Get-LauncherEnvironment

if (-not $environment.IsWindows) {
    Write-LauncherMessage 'MyWindowsPower działa tylko w systemie Windows.' -Level Error
    exit 1
}

$psVersion = $environment.PSVersion
if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
    Write-LauncherMessage ("Wymagany jest PowerShell 5.1 lub 7.x. Wykryto: {0}." -f $psVersion) -Level Error
    exit 1
}

# WPF wymaga wątku STA. powershell.exe 5.1 i pwsh 7 domyślnie startują w STA,
# ale można je uruchomić z -MTA; wtedy launcher uruchamia się ponownie.
if ($environment.ApartmentState -ne [Threading.ApartmentState]::STA) {
    if ($NoRelaunch) {
        Write-LauncherMessage 'Wątek nie działa w trybie STA, a ponowne uruchomienie jest wyłączone (-NoRelaunch). Okno WPF nie będzie działać.' -Level Error
        exit 1
    }

    Write-LauncherMessage 'Wątek nie działa w trybie STA. Ponowne uruchomienie z parametrem -STA...' -Level Warning
    $relaunchArguments = @('-NoRelaunch')
    if ($Elevate) {
        $relaunchArguments += '-Elevate'
    }
    if ($NoGui) {
        $relaunchArguments += '-NoGui'
    }
    & $environment.HostPath -NoProfile -STA -File $PSCommandPath @relaunchArguments
    exit $LASTEXITCODE
}

Write-LauncherMessage 'MyWindowsPower — uruchamianie' -Level Info
Write-LauncherMessage ("PowerShell: {0} ({1})" -f $psVersion, $environment.PSEdition)
$osName = if ($environment.IsWindows11) { 'Windows 11' } else { 'Windows starszy niż 11' }
Write-LauncherMessage ("Windows: {0} ({1})" -f $environment.OSVersion, $osName)
Write-LauncherMessage ("Tryb wątku: {0}" -f $environment.ApartmentState)
if ($environment.IsAdmin) {
    Write-LauncherMessage 'Administrator: tak'
}
else {
    Write-LauncherMessage 'Administrator: nie (operacje wymagające uprawnień poproszą o nie osobno)'
}

if (-not $environment.IsWindows11) {
    Write-LauncherMessage 'Uwaga: to nie jest Windows 11. Aplikacja nie jest testowana na tym systemie.' -Level Warning
}

$modulesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'src\Modules'
if (-not (Test-Path -LiteralPath $modulesRoot)) {
    Write-LauncherMessage ("Nie znaleziono folderu modułów: {0}" -f $modulesRoot) -Level Error
    exit 1
}

# MWP.Core jako pierwszy, bo pozostałe moduły z niego korzystają i to on odkrywa moduły (kontrakt,
# katalogi modułów wbudowanych i z paczek: Get-MwpModuleDefinition, D-031, D-038).
$coreManifest = Join-Path -Path $modulesRoot -ChildPath 'MWP.Core\MWP.Core.psd1'
try {
    Import-Module -Name $coreManifest -Force -ErrorAction Stop
    $definitions = @(Get-MwpModuleDefinition)
    $core = @($definitions | Where-Object { $_.ModuleName -eq 'MWP.Core' }) | Select-Object -First 1
    if ($null -ne $core -and -not $core.IsValid) {
        throw ("niepoprawny kontrakt modułu: {0}" -f ($core.Errors -join ' '))
    }
    Write-LauncherMessage '  [OK]   MWP.Core' -Level Ok
}
catch {
    Write-LauncherMessage ("  [BŁĄD] MWP.Core: {0}" -f $_.Exception.Message) -Level Error
    exit 1
}

# Pozostałe moduły: wbudowane alfabetycznie, potem z paczek.
$others = @($definitions | Where-Object { $_.ModuleName -ne 'MWP.Core' } |
        Sort-Object -Property @{ Expression = { $_.Source -eq 'Installed' } }, ModuleName)
$failed = 0
foreach ($definition in $others) {
    try {
        if (-not $definition.IsValid) {
            throw ("niepoprawny kontrakt modułu: {0}" -f ($definition.Errors -join ' '))
        }
        Import-Module -Name $definition.ManifestPath -Force -ErrorAction Stop
        $label = if ($definition.Source -eq 'Installed') { '{0} (z paczki)' -f $definition.ModuleName } else { $definition.ModuleName }
        Write-LauncherMessage ("  [OK]   {0}" -f $label) -Level Ok
    }
    catch {
        $failed++
        Write-LauncherMessage ("  [BŁĄD] {0}: {1}" -f $definition.ModuleName, $_.Exception.Message) -Level Error
    }
}
$moduleCount = $others.Count + 1

if ($failed -gt 0) {
    Write-LauncherMessage ("Nie udało się zaimportować modułów: {0} z {1}." -f $failed, $moduleCount) -Level Error
    exit 1
}

Write-LauncherMessage ("Zaimportowano moduły: {0}." -f $moduleCount) -Level Ok

if ($Elevate) {
    if ($environment.IsAdmin) {
        Write-LauncherMessage 'Uprawnienia administratora są już aktywne.' -Level Ok
    }
    else {
        $elevation = Request-MwpElevation -FilePath $PSCommandPath -HostPath $environment.HostPath
        if (-not $elevation.Success) {
            Write-LauncherMessage $elevation.Message -Level Error
            exit 1
        }
        Write-LauncherMessage $elevation.Message -Level Ok
        exit 0
    }
}

if ($NoGui) {
    Write-LauncherMessage 'Tryb bez okna (-NoGui): moduły załadowane, okno nie zostanie otwarte.'
    exit 0
}

Write-LauncherMessage 'Otwieranie okna aplikacji...'
try {
    $uiResult = @(& (Join-Path -Path $PSScriptRoot -ChildPath 'src\UI\UI.ps1'))
    $exitCode = [int]($uiResult | Select-Object -Last 1)
}
catch {
    Write-LauncherMessage ("Nie udało się otworzyć okna aplikacji: {0}" -f $_.Exception.Message) -Level Error
    exit 1
}
exit $exitCode
