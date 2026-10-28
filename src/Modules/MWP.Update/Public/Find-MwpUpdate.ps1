function Find-MwpUpdate {
    <#
    .SYNOPSIS
        Wyszukuje oczekujące (niezainstalowane, nieukryte) aktualizacje na komputerze docelowym przez Windows Update Agent (COM Microsoft.Update.Session).

    .DESCRIPTION
        Operacja klasy Odczyt: IUpdateSearcher.Search na komputerze kontekstu (localhost albo zdalnym,
        D-019) łączy się z serwerem aktualizacji i trwa zwykle od kilkunastu sekund do kilku minut;
        niczego nie pobiera ani nie instaluje. Kryteria są stałe i wybierane parametrem -Type (bez
        sklejania tekstu z danych wejściowych, D-015). W sesji zdalnej (WinRM) wyszukiwanie zwykle
        działa, ale Windows Update Agent może odmówić (0x80070005) — wynik z błędem i opisem (D-048).
        Bez -AsOperation zwraca MWP.Result z MWP.UpdateSearch w Data; z -AsOperation startuje w puli
        runspace'ów (Start-MwpOperation, limit czasu -TimeoutSeconds) i zwraca uchwyt MWP.Operation —
        wynik zamienia Resolve-MwpUpdateSearch.

    .PARAMETER Type
        All (domyślnie), Software albo Driver.

    .EXAMPLE
        (Find-MwpUpdate).Data.Updates | Format-Table Title, KBText, SizeText, RebootText
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidateSet('All', 'Software', 'Driver')]
        [string] $Type = 'All',

        [ValidateRange(60, 86400)]
        [int] $TimeoutSeconds = 900,

        [switch] $AsOperation
    )

    $operation = 'Update.Search'
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            Criteria            = Get-MwpUpdateSearchFilter -Type $Type
            ClientApplicationId = 'MyWindowsPower'
        })
    $block = Get-MwpUpdateScript -Name Search
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation -TimeoutSeconds $TimeoutSeconds
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation -TimeoutSeconds $TimeoutSeconds
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    $search = Resolve-MwpUpdateSearch -Data $result -Type $Type -ComputerName $Context.ComputerName
    if ($null -eq $search) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił wyniku wyszukiwania aktualizacji." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
    }
    New-MwpResult @common -Success $search.Success -Message $search.Message -ErrorMessage $search.ErrorText -Data $search
}
