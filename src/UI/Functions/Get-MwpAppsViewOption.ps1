function Get-MwpAppsViewOption {
    <#
    .SYNOPSIS
        Opcje list wyboru widoku Aplikacje: źródło (Source) i zakres (Scope) — etykieta po polsku i wartość dla Select-MwpInstalledApp.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Source', 'Scope')]
        [string] $Kind
    )

    $items = switch ($Kind) {
        'Source' { @(@('Wszystkie źródła', 'All'), @('Rejestr (programy)', 'Registry'), @('Pakiety Appx', 'Appx')) }
        'Scope' { @(@('Komputer i użytkownik', 'All'), @('Cały komputer', 'Machine'), @('Użytkownik', 'User')) }
    }
    foreach ($item in $items) {
        [pscustomobject]@{ PSTypeName = 'MWP.UiOption'; Label = $item[0]; Value = $item[1] }
    }
}
