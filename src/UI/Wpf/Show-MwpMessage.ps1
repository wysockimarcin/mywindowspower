function Show-MwpMessage {
    <#
    .SYNOPSIS
        Pokazuje okno komunikatu (informacja, ostrzeżenie, błąd) nad oknem aplikacji.

    .PARAMETER Owner
        Okno nadrzędne; domyślnie okno główne.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Text,

        [ValidateNotNullOrEmpty()]
        [string] $Title = 'My Windows Power',

        [ValidateSet('Info', 'Warning', 'Error')]
        [string] $Kind = 'Info',

        [AllowNull()]
        [object] $Owner
    )

    $icon = switch ($Kind) {
        'Warning' { [System.Windows.MessageBoxImage]::Warning }
        'Error' { [System.Windows.MessageBoxImage]::Error }
        default { [System.Windows.MessageBoxImage]::Information }
    }
    if ($null -eq $Owner -and $null -ne $script:MwpUi) {
        $Owner = $script:MwpUi.Window
    }
    $box = 'System.Windows.MessageBox' -as [type]
    if ($null -ne $Owner -and $Owner.IsVisible) {
        $null = $box::Show($Owner, $Text, $Title, [System.Windows.MessageBoxButton]::OK, $icon)
    }
    else {
        $null = $box::Show($Text, $Title, [System.Windows.MessageBoxButton]::OK, $icon)
    }
}
