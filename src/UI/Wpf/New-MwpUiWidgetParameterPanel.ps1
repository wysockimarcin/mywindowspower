function New-MwpUiWidgetParameterPanel {
    <#
    .SYNOPSIS
        Wypełnia panel WPF kontrolkami parametrów widgetu i zwraca funkcję odczytu (Parameters, Problem).

    .DESCRIPTION
        Wspólne kontrolki dla okna widgetu i sekcji „Widżety” widoku „Moduły” (D-053). Pola opisuje
        Get-MwpWidgetParameterField, wynik składa ConvertFrom-MwpWidgetParameterInput (logika bez WPF).
        Zwraca tabelę: Fields (pola), Read (blok bez argumentów zwracający Parameters i Problem).

    .PARAMETER Panel
        Panel (StackPanel), którego zawartość zostanie zastąpiona.

    .PARAMETER Field
        Pola z Get-MwpWidgetParameterField.

    .PARAMETER OnChange
        Opcjonalny blok wywoływany po zmianie pola wyboru albo wyjściu z pola tekstowego (np. zapis od razu).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Panel,

        [AllowEmptyCollection()]
        [object[]] $Field = @(),

        [AllowNull()]
        [scriptblock] $OnChange
    )

    $Panel.Children.Clear()
    $inputs = @{}
    foreach ($item in @($Field | Where-Object { $null -ne $_ })) {
        $label = New-Object -TypeName System.Windows.Controls.TextBlock
        $label.Text = $item.Label
        $label.Margin = '0,6,0,2'
        $label.TextWrapping = 'Wrap'
        $null = $Panel.Children.Add($label)
        switch ($item.Kind) {
            'Choices' {
                $wrap = New-Object -TypeName System.Windows.Controls.WrapPanel
                $boxes = @{}
                foreach ($option in @($item.Options)) {
                    $box = New-Object -TypeName System.Windows.Controls.CheckBox
                    $box.Content = $option.Text
                    $box.IsChecked = [bool]$option.Checked
                    $box.Margin = '0,2,16,2'
                    if ($null -ne $OnChange) {
                        $box.Add_Click($OnChange)
                    }
                    $null = $wrap.Children.Add($box)
                    $boxes[$option.Value] = $box
                }
                $null = $Panel.Children.Add($wrap)
                $inputs[$item.Key] = @{ Kind = 'Choices'; Boxes = $boxes }
            }
            'Bool' {
                $box = New-Object -TypeName System.Windows.Controls.CheckBox
                $box.Content = 'Włączone'
                $box.IsChecked = [bool]$item.Checked
                if ($null -ne $OnChange) {
                    $box.Add_Click($OnChange)
                }
                $null = $Panel.Children.Add($box)
                $inputs[$item.Key] = @{ Kind = 'Bool'; Control = $box }
            }
            default {
                $box = New-Object -TypeName System.Windows.Controls.TextBox
                $box.Text = $item.Text
                if ($null -ne $OnChange) {
                    $box.Add_LostFocus($OnChange)
                }
                $null = $Panel.Children.Add($box)
                $inputs[$item.Key] = @{ Kind = $item.Kind; Control = $box }
            }
        }
    }
    $fields = @($Field)
    $read = {
        $entry = @{}
        foreach ($key in @($inputs.Keys)) {
            $control = $inputs[$key]
            $entry[$key] = switch ($control.Kind) {
                'Choices' { , @($control.Boxes.Keys | Where-Object { $control.Boxes[$_].IsChecked }) }
                'Bool' { [bool]$control.Control.IsChecked }
                default { $control.Control.Text }
            }
        }
        ConvertFrom-MwpWidgetParameterInput -Field $fields -Entry $entry
    }.GetNewClosure()
    @{ Fields = $fields; Read = $read }
}
