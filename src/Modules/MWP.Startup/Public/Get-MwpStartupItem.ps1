function Get-MwpStartupItem {
    <#
    .SYNOPSIS
        Odczytuje pozycje autostartu na komputerze docelowym: Run/RunOnce (HKLM z WOW6432Node i użytkownika), foldery Startup, stan z StartupApproved, podpis wydawcy.

    .DESCRIPTION
        Operacja klasy Odczyt (nic nie zmienia). Jedno wywołanie na komputerze kontekstu (localhost
        albo zdalnym, D-019). Pozycje użytkownika (D-046): lokalnie HKCU i folder Startup bieżącego
        konta; zdalnie — profile użytkowników zalogowanych na komputerze docelowym (HKEY_USERS\<SID>);
        gdy nikt nie jest zalogowany, tylko pozycje systemowe z ostrzeżeniem. Filtry jak
        w Select-MwpStartupItem.
        Bez -AsOperation zwraca MWP.Result z MWP.StartupItemList w Data (pozycje w polu Items).
        Z -AsOperation startuje w puli runspace'ów (Start-MwpOperation) i zwraca uchwyt MWP.Operation;
        surowy JSON zamienia Resolve-MwpStartupItemList (filtry nie są wtedy stosowane).

    .PARAMETER NoSignature
        Bez sprawdzania podpisów (Get-AuthenticodeSignature) — szybszy odczyt.

    .PARAMETER WidgetParameters
        Parametry widgetu „Autostart” (kontrakt D-043, D-053): bez sekcji Risky w Sections podpisy nie są sprawdzane (jak -NoSignature) — odczyt jest wtedy szybszy.

    .EXAMPLE
        (Get-MwpStartupItem -State Enabled).Data.Items | Format-Table Name, LocationText, RiskText, Publisher

    .EXAMPLE
        (Get-MwpStartupItem -Context $remote -Scope Machine).Data.Items
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidateSet('All', 'Machine', 'User')]
        [string] $Scope = 'All',

        [ValidateSet('All', 'Enabled', 'Disabled', 'RunOnce')]
        [string] $State = 'All',

        [ValidateSet('All', 'NotSigned')]
        [string] $Risk = 'All',

        [AllowEmptyString()]
        [string] $Search = '',

        [switch] $NoSignature,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Startup.ListItems'
    if ($null -ne $WidgetParameters -and $WidgetParameters.Contains('Sections') -and @($WidgetParameters['Sections']) -notcontains 'Risky') {
        $NoSignature = [switch]$true
    }
    if ($AsOperation) {
        return Invoke-MwpStartupRead -Context $Context -Operation $operation -Kind Item -NoSignature:$NoSignature -AsOperation
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $read = Invoke-MwpStartupRead -Context $Context -Operation $operation -Kind Item -NoSignature:$NoSignature
    if (-not $read.Success) {
        return New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
    }
    $list = Resolve-MwpStartupItemList -Data $read.Raw
    $all = @($list.Items).Count
    $list.Items = @(Select-MwpStartupItem -Item $list.Items -Scope $Scope -State $State -Risk $Risk -Search $Search)
    $shown = @($list.Items).Count
    $message = if ($shown -eq $all) {
        "Odczytano {0} pozycji autostartu komputera '{1}'." -f $all, $Context.ComputerName
    }
    else {
        "Odczytano {0} pozycji autostartu komputera '{1}' (po filtrach: {2})." -f $all, $Context.ComputerName, $shown
    }
    New-MwpResult @common -Success $true -Message $message -Data $list
}
