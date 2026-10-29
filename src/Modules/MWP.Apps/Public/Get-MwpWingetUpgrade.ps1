function Get-MwpWingetUpgrade {
    <#
    .SYNOPSIS
        Lista pakietów winget z dostępną aktualizacją na komputerze docelowym (funkcja danych widgetu „Aktualizacje programów”).

    .DESCRIPTION
        Operacja klasy Odczyt (D-053): to samo co Get-MwpWingetPackage -UpgradeAvailable, czyli
        winget list --source winget --upgrade-available, bez akceptacji umów. Widget wywołuje funkcję
        danych tylko z -Context, -AsOperation i -WidgetParameters, więc przełącznik -UpgradeAvailable
        jest tu stały. Na komputerze zdalnym winget działa przez jednorazowe zadanie harmonogramu jako
        SYSTEM (D-051) i wymaga konta administratora w połączeniu — inaczej wynik ma czytelny komunikat.
        Odczyt trwa kilka–kilkanaście sekund, dlatego widget domyślnie odświeża się tylko ręcznie.

    .PARAMETER WidgetParameters
        Parametry widgetu „Aktualizacje programów” (Top); liczbę pozycji wybiera funkcja widoku.

    .EXAMPLE
        (Get-MwpWingetUpgrade).Data.Packages | Format-Table Name, Version, Available
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043, D-053); liczbę pozycji wybiera funkcja widoku.')]
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

    Get-MwpWingetPackage -Context $Context -UpgradeAvailable -AsOperation:$AsOperation
}
