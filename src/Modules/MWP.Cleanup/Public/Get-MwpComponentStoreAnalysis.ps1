function Get-MwpComponentStoreAnalysis {
    <#
    .SYNOPSIS
        Analizuje magazyn składników Windows (WinSxS) na komputerze docelowym: DISM /Online /Cleanup-Image /AnalyzeComponentStore.

    .DESCRIPTION
        Operacja klasy Odczyt — tylko analiza, bez czyszczenia (D-047; /StartComponentCleanup nie jest
        wykonywane). DISM działa na komputerze docelowym z przełącznikiem /English (wynik niezależny od
        języka systemu), wymaga administratora (bez niego DISM nie jest uruchamiany) i trwa zwykle
        od kilkudziesięciu sekund do kilku minut. Bez -AsOperation zwraca MWP.Result
        z MWP.ComponentStoreAnalysis w Data; z -AsOperation startuje w puli runspace'ów
        (Start-MwpOperation, limit czasu -TimeoutSeconds) i zwraca uchwyt MWP.Operation — wynik
        zamienia Resolve-MwpComponentStoreAnalysis. Anulowanie operacji przerywa oczekiwanie, ale
        uruchomiony już proces dism.exe kończy analizę sam (nic nie zmienia).

    .EXAMPLE
        (Get-MwpComponentStoreAnalysis).Data | Format-List ActualSizeText, BackupsText, CleanupRecommended
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidateRange(60, 86400)]
        [int] $TimeoutSeconds = 3600,

        [switch] $AsOperation
    )

    $operation = 'Cleanup.AnalyzeComponentStore'
    $block = Get-MwpCleanupScript -Name ComponentStore
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -Operation $operation -TimeoutSeconds $TimeoutSeconds
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -Operation $operation -TimeoutSeconds $TimeoutSeconds
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    $analysis = Resolve-MwpComponentStoreAnalysis -Data $result -ComputerName $Context.ComputerName
    if ($null -eq $analysis) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił wyniku analizy magazynu składników." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
    }
    New-MwpResult @common -Success $analysis.Success -Message $analysis.Message -ErrorMessage $(if ($analysis.Success) { $null } else { $analysis.ErrorText }) -Data $analysis
}
