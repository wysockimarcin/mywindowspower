function Invoke-MwpUiProbe {
    <#
    .SYNOPSIS
        Odczyt testowy instancji: operacja w tle na komputerze docelowym (Get-MwpTargetInfo -AsOperation), tylko odczyt.

    .DESCRIPTION
        Pokazuje, że instancja wykonuje operacje na swoim komputerze (localhost albo zdalnym) w puli
        MWP.Remote, z limitem czasu i anulowaniem z paska stanu, bez blokowania okna. Odczyt
        (nazwa komputera, system, wersja PowerShella, czas) należy do MWP.Remote, nie do kodu widoku.
        Zamknięcie instancji anuluje operację (Close-MwpModuleInstance).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    $context = $Entry.Instance.Context
    $state = Get-MwpConnectionStateInfo -Context $context
    if ($state.NeedsCredential) {
        Show-MwpMessage -Text ('Najpierw połącz instancję z komputerem {0} (przycisk „Połącz”), żeby podać poświadczenia.' -f (Format-MwpTargetLabel -Context $context)) -Owner $Owner
        return
    }

    $operation = Get-MwpTargetInfo -Context $context -AsOperation
    $Entry.Busy++
    $Entry.View.Controls['ProbeText'].Text = 'Odczyt w toku…'
    Update-MwpInstanceView -Entry $Entry -StateOnly
    $null = Register-MwpUiOperation -Registry $ui.Tasks -Operation $operation -Name ('Odczyt testowy: {0}' -f (Format-MwpTargetLabel -Context $context)) -State $Entry.Id -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State]
        if ($null -eq $entry) {
            return
        }
        $entry.Busy = [Math]::Max(0, $entry.Busy - 1)
        $result = @($Task.Output) | Select-Object -Last 1
        $text = if ($null -ne $result -and $result.Success) {
            $data = @($result.Data) | Select-Object -First 1
            'Komputer: {0}{4}System: {1} ({5}){4}PowerShell: {2}{4}Czas na komputerze: {3}' -f $data.ComputerName, $data.System, $data.PowerShell, $data.Time, [Environment]::NewLine, $data.OSVersion
        }
        else {
            'Odczyt nie powiódł się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        $entry.View.Controls['ProbeText'].Text = $text
        Update-MwpInstanceView -Entry $entry
    }
}
