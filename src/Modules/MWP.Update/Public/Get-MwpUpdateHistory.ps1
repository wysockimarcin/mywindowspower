function Get-MwpUpdateHistory {
    <#
    .SYNOPSIS
        Odczytuje historię Windows Update na komputerze docelowym (IUpdateSearcher.QueryHistory): data, operacja, wynik, kod błędu, tytuł i KB.

    .DESCRIPTION
        Operacja klasy Odczyt (bez łączenia z serwerem aktualizacji). Zwraca najnowsze wpisy (-First).
        Bez -AsOperation zwraca MWP.Result z MWP.UpdateHistory w Data; z -AsOperation startuje w puli
        runspace'ów i zwraca uchwyt MWP.Operation — wynik zamienia Resolve-MwpUpdateHistory.

    .PARAMETER First
        Liczba najnowszych wpisów (1–2000, domyślnie 200).

    .EXAMPLE
        (Get-MwpUpdateHistory -First 20).Data.Entries | Format-Table DateText, OperationText, ResultText, Title
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidateRange(1, 2000)]
        [int] $First = 200,

        [switch] $AsOperation
    )

    $operation = 'Update.History'
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ First = $First })
    $block = Get-MwpUpdateScript -Name History
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    $history = Resolve-MwpUpdateHistory -Data $result -ComputerName $Context.ComputerName
    if ($null -eq $history) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił historii aktualizacji." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
    }
    New-MwpResult @common -Success $history.Success -Message $history.Message -ErrorMessage $history.ErrorText -Data $history
}
