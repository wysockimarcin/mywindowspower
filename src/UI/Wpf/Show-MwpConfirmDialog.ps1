function Show-MwpConfirmDialog {
    <#
    .SYNOPSIS
        Pokazuje okno potwierdzenia z „Podglądem zmian" i zwraca $true, gdy użytkownik potwierdził.

    .DESCRIPTION
        Wspólne okno potwierdzenia hosta (FAZA 4): nagłówek, klasa operacji (Zmiana / Destrukcyjna,
        D-027), cel, komputer docelowy (zawsze, D-019), linie podglądu (zwykle z wyniku funkcji
        logiki wywołanej z -WhatIf, ConvertTo-MwpPreviewLine) i ostrzeżenie. Dla operacji
        destrukcyjnej można wymagać wpisania tekstu (np. nazwy modułu), zanim przycisk zadziała.
        Domyślnym przyciskiem (Enter) jest „Anuluj".

    .PARAMETER RequireText
        Tekst, który użytkownik musi wpisać, żeby potwierdzić.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Header,

        [AllowEmptyString()]
        [string] $Target = '',

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [AllowEmptyCollection()]
        [string[]] $PreviewLine = @(),

        [ValidateSet('Change', 'Destructive', 'Read')]
        [string] $Class = 'Change',

        [AllowEmptyString()]
        [string] $Warning = '',

        [AllowEmptyString()]
        [string] $RequireText = '',

        [ValidateNotNullOrEmpty()]
        [string] $ConfirmText = 'Wykonaj',

        [AllowNull()]
        [object] $Owner
    )

    $dialog = Import-MwpXaml -Path (Join-Path -Path $script:MwpUi.UiRoot -ChildPath 'Dialogs\Confirm.xaml')
    $window = $dialog.Root
    $c = $dialog.Controls
    if ($null -eq $Owner) {
        $Owner = $script:MwpUi.Window
    }
    if ($null -ne $Owner -and $Owner.IsVisible) {
        $window.Owner = $Owner
    }
    else {
        $window.WindowStartupLocation = 'CenterScreen'
    }

    $window.Title = $Header
    $c['HeaderText'].Text = $Header
    $c['ClassBadge'].DataContext = switch ($Class) {
        'Destructive' { [pscustomobject]@{ Label = 'Operacja destrukcyjna'; Tone = 'Danger' } }
        'Read' { [pscustomobject]@{ Label = 'Odczyt'; Tone = 'Info' } }
        default { [pscustomobject]@{ Label = 'Zmiana'; Tone = 'Warning' } }
    }
    $c['TargetText'].Text = $Target
    $c['ComputerText'].Text = 'Komputer docelowy: {0}' -f (Format-MwpTargetLabel -ComputerName $ComputerName)
    $c['PreviewList'].ItemsSource = @($(if ($PreviewLine.Count -gt 0) { $PreviewLine } else { @('(brak szczegółów podglądu)') }))
    if ($Warning) {
        $c['WarningText'].Text = $Warning
        $c['WarningBanner'].Visibility = 'Visible'
    }
    $c['ConfirmButton'].Content = $ConfirmText
    if ($Class -eq 'Destructive') {
        $c['ConfirmButton'].Style = $window.FindResource('Mwp.Button.Danger')
    }

    $state = @{ Confirmed = $false }
    if ($RequireText) {
        $c['TypedPanel'].Visibility = 'Visible'
        $c['TypedLabel'].Text = "Aby potwierdzić, wpisz: {0}" -f $RequireText
        $c['ConfirmButton'].IsEnabled = $false
        $c['TypedBox'].Add_TextChanged({
                $c['ConfirmButton'].IsEnabled = $c['TypedBox'].Text -ceq $RequireText
            })
    }
    $c['ConfirmButton'].Add_Click({
            $state.Confirmed = $true
            $window.Close()
        })
    $c['CancelButton'].Add_Click({ $window.Close() })

    $null = $window.ShowDialog()
    [bool]$state.Confirmed
}
