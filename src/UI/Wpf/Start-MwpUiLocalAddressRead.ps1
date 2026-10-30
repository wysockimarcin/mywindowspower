function Start-MwpUiLocalAddressRead {
    <#
    .SYNOPSIS
        Odczytuje w tle adres LAN tego komputera (kolumna „Adres IP” wiersza localhost w Ustawieniach, D-054).

    .DESCRIPTION
        Tylko przy wyświetleniu: wejście w Ustawienia (gdy ostatni odczyt jest starszy niż 60 s) albo
        „Odśwież” (-Force). Odczyt (Get-MwpLocalNetworkAddress) działa w puli zadań okna, więc siatka
        pokazuje się od razu („odczyt…”), a adres dopisuje się po odczycie. Wynik jest trzymany tylko
        w stanie okna — nie trafia do ustawień, kontekstu wykonania ani połączeń. Błąd odczytu daje
        „brak danych” bez wpływu na resztę aplikacji.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia tylko odczyt w tle; nie zmienia systemu.')]
    [CmdletBinding()]
    param(
        [switch] $Force
    )

    $ui = $script:MwpUi
    if (-not $ui.ContainsKey('LocalNetwork') -or $null -eq $ui.LocalNetwork) {
        $ui['LocalNetwork'] = @{ Result = $null; ReadAt = [datetime]::MinValue; Task = $null }
    }
    $state = $ui.LocalNetwork
    if ($null -ne $state.Task -and $state.Task.Status -eq 'Running') {
        return
    }
    if (-not $Force -and $null -ne $state.Result -and ((Get-Date) - [datetime]$state.ReadAt).TotalSeconds -lt 60) {
        return
    }
    if ($Force) {
        $state.Result = $null
    }
    $state.Task = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name 'Adres tego komputera w sieci LAN' -ScriptBlock {
        param($Progress)
        $Progress.Message = 'odczyt kart sieciowych'
        Get-MwpLocalNetworkAddress
    } -OnCompleted {
        param($Task)
        $ui = $script:MwpUi
        $result = @($Task.Output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.NetworkAddress' }) | Select-Object -Last 1
        if ($null -eq $result) {
            $result = [pscustomobject]@{ PSTypeName = 'MWP.NetworkAddress'; Status = 'Unavailable'; Text = 'brak danych'; ToolTip = [string]$Task.Error; AllAddresses = @() }
        }
        $ui.LocalNetwork.Result = $result
        $ui.LocalNetwork.ReadAt = Get-Date
        $ui.LocalNetwork.Task = $null
        if ($ui.CurrentKey -eq 'settings' -and $ui.Views.ContainsKey('settings')) {
            Update-MwpSettingsView -View $ui.Views['settings'] -TargetsOnly
        }
    }
}
