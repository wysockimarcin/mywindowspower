function Resume-MwpUiTargetWidget {
    <#
    .SYNOPSIS
        Po udanym połączeniu z komputerem wznawia widgety tego komputera czekające na poświadczenia.

    .DESCRIPTION
        Sprawdzone hasło komputera jest w pamięci procesu (D-052), więc widgety tego komputera w stanie
        NeedsCredential (bez trwającego zadania) dostają Pending i harmonogram odświeży je przy
        najbliższym tyknięciu zegara — bez okna i bez ponownego pytania. Widgety innych komputerów
        nie są zmieniane (D-019). Zwraca liczbę wznowionych widgetów.

    .PARAMETER Widget
        Widgety Dashboardu (tabele z New-MwpWidgetRuntime).

    .PARAMETER ComputerName
        Komputer, z którym właśnie się połączono.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko stan widgetów w pamięci okna.')]
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $Widget = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    $count = 0
    foreach ($item in @($Widget)) {
        if ($null -eq $item -or $item.Removed -or $null -ne $item.Task -or $null -eq $item.Instance) {
            continue
        }
        if ($item.Instance.Context.ComputerName -ne $ComputerName -or $item.Status -ne 'NeedsCredential') {
            continue
        }
        $item.Pending = $true
        $item.Message = $null
        $item.Version++
        $count++
    }
    $count
}
