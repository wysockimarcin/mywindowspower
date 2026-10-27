function Get-MwpUiChangeScript {
    <#
    .SYNOPSIS
        Zwraca blok zadania GUI, który wykonuje kroki zmian modułu (funkcje logiki z -WhatIf albo -Confirm:$false) dla kontekstu instancji.

    .DESCRIPTION
        Używany przez Invoke-MwpUiInstanceChange (Start-MwpUiTask; blok jest odtwarzany z tekstu
        w runspace puli GUI, więc dane przychodzą w parametrach). Pierwszy parametr to tabela postępu.
        Moduł logiki jest importowany z podanej ścieżki manifestu (pula GUI ma tylko MWP.Core
        i MWP.Remote). Każdy krok { Command; Parameters; Label } dostaje kontekst instancji; wynik
        to { Index; Result } — ostatni MWP.Result zwrócony przez krok. Kod widoku nie wywołuje
        poleceń systemowych: kroki to funkcje *-Mwp* (D-015, D-039).
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    {
        param($Progress, [string] $ModulePath, $Context, [object[]] $Steps, [bool] $Preview)
        if ($ModulePath) {
            Import-Module -Name $ModulePath
        }
        $index = 0
        foreach ($step in $Steps) {
            if ($Progress.CancelRequested) {
                break
            }
            $Progress.Message = [string]$step.Label
            $parameters = @{}
            foreach ($key in $step.Parameters.Keys) {
                $parameters[$key] = $step.Parameters[$key]
            }
            $parameters['Context'] = $Context
            if ($Preview) {
                $parameters['WhatIf'] = $true
            }
            else {
                $parameters['Confirm'] = $false
            }
            $output = @(& $step.Command @parameters)
            [pscustomobject]@{
                Index  = $index
                Result = @($output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
            }
            $index++
        }
    }
}
