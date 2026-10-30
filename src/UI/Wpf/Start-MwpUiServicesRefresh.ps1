function Start-MwpUiServicesRefresh {
    <#
    .SYNOPSIS
        Odczytuje usługi komputera instancji w tle (Get-MwpService -AsOperation -IncludeDependencies) i odświeża widok po zakończeniu.

    .DESCRIPTION
        Operacja w puli MWP.Remote (limit czasu, anulowanie z paska stanu, zamknięcie instancji ją
        anuluje). Błąd lub utrata połączenia zmienia tylko ten widok (komunikat), nie aplikację (D-019).
        Komputer zdalny bez poświadczeń: komunikat z prośbą o „Połącz”. Gdy wczytano profil usług,
        różnice są liczone ponownie z nowego odczytu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt (bez zmian systemu).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $context = $Entry.Instance.Context
    if ($Entry.Services.Loading) {
        return
    }
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        $Entry.Services.Error = 'Połącz instancję z komputerem {0} (przycisk „Połącz”), żeby odczytać usługi.' -f (Format-MwpTargetLabel -Context $context)
        Update-MwpServicesView -Entry $Entry
        return
    }
    $operation = Get-MwpService -Context $context -IncludeDependencies -AsOperation
    $Entry.Services.Loading = $true
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation $operation -Name ('Usługi: odczyt ({0})' -f (Format-MwpTargetLabel -Context $context)) `
        -State @{ InstanceId = $Entry.Id } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Services.Loading = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $list = $null
        if ($null -ne $result -and $result.Success) {
            $list = Resolve-MwpServiceList -Data $result
        }
        if ($null -ne $list) {
            $entry.Services.List = $list
            $byName = @{}
            foreach ($service in @($list.Services)) {
                $byName[$service.Name] = $service
            }
            $entry.Services.ByName = $byName
            $entry.Services.Error = $null
            if ($null -ne $entry.Services.Profile) {
                $compare = Compare-MwpServiceProfile -ProfileData $entry.Services.Profile -ServiceList $list
                $entry.Services.Diff = $(if ($compare.Success) { @($compare.Data) } else { @() })
                $entry.ModuleView.Controls['ProfileText'].Text = $compare.Message
            }
        }
        else {
            $entry.Services.Error = 'Odczyt usług nie powiódł się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpServicesView -Entry $Entry
}
