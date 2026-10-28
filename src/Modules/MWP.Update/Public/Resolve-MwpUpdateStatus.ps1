function Resolve-MwpUpdateStatus {
    <#
    .SYNOPSIS
        Zamienia surowy wynik odczytu stanu Windows Update (Get-MwpUpdateStatus -AsOperation, blok Status) na obiekt MWP.UpdateStatus.

    .DESCRIPTION
        Czysta funkcja (bez wywołań na komputerze docelowym): przyjmuje tekst JSON, MWP.Result
        z operacji w tle albo obiekt surowy; gotowy MWP.UpdateStatus jest zwracany bez zmian.
        Pauza (MWP.UpdatePause) jest aktywna, gdy PauseUpdatesExpiryTime (albo koniec pauzy aktualizacji
        jakościowych) jest późniejszy niż -Now. Zasady grupy z wartościami pauzy lub blokadą przycisku
        pauzy dają ostrzeżenie (Ustawienia mogą wtedy pokazać „zarządzane przez organizację”).
        Zwraca $null, gdy danych nie ma.

    .PARAMETER Now
        Bieżący czas (testy); domyślnie Get-Date.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data,

        [datetime] $Now = (Get-Date)
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.UpdateStatus') {
        return $Data
    }
    $raw = ConvertFrom-MwpUpdateJson -Data $Data -Kind 'MWP.UpdateStatusRaw'
    if ($null -eq $raw) {
        return $null
    }
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($warning in @($raw.Warnings | Where-Object { $_ })) {
        $warnings.Add([string]$warning)
    }

    $services = @(foreach ($item in @($raw.Services | Where-Object { $null -ne $_ })) {
            $status = ([string]$item.State) -replace '\s', ''
            $startupType = switch ([string]$item.StartMode) {
                'Auto' { if ($item.Delayed) { 'AutomaticDelayedStart' } else { 'Automatic' } }
                'Manual' { 'Manual' }
                'Disabled' { 'Disabled' }
                default { 'Unknown' }
            }
            [pscustomobject]@{
                PSTypeName      = 'MWP.UpdateService'
                Name            = [string]$item.Name
                DisplayName     = [string]$item.DisplayName
                Status          = $status
                StatusText      = Get-MwpUpdateText -Kind ServiceStatus -Value $status
                StartupType     = $startupType
                StartupTypeText = $(if ($status -eq 'Missing') { '' } else { Get-MwpUpdateText -Kind StartupType -Value $startupType })
            }
        })
    foreach ($service in $services) {
        if ($service.Status -eq 'Missing') {
            $warnings.Add(('Brak usługi {0} na komputerze docelowym.' -f $service.Name))
        }
        elseif ($service.StartupType -eq 'Disabled' -and $service.Name -in 'wuauserv', 'bits', 'cryptsvc') {
            $warnings.Add(('Usługa {0} ({1}) jest wyłączona — Windows Update nie będzie działać.' -f $service.DisplayName, $service.Name))
        }
    }

    $values = @{}
    if ($null -ne $raw.Pause) {
        foreach ($property in $raw.Pause.PSObject.Properties) {
            $values[$property.Name] = ConvertTo-MwpUpdatePauseText -Value $property.Value
        }
    }
    $pause = Resolve-MwpUpdatePause -Values $values -Now $Now

    $policies = @()
    if ($null -ne $raw.Policy) {
        $policies = @(foreach ($property in $raw.Policy.PSObject.Properties) {
                if ($null -ne $property.Value -and [string]$property.Value -ne '') {
                    '{0} = {1}' -f $property.Name, $property.Value
                }
            })
    }
    if ($policies.Count -gt 0) {
        $warnings.Add(('Zasady grupy Windows Update dotyczące pauzy ({0}) mają pierwszeństwo przed pauzą z aplikacji i Ustawień.' -f ($policies -join '; ')))
    }

    $rebootSources = New-Object -TypeName System.Collections.Generic.List[string]
    if ($true -eq $raw.RebootRequired) {
        $rebootSources.Add('Windows Update Agent (Microsoft.Update.SystemInfo)')
    }
    foreach ($key in @($raw.RebootKeys | Where-Object { $_ })) {
        if ([string]$key -like '*RebootRequired') {
            $rebootSources.Add('Windows Update (klucz RebootRequired)')
        }
        elseif ([string]$key -like '*RebootPending') {
            $rebootSources.Add('obsługa składników (klucz RebootPending)')
        }
        else {
            $rebootSources.Add([string]$key)
        }
    }
    $rebootRequired = if ($rebootSources.Count -gt 0) { $true } elseif ($null -eq $raw.RebootRequired) { $null } else { $false }

    $lastSearch = ConvertFrom-MwpUpdateDate -Value $raw.LastSearch
    $lastInstall = ConvertFrom-MwpUpdateDate -Value $raw.LastInstall
    $backups = @(foreach ($group in @($raw.Backups | Where-Object { $null -ne $_ -and [string]$_.Suffix -match '^mwp-\d{8}-\d{6}$' } | Group-Object -Property Suffix)) {
            [pscustomobject]@{
                PSTypeName = 'MWP.UpdateResetBackup'
                Suffix     = [string]$group.Name
                Folders    = @($group.Group | ForEach-Object { [string]$_.Folder })
                Paths      = @($group.Group | ForEach-Object { [string]$_.Path })
                CreatedAt  = ConvertFrom-MwpUpdateDate -Value (@($group.Group)[0].CreatedAt)
            }
        })

    [pscustomobject]@{
        PSTypeName      = 'MWP.UpdateStatus'
        Kind            = 'MWP.UpdateStatus'
        ComputerName    = [string]$raw.ComputerName
        CollectedAt     = ConvertFrom-MwpUpdateDate -Value $raw.CollectedAt
        IsAdministrator = $raw.IsAdministrator
        Services        = $services
        RebootRequired  = $rebootRequired
        RebootSources   = $rebootSources.ToArray()
        RebootText      = $(if ($true -eq $rebootRequired) { 'Wymagany restart: ' + ($rebootSources -join ', ') + '.' } elseif ($false -eq $rebootRequired) { 'Restart nie jest wymagany.' } else { 'Nie udało się sprawdzić, czy restart jest wymagany.' })
        LastSearch      = $lastSearch
        LastInstall     = $lastInstall
        LastSearchText  = $(if ($null -ne $lastSearch) { $lastSearch.ToString('yyyy-MM-dd HH:mm') } else { 'brak danych' })
        LastInstallText = $(if ($null -ne $lastInstall) { $lastInstall.ToString('yyyy-MM-dd HH:mm') } else { 'brak danych' })
        Pause           = $pause
        PauseText       = $pause.Text
        Policies        = $policies
        Backups         = @($backups | Sort-Object -Property Suffix -Descending)
        Warnings        = $warnings.ToArray()
    }
}
