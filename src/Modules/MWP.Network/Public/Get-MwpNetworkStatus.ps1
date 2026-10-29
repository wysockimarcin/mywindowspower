function Get-MwpNetworkStatus {
    <#
    .SYNOPSIS
        Odczytuje stan sieci komputera docelowego: adaptery, konfigurację IP, DNS, DHCP, profile sieci i zmiany czekające na zatwierdzenie.

    .DESCRIPTION
        Operacja klasy Odczyt. Jedno wywołanie na komputerze kontekstu (localhost albo zdalnym, D-019):
        Get-NetAdapter (także wyłączone), Get-NetIPAddress, Get-NetRoute (bramy), Get-DnsClientServerAddress
        i statyczne serwery z rejestru Tcpip/Tcpip6, Get-NetIPInterface (DHCP), Win32_NetworkAdapterConfiguration
        (dzierżawa), Get-NetConnectionProfile (profil sieci), połączenia TCP na porcie WinRM kontekstu
        (adapter używany przez połączenie zdalne) i zadania wycofania w \MyWindowsPower\ (D-049).
        Bez -AsOperation zwraca MWP.Result z MWP.NetworkStatus w Data. Z -AsOperation startuje w puli
        runspace'ów (Start-MwpOperation) i zwraca uchwyt MWP.Operation — wynik zamienia
        Resolve-MwpNetworkStatus.

    .PARAMETER WidgetParameters
        Parametry widgetu „Sieć” (kontrakt D-043); dane są zawsze pełne, adaptery i szczegóły wybiera ConvertTo-MwpNetworkStatusView.

    .EXAMPLE
        (Get-MwpNetworkStatus).Data.Adapters | Format-Table Name, StatusText, IPv4Text, DnsText
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043, D-053); adaptery i szczegóły wybiera funkcja widoku.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Network.Status'
    $config = Get-MwpNetworkTargetConfig
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            ConnectionPort = $(if ($Context.Mode -eq 'Remote') { [int]$Context.Port } else { 0 })
            TaskPath       = $config.TaskPath
            TaskPrefix     = $config.TaskPrefix
        })
    $block = Get-MwpNetworkScript -Name Status
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    $status = Resolve-MwpNetworkStatus -Data $result
    if ($null -eq $status) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił stanu sieci." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
    }
    New-MwpResult @common -Success $true -Message ("Odczytano stan sieci komputera '{0}' ({1} adapterów)." -f $Context.ComputerName, @($status.Adapters).Count) -Data $status
}
