function Get-MwpNetworkRow {
    <#
    .SYNOPSIS
        Zwraca wiersze tabel widoku sieci: adaptery, zmiany czekające na zatwierdzenie (z odliczaniem) albo wyniki testów łączności.

    .DESCRIPTION
        Czysta funkcja (bez WPF). Pozostały czas zmiany oczekującej liczy się od sekund pozostałych
        w chwili odczytu na komputerze docelowym (RemainingSeconds) minus czas, który upłynął od
        odczytu na hoście (-ReadAt, -Now) — bez porównywania zegarów obu komputerów (D-049).

    .PARAMETER Status
        MWP.NetworkStatus (wiersze adapterów albo, z -Pending, zmian oczekujących).

    .PARAMETER Pending
        Wiersze zmian oczekujących zamiast adapterów.

    .PARAMETER ReadAt
        Czas odczytu stanu na hoście.

    .PARAMETER Now
        Bieżący czas (testy).

    .PARAMETER Test
        MWP.NetworkTest (wiersze testów łączności).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Adapter')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Adapter')]
        [Parameter(ParameterSetName = 'Pending')]
        [AllowNull()]
        [object] $Status,

        [Parameter(Mandatory, ParameterSetName = 'Pending')]
        [switch] $Pending,

        [Parameter(ParameterSetName = 'Pending')]
        [AllowNull()]
        [object] $ReadAt,

        [Parameter(ParameterSetName = 'Pending')]
        [datetime] $Now = (Get-Date),

        [Parameter(Mandatory, ParameterSetName = 'Test')]
        [AllowNull()]
        [object] $Test
    )

    if ($PSCmdlet.ParameterSetName -eq 'Test') {
        if ($null -eq $Test) {
            return
        }
        foreach ($item in @($Test.Tests)) {
            [pscustomobject]@{
                Label        = $item.Label
                Target       = $item.Target
                ResultText   = $item.ResultText
                Detail       = $item.Detail
                DurationText = $(if ($item.DurationMs -gt 0) { '{0} ms' -f $item.DurationMs } else { '' })
                Success      = $item.Success
            }
        }
        return
    }
    if ($null -eq $Status) {
        return
    }
    if ($Pending) {
        $elapsed = if ($null -ne $ReadAt) { [Math]::Max(0, ($Now - [datetime]$ReadAt).TotalSeconds) } else { 0 }
        foreach ($item in @($Status.Pending)) {
            $remaining = [int][Math]::Floor($item.RemainingSeconds - $elapsed)
            $summary = ([string]$item.Description) -replace '^My Windows Power: automatyczne wycofanie zmiany sieci \((.*)\)\. .*$', '$1'
            [pscustomobject]@{
                ChangeId         = $item.ChangeId
                Description      = $summary
                AdapterName      = $item.AdapterName
                InterfaceIndex   = $item.InterfaceIndex
                DeadlineText     = $(if ($null -ne $item.Deadline) { ([datetime]$item.Deadline).ToString('HH:mm:ss') } else { '' })
                RemainingSeconds = $remaining
                RemainingText    = $(if ($remaining -gt 0) { '{0}:{1:00}' -f [Math]::Floor($remaining / 60), ($remaining % 60) } else { 'wycofywanie…' })
            }
        }
        return
    }
    $pendingIndex = @($Status.Pending | ForEach-Object { $_.InterfaceIndex })
    foreach ($adapter in @($Status.Adapters)) {
        $notes = @()
        if ($adapter.IsConnectionAdapter) { $notes += 'połączenie aplikacji' }
        if ($pendingIndex -contains $adapter.InterfaceIndex) { $notes += 'zmiana czeka na zatwierdzenie' }
        if ($adapter.Virtual) { $notes += 'wirtualny' }
        [pscustomobject]@{
            InterfaceIndex = $adapter.InterfaceIndex
            Name           = $adapter.Name
            StatusText     = $adapter.StatusText
            IPv4Text       = $adapter.IPv4Text
            GatewayText    = $adapter.GatewayText
            DnsText        = $adapter.DnsText
            DhcpText       = $(if ($adapter.DhcpEnabled) { 'Tak' } else { 'Nie' })
            CategoryText   = $adapter.CategoryText
            Note           = $notes -join ', '
        }
    }
}
