function Get-MwpOwnerWindow {
    <#
    .SYNOPSIS
        Zwraca okno, w którym leży kontrolka (okno główne albo osobne okno instancji).

    .DESCRIPTION
        Okna dialogowe otwierane z widoku instancji w osobnym oknie mają to okno jako nadrzędne,
        żeby pojawiły się nad nim, a nie nad oknem głównym.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [AllowNull()]
        [object] $Element
    )

    $window = $null
    if ($Element -is [System.Windows.DependencyObject]) {
        $windowType = 'System.Windows.Window' -as [type]
        $window = $windowType::GetWindow($Element)
    }
    if ($null -eq $window) {
        $window = $script:MwpUi.Window
    }
    $window
}
