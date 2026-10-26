function Show-MwpTargetEditor {
    <#
    .SYNOPSIS
        Formularz dodania albo edycji komputera docelowego; zwraca parametry dla Add-MwpTarget / Set-MwpTarget.

    .DESCRIPTION
        Formularz tylko zbiera dane (walidacja prezentacyjna: wymagana nazwa, port 1–65535); walidację
        nazwy, zapis, podgląd i log wykonują Add-MwpTarget i Set-MwpTarget (MWP.Remote). Bez pola
        hasła (D-034). Zwraca tabelę parametrów albo $null (anulowano).

    .PARAMETER Target
        Edytowany komputer (MWP.Target); bez niego formularz dodaje nowy.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowNull()]
        [object] $Target,

        [AllowNull()]
        [object] $Owner
    )

    $dialog = Import-MwpXaml -Path (Join-Path -Path $script:MwpUi.UiRoot -ChildPath 'Dialogs\TargetEditor.xaml')
    $window = $dialog.Root
    $c = $dialog.Controls
    if ($null -eq $Owner) {
        $Owner = $script:MwpUi.Window
    }
    if ($null -ne $Owner -and $Owner.IsVisible) {
        $window.Owner = $Owner
    }

    $isEdit = $null -ne $Target
    $c['HeaderText'].Text = $(if ($isEdit) { 'Edycja komputera {0}' -f $Target.Name } else { 'Nowy komputer docelowy' })
    $c['AuthCombo'].SelectedIndex = 0
    $c['PortBox'].Text = '5985'
    if ($isEdit) {
        $c['NameBox'].Text = $Target.Name
        $c['NameBox'].IsReadOnly = $true
        $c['DisplayNameBox'].Text = $Target.DisplayName
        $c['UserBox'].Text = $Target.UserName
        $c['PortBox'].Text = [string]$Target.Port
        $c['SslCheck'].IsChecked = [bool]$Target.UseSsl
        $c['AuthCombo'].SelectedIndex = $(if ($Target.Authentication -eq 'CurrentUser') { 1 } else { 0 })
    }
    $c['SslCheck'].Add_Click({
            if ($c['PortBox'].Text -in @('5985', '5986')) {
                $c['PortBox'].Text = $(if ($c['SslCheck'].IsChecked) { '5986' } else { '5985' })
            }
        })

    $state = @{ Result = $null }
    $c['OkButton'].Add_Click({
            $name = $c['NameBox'].Text.Trim()
            $port = 0
            $errors = @()
            if ($name -eq '') { $errors += 'Podaj nazwę komputera.' }
            if (-not [int]::TryParse($c['PortBox'].Text.Trim(), [ref]$port) -or $port -lt 1 -or $port -gt 65535) { $errors += 'Port musi być liczbą od 1 do 65535.' }
            if ($errors.Count -gt 0) {
                $c['ErrorText'].Text = $errors -join ' '
                $c['ErrorText'].Visibility = 'Visible'
                return
            }
            $parameters = @{
                Name           = $name
                Authentication = [string]$c['AuthCombo'].SelectedItem.Tag
                UserName       = $c['UserBox'].Text.Trim()
                Port           = $port
            }
            $display = $c['DisplayNameBox'].Text.Trim()
            if ($display -ne '') {
                $parameters['DisplayName'] = $display
            }
            if ($isEdit) {
                $parameters['UseSsl'] = [bool]$c['SslCheck'].IsChecked
            }
            elseif ($c['SslCheck'].IsChecked) {
                $parameters['UseSsl'] = [switch]$true
            }
            $state.Result = $parameters
            $window.Close()
        })
    $c['CancelButton'].Add_Click({ $window.Close() })

    $null = $window.ShowDialog()
    $state.Result
}
