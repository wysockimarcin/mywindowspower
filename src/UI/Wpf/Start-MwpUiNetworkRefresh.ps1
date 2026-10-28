function Start-MwpUiNetworkRefresh {
    <#
    .SYNOPSIS
        Odczytuje w tle stan sieci (Status) albo wykonuje testy łączności (Test) komputera instancji i odświeża widok po zakończeniu.

    .DESCRIPTION
        Operacje w puli MWP.Remote (Get-MwpNetworkStatus i Test-MwpNetworkConnection z -AsOperation;
        limit czasu, anulowanie z paska stanu, zamknięcie instancji je anuluje). Błąd lub utrata
        połączenia zmienia tylko ten widok (komunikat), nie aplikację (D-019). Komputer zdalny bez
        poświadczeń: komunikat z prośbą o „Połącz”.

    .PARAMETER Kind
        Status (domyślnie) albo Test.

    .PARAMETER TestParameters
        Parametry Test-MwpNetworkConnection (ExternalHost, DnsName, PortHost, Port).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt (bez zmian systemu).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [ValidateSet('Status', 'Test')]
        [string] $Kind = 'Status',

        [hashtable] $TestParameters = @{}
    )

    $context = $Entry.Instance.Context
    $view = $Entry.Network
    if ($view[$Kind + 'Loading']) {
        return
    }
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        $view[$Kind + 'Error'] = 'Połącz instancję z komputerem {0} (przycisk „Połącz”), żeby odczytać sieć.' -f $context.ComputerName
        Update-MwpNetworkView -Entry $Entry
        return
    }
    if ($Kind -eq 'Status') {
        $operation = Get-MwpNetworkStatus -Context $context -AsOperation
        $name = 'Sieć: stan ({0})' -f $context.ComputerName
    }
    else {
        try {
            $operation = Test-MwpNetworkConnection -Context $context -AsOperation @TestParameters
        }
        catch {
            $view.TestError = $_.Exception.Message
            Update-MwpNetworkView -Entry $Entry
            return
        }
        $name = 'Sieć: testy łączności ({0})' -f $context.ComputerName
    }
    $view[$Kind + 'Loading'] = $true
    $view[$Kind + 'Error'] = $null
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation $operation -Name $name -State @{ InstanceId = $Entry.Id; Kind = $Kind } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $kind = [string]$Task.State.Kind
        $view = $entry.Network
        $view[$kind + 'Loading'] = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $data = $null
        if ($null -ne $result -and $result.Success) {
            $data = if ($kind -eq 'Status') { Resolve-MwpNetworkStatus -Data $result } else { Resolve-MwpNetworkTest -Data $result }
        }
        if ($null -ne $data) {
            $view[$kind] = $data
            $view[$kind + 'Error'] = $null
            if ($kind -eq 'Status') {
                $view.StatusReadAt = Get-Date
                $view.ExpiredRefresh = $false
            }
        }
        elseif ($Task.Status -eq 'Cancelled') {
            $view[$kind + 'Error'] = 'Anulowano.'
        }
        else {
            $view[$kind + 'Error'] = 'Odczyt nie powiódł się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpNetworkView -Entry $Entry
}
