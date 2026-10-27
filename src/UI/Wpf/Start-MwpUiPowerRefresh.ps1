function Start-MwpUiPowerRefresh {
    <#
    .SYNOPSIS
        Odczytuje stan zasilania komputera instancji w tle (Get-MwpPowerStatus -AsOperation) i odświeża widok po zakończeniu.

    .DESCRIPTION
        Operacja w puli MWP.Remote (limit czasu, anulowanie z paska stanu, zamknięcie instancji ją
        anuluje). Błąd lub utrata połączenia zmienia tylko ten widok (komunikat), nie aplikację (D-019).
        Komputer zdalny bez poświadczeń: komunikat z prośbą o „Połącz”.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt (bez zmian systemu).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $context = $Entry.Instance.Context
    if ($Entry.Power.Loading) {
        return
    }
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        $Entry.Power.Error = 'Połącz instancję z komputerem {0} (przycisk „Połącz”), żeby odczytać stan zasilania.' -f $context.ComputerName
        Update-MwpPowerView -Entry $Entry
        return
    }
    $operation = Get-MwpPowerStatus -Context $context -AsOperation
    $Entry.Power.Loading = $true
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation $operation -Name ('Zasilanie: odczyt ({0})' -f $context.ComputerName) `
        -State @{ InstanceId = $Entry.Id } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Power.Loading = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $status = $null
        if ($null -ne $result -and $result.Success) {
            $status = Resolve-MwpPowerStatus -Data $result
        }
        if ($null -ne $status) {
            $entry.Power.Status = $status
            $entry.Power.Error = $null
        }
        else {
            $entry.Power.Error = 'Odczyt stanu zasilania nie powiódł się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpPowerView -Entry $Entry
}
