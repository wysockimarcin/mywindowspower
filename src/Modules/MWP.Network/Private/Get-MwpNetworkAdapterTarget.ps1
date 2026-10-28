function Get-MwpNetworkAdapterTarget {
    <#
    .SYNOPSIS
        Wspólne sprawdzenia przed zmianą adaptera: odczyt stanu, adapter o podanym indeksie (i GUID), administrator, brak zmiany czekającej na zatwierdzenie.

    .DESCRIPTION
        Wynik: Success, Result (MWP.Result z odmową — gdy Success = $false), Status (MWP.NetworkStatus),
        Adapter (MWP.NetAdapter) i Target (opis do potwierdzenia). Sprawdzenia dzieją się przed
        podglądem (-WhatIf), więc odmowa jest widoczna już w podglądzie. Zmiana adaptera, na którym
        czeka niezatwierdzona zmiana, jest odrzucana — inaczej zadanie wycofania przywróciłoby stan
        sprzed obu zmian w złej kolejności (D-049).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [int] $InterfaceIndex,

        [AllowEmptyString()]
        [string] $InterfaceGuid = '',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [switch] $RequireAdministrator,

        [switch] $RejectPending
    )

    $computerName = $Context.ComputerName
    $common = @{ Operation = $Operation; Target = ('adapter {0}' -f $InterfaceIndex); ComputerName = $computerName }
    $deny = {
        param([string] $Message, [string] $ErrorMessage)
        [pscustomobject]@{ Success = $false; Result = (New-MwpResult @common -Success $false -Message $Message -ErrorMessage $ErrorMessage); Status = $null; Adapter = $null; Target = '' }
    }
    $read = Get-MwpNetworkStatus -Context $Context
    if (-not $read.Success) {
        return & $deny $read.Message $read.ErrorMessage
    }
    $status = $read.Data
    $adapter = @($status.Adapters | Where-Object { $_.InterfaceIndex -eq $InterfaceIndex }) | Select-Object -First 1
    if ($null -eq $adapter) {
        return & $deny ("Na komputerze '{0}' nie ma adaptera sieciowego o indeksie {1}." -f $computerName, $InterfaceIndex) ''
    }
    if ($InterfaceGuid -and $adapter.InterfaceGuid.Trim('{}') -ne $InterfaceGuid.Trim('{}')) {
        return & $deny ("Adapter o indeksie {0} na komputerze '{1}' ma inny identyfikator ({2}) niż oczekiwany ({3}) — zmiana odrzucona." -f $InterfaceIndex, $computerName, $adapter.InterfaceGuid, $InterfaceGuid) ''
    }
    if ($RequireAdministrator) {
        $admin = Test-MwpNetworkAdmin -Context $Context
        if (-not $admin.Success) {
            return & $deny $admin.Result.Message $admin.Result.ErrorMessage
        }
        if (-not $admin.IsAdministrator) {
            return & $deny ("Zmiana ustawień sieci wymaga uprawnień administratora na komputerze '{0}'." -f $computerName) ''
        }
    }
    if ($RejectPending) {
        $pending = @($status.Pending | Where-Object { $_.InterfaceIndex -eq $InterfaceIndex }) | Select-Object -First 1
        if ($null -ne $pending) {
            return & $deny ("Na adapterze '{0}' (komputer '{1}') czeka na zatwierdzenie poprzednia zmiana — zatwierdź ją (Approve-MwpNetworkChange -ChangeId {2}) albo poczekaj na automatyczne wycofanie{3}." -f $adapter.Name, $computerName, $pending.ChangeId,
                $(if ($null -ne $pending.Deadline) { ' ({0:HH:mm:ss})' -f $pending.Deadline } else { '' })) ''
        }
    }
    [pscustomobject]@{
        Success = $true
        Result  = $null
        Status  = $status
        Adapter = $adapter
        Target  = ("adapter '{0}' ({1})" -f $adapter.Name, $adapter.Description)
    }
}
