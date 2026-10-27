function Resolve-MwpServiceList {
    <#
    .SYNOPSIS
        Zamienia surowy wynik odczytu usług (Get-MwpService -AsOperation, blok List) na listę usług MWP.ServiceList z oznaczeniem listy ochronnej.

    .DESCRIPTION
        Czysta funkcja (bez wywołań na komputerze docelowym): przyjmuje tekst JSON, MWP.Result
        z operacji w tle albo obiekt MWP.ServiceRaw; gotowa MWP.ServiceList jest zwracana bez zmian.
        Każda usługa (MWP.Service) ma stan i typ uruchomienia po polsku, zależności (gdy odczyt je
        zawierał) i oznaczenie listy ochronnej (IsProtected, ProtectionReason). Gdy listy ochronnej
        nie da się odczytać, wszystkie usługi są oznaczone jako chronione (zmiany zablokowane)
        z ostrzeżeniem. Zwraca $null, gdy danych nie ma.

    .PARAMETER ProtectedItem
        Elementy listy ochronnej kategorii Service (domyślnie Get-MwpProtectedItem -Category Service).

    .EXAMPLE
        Resolve-MwpServiceList -Data (Wait-MwpOperation -Operation (Get-MwpService -AsOperation))
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $ProtectedItem
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.ServiceList') {
        return $Data
    }
    $raw = ConvertFrom-MwpServiceJson -Data $Data -Kind 'MWP.ServiceRaw'
    if ($null -eq $raw -or $raw.Error) {
        return $null
    }
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($warning in @($raw.Warnings | Where-Object { $_ })) {
        $warnings.Add([string]$warning)
    }
    $protectionKnown = $true
    if (-not $PSBoundParameters.ContainsKey('ProtectedItem') -or $null -eq $ProtectedItem) {
        try {
            $ProtectedItem = @(Get-MwpProtectedItem -Category Service)
        }
        catch {
            $protectionKnown = $false
            $ProtectedItem = @()
            $warnings.Add(('Lista ochronna jest nieczytelna — wszystkie usługi są traktowane jako chronione: {0}' -f $_.Exception.Message))
        }
    }

    $links = @($raw.Dependencies | Where-Object { $null -ne $_ })
    $dependsOn = @{}
    $dependents = @{}
    foreach ($link in $links) {
        $service = ([string]$link.Service).ToLowerInvariant()
        $required = ([string]$link.DependsOn).ToLowerInvariant()
        if (-not $dependsOn.ContainsKey($service)) { $dependsOn[$service] = New-Object -TypeName System.Collections.Generic.List[string] }
        if (-not $dependents.ContainsKey($required)) { $dependents[$required] = New-Object -TypeName System.Collections.Generic.List[string] }
        $dependsOn[$service].Add([string]$link.DependsOn)
        $dependents[$required].Add([string]$link.Service)
    }

    $typeLabels = @{}
    foreach ($type in @(Get-MwpServiceStartupTypeList)) {
        $typeLabels[$type.Id] = $type.Label
    }
    $patterns = @($ProtectedItem | Where-Object { $null -ne $_ })
    $services = @(foreach ($item in @($raw.Services | Where-Object { $null -ne $_ })) {
            $name = [string]$item.Name
            $key = $name.ToLowerInvariant()
            $status = ([string]$item.State) -replace '\s', ''
            if (-not $status) { $status = 'Unknown' }
            $startupType = switch ([string]$item.StartMode) {
                'Auto' { if ($item.Delayed) { 'AutomaticDelayedStart' } else { 'Automatic' } }
                'Manual' { 'Manual' }
                'Disabled' { 'Disabled' }
                default { 'Unknown' }
            }
            $protection = $null
            foreach ($pattern in $patterns) {
                if ($name -like $pattern.Name) {
                    $protection = $pattern
                    break
                }
            }
            [pscustomobject]@{
                PSTypeName       = 'MWP.Service'
                Name             = $name
                DisplayName      = $(if ($item.DisplayName) { [string]$item.DisplayName } else { $name })
                Status           = $status
                StatusText       = Get-MwpServiceText -Status $status
                StartupType      = $startupType
                StartupTypeText  = $(if ($typeLabels.ContainsKey($startupType)) { $typeLabels[$startupType] } else { 'Nieznany' })
                Account          = [string]$item.StartName
                Path             = [string]$item.PathName
                Description      = [string]$item.Description
                ProcessId        = [int]$item.ProcessId
                CanStop          = [bool]$item.AcceptStop
                ServiceType      = [string]$item.ServiceType
                DependsOn        = $(if ($dependsOn.ContainsKey($key)) { $dependsOn[$key].ToArray() } else { @() })
                Dependents       = $(if ($dependents.ContainsKey($key)) { $dependents[$key].ToArray() } else { @() })
                IsProtected      = (-not $protectionKnown) -or $null -ne $protection
                ProtectionReason = $(if ($null -ne $protection) { $protection.Reason } elseif (-not $protectionKnown) { 'Lista ochronna jest nieczytelna.' } else { $null })
            }
        })

    [pscustomobject]@{
        PSTypeName      = 'MWP.ServiceList'
        Kind            = 'MWP.ServiceList'
        ComputerName    = [string]$raw.ComputerName
        CollectedAt     = [string]$raw.CollectedAt
        IsAdministrator = $raw.IsAdministrator
        HasGraph        = [bool]$raw.HasGraph
        Services        = @($services | Sort-Object -Property DisplayName)
        Dependencies    = $links
        Warnings        = $warnings.ToArray()
    }
}
