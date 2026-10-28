function Get-MwpNetworkActionState {
    <#
    .SYNOPSIS
        Wylicza dostępność przycisków widoku sieci dla zaznaczonego adaptera.

    .DESCRIPTION
        Czysta funkcja (bez WPF). Zmiany (włącz, wyłącz, DHCP, DNS, resety) wymagają administratora na
        komputerze docelowym (ostatni odczyt stanu) i braku trwającego zadania; zmiana DNS i wyłączenie
        są zablokowane na adapterze, na którym czeka niezatwierdzona zmiana (D-049). Wyłączenie adaptera
        połączenia wymaga dodatkowego potwierdzenia (DisableNeedsExtra). Reguły i tak egzekwują funkcje
        MWP.Network.

    .PARAMETER Status
        MWP.NetworkStatus (ostatni odczyt) albo $null.

    .PARAMETER InterfaceIndex
        Indeks zaznaczonego adaptera (0 = brak).

    .PARAMETER Ready
        Połączono i nie trwa żadne zadanie widoku ani zmiana.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Status,

        [int] $InterfaceIndex = 0,

        [bool] $Ready = $true
    )

    $administrator = $null -ne $Status -and [bool]$Status.IsAdministrator
    $adapter = if ($null -ne $Status -and $InterfaceIndex -gt 0) { @($Status.Adapters | Where-Object { $_.InterfaceIndex -eq $InterfaceIndex }) | Select-Object -First 1 } else { $null }
    $pending = if ($null -ne $adapter) { @($Status.Pending | Where-Object { $_.InterfaceIndex -eq $InterfaceIndex }) | Select-Object -First 1 } else { $null }
    $change = $Ready -and $administrator -and $null -ne $adapter
    $hint = if ($null -eq $Status) {
        ''
    }
    elseif (-not $administrator) {
        'Zmiany wymagają uprawnień administratora na tym komputerze.'
    }
    elseif ($null -eq $adapter) {
        'Wybierz adapter z listy.'
    }
    elseif ($null -ne $pending) {
        'Na tym adapterze czeka niezatwierdzona zmiana — zatwierdź ją albo poczekaj na wycofanie.'
    }
    elseif ($adapter.IsConnectionAdapter) {
        'Tym adapterem idzie połączenie aplikacji z tym komputerem.'
    }
    else {
        ''
    }

    [pscustomobject]@{
        PSTypeName        = 'MWP.NetworkActionState'
        Adapter           = $adapter
        Pending           = $pending
        IsAdministrator   = $administrator
        CanEnable         = $change -and -not $adapter.IsEnabled
        CanDisable        = $change -and $adapter.IsEnabled -and $null -eq $pending
        DisableNeedsExtra = $null -ne $adapter -and [bool]$adapter.IsConnectionAdapter
        CanRenew          = $change -and $adapter.DhcpEnabled -and $adapter.Status -eq 'Up'
        CanSetDns         = $change -and $adapter.IsEnabled -and $null -eq $pending
        CanFlush          = $Ready
        CanTest           = $Ready
        CanReset          = $Ready -and $administrator
        CanApprove        = $Ready -and $null -ne $Status -and @($Status.Pending).Count -gt 0
        Hint              = $hint
    }
}
