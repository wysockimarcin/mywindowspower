function Get-MwpUpdateTargetConfig {
    <#
    .SYNOPSIS
        Zwraca stałe miejsca Windows Update na komputerze docelowym: klucze rejestru pauzy, zasad i restartu, usługi i foldery resetu.

    .DESCRIPTION
        Jedno miejsce z kluczami i folderami używanymi przez bloki Get-MwpUpdateScript (dane przez
        parametry, D-036). Klucze pauzy to te same wartości, które zapisuje przycisk „Wstrzymaj”
        w Ustawieniach Windows 11 (HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings, D-048).
        WindowsRoot pusty = %SystemRoot% komputera docelowego (testy podmieniają go na TestDrive,
        a klucze — na TestRegistry). Foldery resetu są stałe (ścieżki względne od WindowsRoot);
        nic nie pochodzi z danych użytkownika (D-015).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    [pscustomobject]@{
        PauseKey         = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
        PauseValues      = @(
            'PauseUpdatesStartTime', 'PauseUpdatesExpiryTime',
            'PauseFeatureUpdatesStartTime', 'PauseFeatureUpdatesEndTime',
            'PauseQualityUpdatesStartTime', 'PauseQualityUpdatesEndTime'
        )
        PolicyKey        = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        PolicyValues     = @('SetDisablePauseUXAccess', 'PauseQualityUpdates', 'PauseQualityUpdatesStartTime', 'PauseFeatureUpdates', 'PauseFeatureUpdatesStartTime')
        RebootKeys       = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        )
        WindowsRoot      = ''
        Services         = @('wuauserv', 'bits', 'cryptsvc', 'usosvc')
        # Kolejność zatrzymania przy resecie; usosvc jest opcjonalna (błąd zatrzymania = ostrzeżenie).
        ResetServices    = @('usosvc', 'wuauserv', 'bits', 'cryptsvc')
        OptionalServices = @('usosvc')
        ResetFolders     = @(
            [pscustomobject]@{ Name = 'SoftwareDistribution'; RelativePath = 'SoftwareDistribution' }
            [pscustomobject]@{ Name = 'catroot2'; RelativePath = 'System32\catroot2' }
        )
    }
}
