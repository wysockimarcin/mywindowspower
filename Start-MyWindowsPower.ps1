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
    - importuje moduły z src/Modules (najpierw MWP.Core).

    Launcher niczego nie zmienia w systemie. Okno GUI powstanie w FAZIE 3.

.PARAMETER NoRelaunch
    Wyłącza ponowne uruchomienie w trybie STA. Ustawiany automatycznie przy ponownym
    uruchomieniu, żeby nie dopuścić do pętli.

.OUTPUTS
    Kod wyjścia 0, gdy wszystkie moduły się zaimportowały; 1 w przypadku błędu.

.EXAMPLE
    .\Start-MyWindowsPower.ps1
#>
[CmdletBinding()]
param(
    [switch] $NoRelaunch
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
    & $environment.HostPath -NoProfile -STA -File $PSCommandPath -NoRelaunch
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

# MWP.Core jako pierwszy, bo pozostałe moduły będą z niego korzystać.
$moduleDirs = @(Get-ChildItem -LiteralPath $modulesRoot -Directory -Filter 'MWP.*' |
        Sort-Object -Property @{ Expression = { $_.Name -ne 'MWP.Core' } }, Name)

$failed = 0
foreach ($dir in $moduleDirs) {
    $manifest = Join-Path -Path $dir.FullName -ChildPath ($dir.Name + '.psd1')
    try {
        Import-Module -Name $manifest -Force -ErrorAction Stop
        Write-LauncherMessage ("  [OK]   {0}" -f $dir.Name) -Level Ok
    }
    catch {
        $failed++
        Write-LauncherMessage ("  [BŁĄD] {0}: {1}" -f $dir.Name, $_.Exception.Message) -Level Error
    }
}

if ($failed -gt 0) {
    Write-LauncherMessage ("Nie udało się zaimportować modułów: {0} z {1}." -f $failed, $moduleDirs.Count) -Level Error
    exit 1
}

Write-LauncherMessage ("Zaimportowano moduły: {0}." -f $moduleDirs.Count) -Level Ok
Write-LauncherMessage 'Okno aplikacji (GUI) zostanie dodane w FAZIE 3.'
exit 0
