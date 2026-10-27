function Compare-MwpServiceProfile {
    <#
    .SYNOPSIS
        Porównuje profil usług z usługami komputera docelowego i zwraca różnice typów uruchomienia (podgląd przed importem).

    .DESCRIPTION
        Odczyt (bez zmian systemu). Dla każdej usługi profilu zwraca wiersz MWP.ServiceProfileDiff:
        Name, DisplayName, Current/CurrentText, Wanted/WantedText, CurrentStatus, ProfileStatus,
        Action i Note. Action: Change (typ do zmiany), Same (bez zmian), Missing (brak usługi na
        komputerze), Protected (usługa chroniona, a profil chce typu ręcznego lub wyłączonego — D-045),
        Blocked (nieznany typ bieżący). Stan usługi jest tylko informacją: import zmienia wyłącznie
        typy uruchomienia. Źródło: odczyt z komputera kontekstu albo gotowa lista (-ServiceList).
        Wiersze Change są na początku.

    .PARAMETER ProfileData
        Profil (MWP.ServiceProfile z Read-MwpServiceProfile albo jej MWP.Result).

    .PARAMETER ServiceList
        Lista usług komputera (MWP.ServiceList albo surowy wynik operacji w tle).

    .EXAMPLE
        (Compare-MwpServiceProfile -ProfileData (Read-MwpServiceProfile .\uslugi.json)).Data | Where-Object Action -eq 'Change'
    #>
    [CmdletBinding(DefaultParameterSetName = 'Context')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object] $ProfileData,

        [Parameter(ParameterSetName = 'Context')]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [object] $ServiceList
    )

    $operation = 'Services.CompareProfile'
    if ($ProfileData.PSObject.TypeNames -contains 'MWP.Result') {
        if (-not $ProfileData.Success) {
            return $ProfileData
        }
        $ProfileData = $ProfileData.Data
    }
    if ($null -eq $ProfileData -or $ProfileData.PSObject.TypeNames -notcontains 'MWP.ServiceProfile') {
        return New-MwpResult -Operation $operation -Success $false -Message 'Profil usług jest niepoprawny (oczekiwany wynik Read-MwpServiceProfile).'
    }
    if ($PSCmdlet.ParameterSetName -eq 'List') {
        $list = Resolve-MwpServiceList -Data $ServiceList
        if ($null -eq $list) {
            return New-MwpResult -Operation $operation -Success $false -Message 'Brak listy usług komputera do porównania z profilem.'
        }
        $computerName = if ($list.ComputerName) { $list.ComputerName } else { 'localhost' }
    }
    else {
        $computerName = $Context.ComputerName
        $read = Get-MwpService -Context $Context
        if (-not $read.Success) {
            return New-MwpResult -Operation $operation -Target $ProfileData.Path -ComputerName $computerName -Success $false -Message $read.Message -ErrorMessage $read.ErrorMessage
        }
        $list = $read.Data
    }

    $byName = @{}
    foreach ($service in @($list.Services)) {
        $byName[$service.Name.ToLowerInvariant()] = $service
    }
    $labels = @{}
    foreach ($type in @(Get-MwpServiceStartupTypeList)) {
        $labels[$type.Id] = $type
    }
    $rows = @(foreach ($item in @($ProfileData.Services)) {
            $current = $byName[$item.Name.ToLowerInvariant()]
            $wanted = $labels[$item.StartupType]
            $action = 'Same'
            $note = ''
            if ($null -eq $current) {
                $action = 'Missing'
                $note = 'Brak usługi na tym komputerze.'
            }
            elseif ($current.StartupType -eq 'Unknown') {
                $action = 'Blocked'
                $note = 'Nieznany typ uruchomienia — zmiana niedostępna.'
            }
            elseif ($current.StartupType -ne $item.StartupType) {
                if ($current.IsProtected -and -not $wanted.AllowedWhenProtected) {
                    $action = 'Protected'
                    $note = 'Usługa chroniona: {0}' -f $current.ProtectionReason
                }
                else {
                    $action = 'Change'
                    if ($item.StartupType -eq 'Disabled' -and $current.Status -ne 'Stopped') {
                        $note = 'Usługa działa — wyłączenie jej nie zatrzyma.'
                    }
                }
            }
            [pscustomobject]@{
                PSTypeName    = 'MWP.ServiceProfileDiff'
                Name          = $(if ($null -ne $current) { $current.Name } else { $item.Name })
                DisplayName   = $(if ($null -ne $current) { $current.DisplayName } else { $item.DisplayName })
                Current       = $(if ($null -ne $current) { $current.StartupType } else { $null })
                CurrentText   = $(if ($null -ne $current) { $current.StartupTypeText } else { '—' })
                Wanted        = $item.StartupType
                WantedText    = $wanted.Label
                CurrentStatus = $(if ($null -ne $current) { $current.StatusText } else { '—' })
                ProfileStatus = $(if ($item.Status) { Get-MwpServiceText -Status $item.Status } else { '—' })
                Action        = $action
                ActionText    = switch ($action) { 'Change' { 'Do zmiany' } 'Same' { 'Bez zmian' } 'Missing' { 'Brak usługi' } 'Protected' { 'Chroniona' } default { 'Zablokowana' } }
                Note          = $note
            }
        })
    $order = @{ Change = 0; Protected = 1; Blocked = 2; Missing = 3; Same = 4 }
    $rows = @($rows | Sort-Object -Property @{ Expression = { $order[$_.Action] } }, DisplayName)
    $changes = @($rows | Where-Object { $_.Action -eq 'Change' }).Count
    New-MwpResult -Operation $operation -Target $ProfileData.Path -ComputerName $computerName -Success $true -Data $rows `
        -Message ("Profil a komputer '{0}': {1} zmian(y) typu uruchomienia, {2} bez zmian, {3} chronionych, {4} brakujących." -f $computerName, $changes,
        @($rows | Where-Object { $_.Action -eq 'Same' }).Count, @($rows | Where-Object { $_.Action -eq 'Protected' }).Count, @($rows | Where-Object { $_.Action -eq 'Missing' }).Count)
}
