function Initialize-MwpModuleInstance {
    <#
    .SYNOPSIS
        Inicjalizuje instancję modułu: import modułu (raz na proces) i opcjonalnie połączenie z komputerem.

    .DESCRIPTION
        Cykl życia D-024: utworzenie -> inicjalizacja -> działanie -> zamknięcie. Moduł jest
        importowany globalnie tylko wtedy, gdy nie jest jeszcze załadowany (definicja jest wspólna,
        stan należy do instancji). Z -Connect łączy kontekst z komputerem zdalnym; błąd połączenia
        nie przerywa inicjalizacji — instancja ma status Initialized, a stan połączenia kontekstu
        opisuje błąd (izolacja, D-019).

    .EXAMPLE
        Initialize-MwpModuleInstance -Instance $instance -Connect
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PSTypeName('MWP.ModuleInstance')]
        [object] $Instance,

        [switch] $Connect
    )

    process {
        $operation = 'Instance.Initialize'
        $computerName = $Instance.Context.ComputerName
        $common = @{ Operation = $operation; Target = $Instance.Name; ComputerName = $computerName }

        if ($Instance.Status -eq 'Closed') {
            return New-MwpResult @common -Success $false -Message ("Instancja '{0}' jest zamknięta; utwórz nową." -f $Instance.Name)
        }

        try {
            if ($null -eq (Get-Module -Name $Instance.ModuleName)) {
                Import-Module -Name $Instance.ManifestPath -Global -ErrorAction Stop
            }
        }
        catch {
            $message = "Nie udało się zaimportować modułu {0} dla instancji '{1}': {2}" -f $Instance.ModuleName, $Instance.Name, $_.Exception.Message
            Write-MwpLog -Level Error -Source 'MWP.Remote' -Operation $operation -ComputerName $computerName -Message $message
            return New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message
        }

        $changed = $Instance.Status -ne 'Initialized'
        if ($changed) {
            $Instance.Status = 'Initialized'
            $Instance.InitializedAt = Get-Date
        }

        if ($Connect -and $Instance.Context.Mode -eq 'Remote') {
            $connection = Connect-MwpTarget -Context $Instance.Context
            if (-not $connection.Success) {
                return New-MwpResult @common -Success $false -Changed $changed -Message ("Instancja '{0}' zainicjalizowana bez połączenia: {1}" -f $Instance.Name, $connection.Message) `
                    -ErrorMessage $connection.ErrorMessage
            }
        }
        New-MwpResult @common -Success $true -Changed $changed -Message ("Instancja '{0}' jest gotowa." -f $Instance.Name)
    }
}
