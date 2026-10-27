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

    Dziennik startu (D-042): po imporcie modułów launcher zapisuje w logu aplikacji (Write-MwpLog, źródło
    Launcher) wpisy Startup.Environment i Startup.Modules, a po pierwszym wyświetleniu okna
    Startup.Window (czas startu z podziałem na etapy). Moduł, który się nie załadował, dostaje osobny
    wpis Startup.Module na poziomie Error. Błędy startu są pokazywane także w oknie komunikatu (bez
    -NoGui), bo w wydaniu konsola jest ukryta. Gdy nie zaimportuje się MWP.Core (nie ma Write-MwpLog),
    błąd trafia do %LOCALAPPDATA%\MyWindowsPower\logs\mwp-startup-failure.log.
    Bez -NoGui launcher pokazuje okno startowe (splash, src\UI\Splash.ps1) z krokowym paskiem postępu
    od importu modułów do pierwszego wyświetlenia okna głównego.

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

    [switch] $NoGui,

    # Ustawiany przez launcher przy ponownym uruchomieniu w trybie STA: poprzedni tryb wątku
    # (do wpisu Startup.Environment, D-042).
    [Parameter(DontShow)]
    [string] $RelaunchReason = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Pomiar czasu startu (D-042): etapy w ms od uruchomienia launchera.
$launcherClock = [Diagnostics.Stopwatch]::StartNew()
$launcherStartedAt = Get-Date
$startupStages = [ordered]@{}

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

function Show-LauncherError {
    <# Okno komunikatu z błędem startu (D-042); nie przy -NoGui (testy). Błąd okna nie przerywa launchera. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Message,

        [switch] $NoGui
    )

    if ($NoGui) {
        return
    }
    try {
        Add-Type -AssemblyName PresentationFramework
        $null = [System.Windows.MessageBox]::Show($Message, 'My Windows Power — błąd uruchamiania',
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
    catch {
        Write-LauncherMessage ("Nie udało się pokazać okna komunikatu: {0}" -f $_.Exception.Message) -Level Warning
    }
}

function Write-LauncherStartupFailure {
    <#
        Awaryjny wpis błędu startu, tylko gdy MWP.Core się nie zaimportował (nie ma Write-MwpLog, D-042):
        jedna linia JSON Lines w %LOCALAPPDATA%\MyWindowsPower\logs\mwp-startup-failure.log (katalog
        zapasowy, D-032). Zwraca ścieżkę pliku albo $null, gdy zapis się nie udał.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Operation,

        [Parameter(Mandatory)]
        [string] $Message
    )

    try {
        if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
            throw 'Zmienna środowiskowa LOCALAPPDATA nie jest ustawiona.'
        }
        $directory = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'MyWindowsPower\logs'
        $null = [IO.Directory]::CreateDirectory($directory)
        $path = Join-Path -Path $directory -ChildPath 'mwp-startup-failure.log'
        $entry = [ordered]@{
            timestamp = (Get-Date).ToString('o')
            level     = 'Error'
            operation = $Operation
            message   = $Message
        }
        $encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        [IO.File]::AppendAllText($path, (ConvertTo-Json -InputObject $entry -Compress) + [Environment]::NewLine, $encoding)
        $path
    }
    catch {
        Write-LauncherMessage ("Nie zapisano awaryjnego wpisu błędu startu: {0}" -f $_.Exception.Message) -Level Warning
        $null
    }
}

function Write-LauncherStartupLog {
    <#
        Zapisuje dziennik startu przez Write-MwpLog (MWP.Core musi być zaimportowany, D-042), w kolejności
        zdarzeń: Startup.Environment, Startup.Module (Error) dla każdego wadliwego modułu, Startup.Modules.
        Przy zdrowym starcie to dokładnie 2 wywołania Write-MwpLog (trzecie, Startup.Window, zapisuje MWP.UI).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $LauncherEnvironment,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Modules,

        [Parameter(Mandatory)]
        [hashtable] $Parameters,

        [string] $RelaunchReason = '',

        [datetime] $StartedAt = (Get-Date)
    )

    $source = $LauncherEnvironment
    if ($null -ne (Get-Command -Name Get-MwpEnvironment -ErrorAction SilentlyContinue)) {
        $source = Get-MwpEnvironment
    }
    $hostVersion = $null
    if ($null -ne $source.PSObject.Properties['HostVersion']) {
        $hostVersion = [string]$source.HostVersion
    }
    $relaunched = -not [string]::IsNullOrEmpty($RelaunchReason)
    $environmentData = [ordered]@{
        EventTime      = $StartedAt.ToString('o')
        PSVersion      = [string]$source.PSVersion
        PSEdition      = [string]$source.PSEdition
        OSVersion      = [string]$source.OSVersion
        IsWindows11    = [bool]$source.IsWindows11
        ApartmentState = [string]$source.ApartmentState
        IsAdmin        = [bool]$source.IsAdmin
        HostPath       = [string]$source.HostPath
        HostVersion    = $hostVersion
        AppRoot        = $PSScriptRoot
        Parameters     = $Parameters
        Relaunched     = $relaunched
        RelaunchReason = $(if ($relaunched) { "Wątek działał w trybie $RelaunchReason; ponowne uruchomienie z -STA (WPF wymaga STA)." } else { $null })
    }
    $osName = if ($environmentData.IsWindows11) { 'Windows 11' } else { 'Windows starszy niż 11' }
    $message = "Środowisko: PowerShell {0} ({1}), Windows {2} ({3}), wątek {4}, administrator: {5}." -f $environmentData.PSVersion,
    $environmentData.PSEdition, $environmentData.OSVersion, $osName, $environmentData.ApartmentState, $(if ($environmentData.IsAdmin) { 'tak' } else { 'nie' })
    if ($relaunched) {
        $message += ' Ponowne uruchomienie w trybie STA (poprzednio {0}).' -f $RelaunchReason
    }
    $level = if ($relaunched -or -not $environmentData.IsWindows11) { 'Warning' } else { 'Info' }
    Write-MwpLog -Level $level -Source 'Launcher' -Operation 'Startup.Environment' -Message $message -Data $environmentData

    $loaded = @($Modules | Where-Object { $_.Status -eq 'Loaded' })
    $failedModules = @($Modules | Where-Object { $_.Status -ne 'Loaded' })
    foreach ($module in $failedModules) {
        Write-MwpLog -Level Error -Source 'Launcher' -Operation 'Startup.Module' `
            -Message ("Nie załadowano modułu {0}: {1}" -f $module.Name, $module.Error) -Data $module
    }

    $fromPackages = @($loaded | Where-Object { $_.Source -eq 'Installed' }).Count
    $importMs = 0
    foreach ($module in $Modules) {
        $importMs += [long]$module.ImportMs
    }
    $summaryData = [ordered]@{
        EventTime = (Get-Date).ToString('o')
        Loaded    = $loaded.Count
        Failed    = $failedModules.Count
        ImportMs  = $importMs
        Modules   = $Modules
    }
    if ($failedModules.Count -eq 0) {
        $summary = "Załadowano moduły: {0} (z paczek: {1}) w {2} ms." -f $loaded.Count, $fromPackages, $importMs
        Write-MwpLog -Level Info -Source 'Launcher' -Operation 'Startup.Modules' -Message $summary -Data $summaryData
    }
    else {
        $summary = "Załadowano moduły: {0} z {1} (z paczek: {2}) w {3} ms; nie załadowano: {4}." -f $loaded.Count, $Modules.Count,
        $fromPackages, $importMs, (($failedModules | ForEach-Object { $_.Name }) -join ', ')
        Write-MwpLog -Level Warning -Source 'Launcher' -Operation 'Startup.Modules' -Message $summary -Data $summaryData
    }
}

function Get-LauncherLogPath {
    <# Ścieżka dzisiejszego pliku logu (do okna komunikatu); $null, gdy nie da się jej ustalić. #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        Join-Path -Path (Get-MwpDataLocation).Logs -ChildPath ('mwp-{0:yyyy-MM-dd}.log' -f (Get-Date))
    }
    catch {
        $null
    }
}

# Wynik importu modułu do dziennika startu (D-042): Startup.Modules (Data) i Startup.Module (Error).
function New-LauncherModuleRecord {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy tylko obiekt w pamięci.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string] $Name,
        [AllowNull()] [object] $Definition,
        [long] $ImportMs,
        [string] $ErrorMessage = ''
    )

    $hasDefinition = $null -ne $Definition
    [pscustomobject]@{
        Name           = $Name
        Version        = $(if ($hasDefinition -and $null -ne $Definition.Version) { [string]$Definition.Version } else { $null })
        Source         = $(if ($hasDefinition -and $Definition.Source -eq 'Installed') { 'Installed' } else { 'Built-in' })
        ImportMs       = $ImportMs
        Status         = $(if ($ErrorMessage -eq '') { 'Loaded' } else { 'Failed' })
        Error          = $(if ($ErrorMessage -eq '') { $null } else { $ErrorMessage })
        ContractErrors = $(if ($hasDefinition -and -not $Definition.IsValid) { @($Definition.Errors) } else { @() })
    }
}

function Step-LauncherSplash {
    <#
        Krok okna startowego (D-042). Błąd okna startowego nie blokuje startu: okno jest zamykane, a
        ostrzeżenie trafia do logu (od razu, gdy jest Write-MwpLog, inaczej po imporcie MWP.Core).
    #>
    [CmdletBinding()]
    param(
        [int] $Step,
        [int] $Total,
        [string] $Status
    )

    if ($null -eq $script:launcherSplash) {
        return
    }
    try {
        Update-MwpSplash -Splash $script:launcherSplash -Step $Step -Total $Total -Status $Status
    }
    catch {
        Add-LauncherSplashWarning -Message ("Błąd okna startowego: {0}" -f $_.Exception.Message)
        Close-LauncherSplash
    }
}

function Close-LauncherSplash {
    <# Zamyka okno startowe, jeśli jest (wielokrotne wywołanie jest bezpieczne). #>
    [CmdletBinding()]
    param()

    if ($null -eq $script:launcherSplash) {
        return
    }
    $splash = $script:launcherSplash
    $script:launcherSplash = $null
    try {
        Close-MwpSplash -Splash $splash
    }
    catch {
        Add-LauncherSplashWarning -Message ("Nie udało się zamknąć okna startowego: {0}" -f $_.Exception.Message)
    }
}

function Add-LauncherSplashWarning {
    <# Ostrzeżenie o oknie startowym: do logu (Startup.Splash) albo do kolejki, gdy MWP.Core jeszcze nie działa. #>
    [CmdletBinding()]
    param([string] $Message)

    Write-LauncherMessage $Message -Level Warning
    if ($null -ne (Get-Command -Name Write-MwpLog -ErrorAction SilentlyContinue)) {
        Write-MwpLog -Level Warning -Source 'Launcher' -Operation 'Startup.Splash' -Message $Message
    }
    else {
        $script:launcherSplashWarnings.Add($Message)
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
    $relaunchArguments = @('-NoRelaunch', '-RelaunchReason', [string]$environment.ApartmentState)
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
# Okno startowe (D-042): po sprawdzeniu STA, przed importem modułów, w tym samym wątku; nie z -NoGui.
$script:launcherSplash = $null
$script:launcherSplashWarnings = New-Object -TypeName System.Collections.Generic.List[string]
if (-not $NoGui) {
    try {
        $uiRoot = Join-Path -Path $PSScriptRoot -ChildPath 'src\UI'
        . (Join-Path -Path $uiRoot -ChildPath 'Splash.ps1')
        $hostVersion = ''
        $versionMatch = [regex]::Match([IO.File]::ReadAllText((Join-Path -Path $modulesRoot -ChildPath 'MWP.Core\MWP.Core.psd1')), "ModuleVersion\s*=\s*'([^']+)'")
        if ($versionMatch.Success) {
            $hostVersion = $versionMatch.Groups[1].Value
        }
        $script:launcherSplash = Show-MwpSplash -UiRoot $uiRoot -Theme (Get-MwpSplashTheme -AppRoot $PSScriptRoot) -Version $hostVersion
    }
    catch {
        $script:launcherSplash = $null
        Add-LauncherSplashWarning -Message ("Nie udało się pokazać okna startowego: {0}" -f $_.Exception.Message)
    }
}
Step-LauncherSplash -Step 0 -Total 1 -Status 'Ładowanie modułów…'

$startupStages['EnvironmentMs'] = $launcherClock.ElapsedMilliseconds
$startupParameters = @{ Elevate = [bool]$Elevate; NoGui = [bool]$NoGui; NoRelaunch = [bool]$NoRelaunch }

$moduleRecords = New-Object -TypeName System.Collections.Generic.List[object]
$coreManifest = Join-Path -Path $modulesRoot -ChildPath 'MWP.Core\MWP.Core.psd1'
$importClock = [Diagnostics.Stopwatch]::StartNew()
$core = $null
try {
    Import-Module -Name $coreManifest -Force -ErrorAction Stop
    $definitions = @(Get-MwpModuleDefinition)
    $core = @($definitions | Where-Object { $_.ModuleName -eq 'MWP.Core' }) | Select-Object -First 1
    if ($null -ne $core -and -not $core.IsValid) {
        throw ("niepoprawny kontrakt modułu: {0}" -f ($core.Errors -join ' '))
    }
    $moduleRecords.Add((New-LauncherModuleRecord -Name 'MWP.Core' -Definition $core -ImportMs $importClock.ElapsedMilliseconds))
    Write-LauncherMessage '  [OK]   MWP.Core' -Level Ok
}
catch {
    $coreError = $_.Exception.Message
    Write-LauncherMessage ("  [BŁĄD] MWP.Core: {0}" -f $coreError) -Level Error
    $boxMessage = "Nie udało się załadować modułu MWP.Core:`n{0}" -f $coreError
    if ($null -ne (Get-Command -Name Write-MwpLog -ErrorAction SilentlyContinue)) {
        # MWP.Core się zaimportował, ale ma błędny kontrakt: zwykły dziennik startu.
        $moduleRecords.Add((New-LauncherModuleRecord -Name 'MWP.Core' -Definition $core -ImportMs $importClock.ElapsedMilliseconds -ErrorMessage $coreError))
        Write-LauncherStartupLog -LauncherEnvironment $environment -Modules $moduleRecords.ToArray() -Parameters $startupParameters `
            -RelaunchReason $RelaunchReason -StartedAt $launcherStartedAt
        $logPath = Get-LauncherLogPath
    }
    else {
        $logPath = Write-LauncherStartupFailure -Operation 'Startup.Module' -Message ("Nie udało się zaimportować modułu MWP.Core: {0}" -f $coreError)
    }
    if ($null -ne $logPath) {
        $boxMessage += "`n`nPlik logu: {0}" -f $logPath
    }
    Close-LauncherSplash
    Show-LauncherError -Message $boxMessage -NoGui:$NoGui
    exit 1
}
$startupStages['CoreImportMs'] = $importClock.ElapsedMilliseconds

# Pozostałe moduły: wbudowane alfabetycznie, potem z paczek.
$importClock.Restart()
$others = @($definitions | Where-Object { $_.ModuleName -ne 'MWP.Core' } |
        Sort-Object -Property @{ Expression = { $_.Source -eq 'Installed' } }, ModuleName)
$failed = 0
$moduleClock = New-Object -TypeName System.Diagnostics.Stopwatch
# Kroki okna startowego: moduły (MWP.Core już jest) + przygotowanie okna głównego.
$splashTotal = $others.Count + 2
$splashStep = 1
foreach ($definition in $others) {
    Step-LauncherSplash -Step $splashStep -Total $splashTotal -Status ("Ładowanie modułów ({0}/{1})…" -f ($splashStep + 1), ($others.Count + 1))
    $splashStep++
    $moduleClock.Restart()
    try {
        if (-not $definition.IsValid) {
            throw ("niepoprawny kontrakt modułu: {0}" -f ($definition.Errors -join ' '))
        }
        Import-Module -Name $definition.ManifestPath -Force -ErrorAction Stop
        $moduleRecords.Add((New-LauncherModuleRecord -Name $definition.ModuleName -Definition $definition -ImportMs $moduleClock.ElapsedMilliseconds))
        $label = if ($definition.Source -eq 'Installed') { '{0} (z paczki)' -f $definition.ModuleName } else { $definition.ModuleName }
        Write-LauncherMessage ("  [OK]   {0}" -f $label) -Level Ok
    }
    catch {
        $failed++
        $moduleRecords.Add((New-LauncherModuleRecord -Name $definition.ModuleName -Definition $definition -ImportMs $moduleClock.ElapsedMilliseconds -ErrorMessage $_.Exception.Message))
        Write-LauncherMessage ("  [BŁĄD] {0}: {1}" -f $definition.ModuleName, $_.Exception.Message) -Level Error
    }
}
$moduleCount = $others.Count + 1
$startupStages['ModulesImportMs'] = $importClock.ElapsedMilliseconds

# Dziennik startu jedną serią (2 wpisy przy zdrowym starcie + 1 na każdy wadliwy moduł, D-042).
$importClock.Restart()
Write-LauncherStartupLog -LauncherEnvironment $environment -Modules $moduleRecords.ToArray() -Parameters $startupParameters `
    -RelaunchReason $RelaunchReason -StartedAt $launcherStartedAt
$startupStages['StartupLogMs'] = $importClock.ElapsedMilliseconds
foreach ($warning in $script:launcherSplashWarnings) {
    Write-MwpLog -Level Warning -Source 'Launcher' -Operation 'Startup.Splash' -Message $warning
}

if ($failed -gt 0) {
    Write-LauncherMessage ("Nie udało się zaimportować modułów: {0} z {1}." -f $failed, $moduleCount) -Level Error
    $lines = @($moduleRecords | Where-Object { $_.Status -ne 'Loaded' } | ForEach-Object { '• {0}: {1}' -f $_.Name, $_.Error })
    $boxMessage = "Nie udało się załadować modułów ({0} z {1}):`n`n{2}" -f $failed, $moduleCount, ($lines -join "`n")
    $logPath = Get-LauncherLogPath
    if ($null -ne $logPath) {
        $boxMessage += "`n`nPlik logu: {0}" -f $logPath
    }
    Close-LauncherSplash
    Show-LauncherError -Message $boxMessage -NoGui:$NoGui
    exit 1
}

Write-LauncherMessage ("Zaimportowano moduły: {0}." -f $moduleCount) -Level Ok

if ($Elevate) {
    if ($environment.IsAdmin) {
        Write-LauncherMessage 'Uprawnienia administratora są już aktywne.' -Level Ok
    }
    else {
        Close-LauncherSplash
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
$startupStages['BeforeWindowMs'] = $launcherClock.ElapsedMilliseconds
# Wpis Startup.Window zapisuje MWP.UI po pierwszym wyświetleniu okna (ContentRendered, D-042).
Step-LauncherSplash -Step ($splashTotal - 1) -Total $splashTotal -Status 'Przygotowanie okna…'
# Okno startowe zamyka MWP.UI po ContentRendered (Close-MwpUiSplash); przy błędzie — launcher.
$startupTiming = @{
    Stopwatch    = $launcherClock
    Stages       = $startupStages
    ProcessStart = (Get-Process -Id $PID).StartTime
    Splash       = $script:launcherSplash
}
try {
    $uiResult = @(& (Join-Path -Path $PSScriptRoot -ChildPath 'src\UI\UI.ps1') -StartupTiming $startupTiming)
    $exitCode = [int]($uiResult | Select-Object -Last 1)
}
catch {
    $message = "Nie udało się otworzyć okna aplikacji: {0}" -f $_.Exception.Message
    Write-LauncherMessage $message -Level Error
    Close-LauncherSplash
    Write-MwpLog -Level Error -Source 'Launcher' -Operation 'Startup.Window' -Message $message `
        -Data @{ ElapsedMs = $launcherClock.ElapsedMilliseconds; Position = $_.InvocationInfo.PositionMessage }
    $logPath = Get-LauncherLogPath
    Show-LauncherError -Message $(if ($null -ne $logPath) { "{0}`n`nPlik logu: {1}" -f $message, $logPath } else { $message }) -NoGui:$NoGui
    exit 1
}
Close-LauncherSplash
if ($exitCode -ne 0) {
    # Start-MwpUi zapisał błąd w logu (Startup.Window przed wyświetleniem okna, potem UI.Start).
    $logPath = Get-LauncherLogPath
    $message = 'Okno aplikacji zakończyło się błędem.'
    Show-LauncherError -Message $(if ($null -ne $logPath) { "{0}`n`nSzczegóły w pliku logu: {1}" -f $message, $logPath } else { $message }) -NoGui:$NoGui
}
exit $exitCode
