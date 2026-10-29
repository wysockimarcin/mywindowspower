function Get-MwpTweaksWidgetData {
    <#
    .SYNOPSIS
        Funkcja danych widgetu-zalążka modułu MWP.Tweaks (D-053): nazwa komputera, wersja modułu i informacja, że pełny widget powstaje w FAZIE 13.

    .DESCRIPTION
        Moduł jest zalążkiem (prywatność i tweaki — FAZA 13), a każdy moduł deklaruje widget (D-053). Widget ma
        w manifeście Enabled = $false: nie ma go na liście „Dodaj widżet”, dopóki użytkownik go nie
        włączy w widoku „Moduły”. FAZA 13 zastąpi go widgetem z danymi obszaru. Operacja klasy
        Odczyt: blok w tle zwraca tylko nazwę komputera i czas.

    .PARAMETER WidgetParameters
        Parametry widgetu (kontrakt D-043); widget-zalążek nie ma parametrów.

    .EXAMPLE
        Wait-MwpOperation (Get-MwpTweaksWidgetData -Context (New-MwpExecutionContext) -AsOperation)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043).')]
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

    $operation = 'Tweaks.WidgetData'
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            Module  = $MyInvocation.MyCommand.Module.Name
            Version = [string]$MyInvocation.MyCommand.Module.Version
            Phase   = 13
        })
    $block = {
        param([string] $RequestJson)
        $request = ConvertFrom-Json -InputObject $RequestJson
        ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                Kind         = 'MWP.ModuleSeedWidgetRaw'
                ComputerName = $env:COMPUTERNAME
                CollectedAt  = (Get-Date).ToString('o')
                Module       = [string]$request.Module
                Version      = [string]$request.Version
                Phase        = [int]$request.Phase
            })
    }
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    New-MwpResult @common -Success $true -Message 'Moduł MWP.Tweaks jest zalążkiem (FAZA 13).' -Data $result.Data
}
