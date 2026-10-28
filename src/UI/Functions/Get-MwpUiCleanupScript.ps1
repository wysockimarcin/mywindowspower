function Get-MwpUiCleanupScript {
    <#
    .SYNOPSIS
        Zwraca blok zadania GUI widoku Czyszczenie dysku: skan (Scan) albo czyszczenie zaznaczonych kategorii (Clear).

    .DESCRIPTION
        Używany przez Start-MwpUiCleanupScan i Start-MwpUiCleanup (Start-MwpUiTask; blok jest
        odtwarzany z tekstu w runspace puli GUI, dane przychodzą w parametrach, pierwszy parametr to
        tabela postępu). Moduł MWP.Cleanup jest importowany z podanej ścieżki manifestu. Funkcje logiki
        dostają tabelę postępu (-Progress): ustawiają Percent i Message, a CancelRequested przerywa pracę
        w bezpiecznym miejscu. Czyszczenie odkłada każdy wynik do Progress.Results, więc raport
        powstaje także po przerwaniu. Kod widoku nie wywołuje poleceń systemowych (D-015, D-039).

    .PARAMETER Name
        Scan albo Clear.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Scan', 'Clear')]
        [string] $Name
    )

    if ($Name -eq 'Scan') {
        return {
            param($Progress, [string] $ModulePath, $Context, [bool] $IncludeUserProfiles)
            Import-Module -Name $ModulePath
            Measure-MwpCleanupCategory -Context $Context -IncludeUserProfiles:$IncludeUserProfiles -Progress $Progress
        }
    }
    {
        param($Progress, [string] $ModulePath, $Context, [string[]] $Category, [bool] $IncludeUserProfiles)
        Import-Module -Name $ModulePath
        $Progress.Results = [Collections.ArrayList]::Synchronized((New-Object -TypeName System.Collections.ArrayList))
        foreach ($id in $Category) {
            foreach ($result in @(Clear-MwpCleanupCategory -Category $id -Context $Context -IncludeUserProfiles:$IncludeUserProfiles -Progress $Progress -Confirm:$false)) {
                $null = $Progress.Results.Add($result)
                $result
            }
        }
    }
}
