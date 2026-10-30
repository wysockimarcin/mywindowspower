function Start-MwpUiUpdateRefresh {
    <#
    .SYNOPSIS
        Odczytuje w tle stan Windows Update (Status), oczekujące aktualizacje (Search) albo historię (History) komputera instancji i odświeża widok po zakończeniu.

    .DESCRIPTION
        Operacje w puli MWP.Remote (Get-MwpUpdateStatus, Find-MwpUpdate, Get-MwpUpdateHistory
        z -AsOperation; limit czasu, anulowanie z paska stanu, zamknięcie instancji je anuluje). Błąd lub
        utrata połączenia zmienia tylko ten widok (komunikat), nie aplikację (D-019). Komputer zdalny bez
        poświadczeń: komunikat z prośbą o „Połącz”.

    .PARAMETER Kind
        Status (domyślnie), Search albo History.

    .PARAMETER Type
        Rodzaj wyszukiwania (All, Software, Driver) dla Search.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt (bez zmian systemu).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [ValidateSet('Status', 'Search', 'History')]
        [string] $Kind = 'Status',

        [ValidateSet('All', 'Software', 'Driver')]
        [string] $Type = 'All'
    )

    $context = $Entry.Instance.Context
    $view = $Entry.Update
    if ($view[$Kind + 'Loading']) {
        return
    }
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        $view[$Kind + 'Error'] = 'Połącz instancję z komputerem {0} (przycisk „Połącz”), żeby odczytać Windows Update.' -f (Format-MwpTargetLabel -Context $context)
        Update-MwpUpdateView -Entry $Entry
        return
    }
    switch ($Kind) {
        'Status' {
            $operation = Get-MwpUpdateStatus -Context $context -AsOperation
            $name = 'Windows Update: stan ({0})' -f (Format-MwpTargetLabel -Context $context)
        }
        'Search' {
            $operation = Find-MwpUpdate -Context $context -Type $Type -AsOperation
            $name = 'Windows Update: wyszukiwanie aktualizacji ({0})' -f (Format-MwpTargetLabel -Context $context)
        }
        'History' {
            $operation = Get-MwpUpdateHistory -Context $context -AsOperation
            $name = 'Windows Update: historia ({0})' -f (Format-MwpTargetLabel -Context $context)
        }
    }
    $view[$Kind + 'Loading'] = $true
    $view[$Kind + 'Error'] = $null
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation $operation -Name $name -State @{ InstanceId = $Entry.Id; Kind = $Kind; Type = $Type } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $kind = [string]$Task.State.Kind
        $view = $entry.Update
        $view[$kind + 'Loading'] = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $computerName = $entry.Instance.Context.ComputerName
        $data = $null
        if ($null -ne $result -and $result.Success) {
            $data = switch ($kind) {
                'Status' { Resolve-MwpUpdateStatus -Data $result }
                'Search' { Resolve-MwpUpdateSearch -Data $result -Type ([string]$Task.State.Type) -ComputerName $computerName }
                'History' { Resolve-MwpUpdateHistory -Data $result -ComputerName $computerName }
            }
        }
        if ($null -ne $data -and ($kind -eq 'Status' -or $data.Success)) {
            $view[$kind] = $data
            $view[$kind + 'Error'] = $null
        }
        elseif ($null -ne $data) {
            $view[$kind + 'Error'] = $data.Message
        }
        elseif ($Task.Status -eq 'Cancelled') {
            $view[$kind + 'Error'] = 'Anulowano.'
        }
        else {
            $view[$kind + 'Error'] = 'Odczyt nie powiódł się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpUpdateView -Entry $Entry
}
