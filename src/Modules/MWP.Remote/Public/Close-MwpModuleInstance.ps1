function Close-MwpModuleInstance {
    <#
    .SYNOPSIS
        Zamyka instancję modułu i zwalnia jej zasoby; inne instancje działają dalej.

    .DESCRIPTION
        Anuluje operacje asynchroniczne instancji, zamyka sesje WinRM i CIM jej kontekstu, usuwa
        poświadczenia z pamięci, czyści stan instancji i usuwa ją z rejestru. Instancje tego
        samego modułu (także dla tego samego komputera) mają własne konteksty i nie są zmieniane.
        Zamknięcie zamkniętej instancji nic nie robi. Moduł zostaje załadowany (definicja jest
        wspólna dla instancji).

    .EXAMPLE
        Get-MwpModuleInstance -ModuleId 'Services' | Close-MwpModuleInstance
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByInstance')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'ByInstance')]
        [PSTypeName('MWP.ModuleInstance')]
        [object] $Instance,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    process {
        $operation = 'Instance.Close'
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $Instance = $script:MwpInstanceRegistry[$Id]
            if ($null -eq $Instance) {
                return New-MwpResult -Success $false -Operation $operation -Target $Id -Message ("Nie znaleziono instancji '{0}'." -f $Id)
            }
        }
        $computerName = $Instance.Context.ComputerName
        $common = @{ Operation = $operation; Target = $Instance.Name; ComputerName = $computerName }
        if ($Instance.Status -eq 'Closed') {
            return New-MwpResult @common -Success $true -Message ("Instancja '{0}' jest już zamknięta." -f $Instance.Name)
        }

        $stopped = 0
        foreach ($running in @($script:MwpOperationRegistry.Values | Where-Object { $_.InstanceId -eq $Instance.Id -and $_.Status -eq 'Running' })) {
            $null = Stop-MwpOperation -Operation $running -Confirm:$false
            $stopped++
        }
        $null = Disconnect-MwpTarget -Context $Instance.Context
        $Instance.State.Clear()
        $Instance.Status = 'Closed'
        $Instance.ClosedAt = Get-Date
        $script:MwpInstanceRegistry.Remove($Instance.Id)

        $message = "Zamknięto instancję '{0}' (anulowane operacje: {1})." -f $Instance.Name, $stopped
        Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName $computerName -Message $message -Data @{ InstanceId = $Instance.Id }
        New-MwpResult @common -Success $true -Changed $true -Message $message -Data ([ordered]@{ InstanceId = $Instance.Id; StoppedOperations = $stopped })
    }
}
