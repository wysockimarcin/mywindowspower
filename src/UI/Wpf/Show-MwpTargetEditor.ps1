function Show-MwpTargetEditor {
    <#
    .SYNOPSIS
        Formularz dodania albo edycji komputera docelowego; zwraca parametry dla Add-MwpTarget / Set-MwpTarget.

    .DESCRIPTION
        Formularz tylko zbiera dane (walidacja prezentacyjna: wymagana nazwa, port 1–65535); walidację
        nazwy i adresu, zapis, podgląd i log wykonują Add-MwpTarget i Set-MwpTarget (MWP.Remote). Bez
        pola hasła (D-034). Przy edycji pokazuje, czy hasło komputera jest zapisane w Menedżerze
        poświadczeń Windows, i przycisk „Zapomnij hasło” (Remove-MwpTargetCredential, D-052).
        D-054: pola „Nazwa komputera” (identyfikator; przy edycji zmiana nazwy = Set-MwpTarget -NewName)
        i „Adres” (opcjonalny adres połączenia); przycisk „Odczytaj nazwę z komputera” łączy się w tle pod
        podany adres (Get-MwpTargetComputerName) z hasłem z pamięci procesu albo z okna poświadczeń (bez
        zapisu) i podpowiada nazwę; ostrzeżenia (Get-MwpTargetEditorWarning) niczego nie blokują.
        Zwraca tabelę parametrów albo $null (anulowano).

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

    $ui = $script:MwpUi
    $dialog = Import-MwpXaml -Path (Join-Path -Path $ui.UiRoot -ChildPath 'Dialogs\TargetEditor.xaml')
    $window = $dialog.Root
    $c = $dialog.Controls
    if ($null -eq $Owner) {
        $Owner = $ui.Window
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
        $c['AddressBox'].Text = $(if ($null -ne $Target.PSObject.Properties['Address']) { [string]$Target.Address } else { '' })
        $c['DisplayNameBox'].Text = $Target.DisplayName
        $c['UserBox'].Text = $Target.UserName
        $c['PortBox'].Text = [string]$Target.Port
        $c['SslCheck'].IsChecked = [bool]$Target.UseSsl
        $c['AuthCombo'].SelectedIndex = $(if ($Target.Authentication -eq 'CurrentUser') { 1 } else { 0 })

        # D-052: tylko metadane (czy zapisane, konto, data); „Zapomnij hasło” działa od razu, bez zapisu formularza.
        $showCredential = {
            $info = @(Get-MwpTargetCredentialInfo -Name $Target.Name) | Select-Object -First 1
            $text = Get-MwpTargetCredentialText -Info $info
            $c['CredentialStatusText'].Text = $text.Text
            $c['ForgetButton'].IsEnabled = $text.CanForget
        }
        & $showCredential
        $c['CredentialPanel'].Visibility = 'Visible'
        $c['ForgetButton'].Add_Click({
                $forget = Remove-MwpTargetCredential -Name $Target.Name -Confirm:$false
                & $showCredential
                if (-not $forget.Success) {
                    $c['ErrorText'].Text = $forget.Message
                    $c['ErrorText'].Visibility = 'Visible'
                }
            })
    }

    # D-054: ostrzeżenia (bez blokady) po zmianie nazwy, adresu albo HTTPS.
    $updateWarning = {
        $name = $c['NameBox'].Text.Trim()
        $address = $c['AddressBox'].Text.Trim()
        $check = $null
        if ($name -ne '') {
            try {
                $check = Test-MwpTargetIsLocalComputer -Name $name -Address $address
            }
            catch {
                $check = $null
            }
        }
        $warnings = @(Get-MwpTargetEditorWarning -Name $name -Address $address -UseSsl ([bool]$c['SslCheck'].IsChecked) -LocalCheck $check)
        if ($isEdit -and $name -ne '' -and -not [string]::Equals($name, [string]$Target.Name, [StringComparison]::Ordinal)) {
            $warnings += ("Zmiana nazwy '{0}' -> '{1}': zapisane hasło, widgety Pulpitu i wpisy cofnięcia tego komputera przejdą na nową nazwę (podsumowanie w następnym kroku). Otwarte instancje tego komputera trzeba najpierw zamknąć." -f $Target.Name, $name)
        }
        $c['WarningText'].Text = $warnings -join [Environment]::NewLine
        $c['WarningPanel'].Visibility = $(if ($warnings.Count -gt 0) { 'Visible' } else { 'Collapsed' })
    }
    $c['NameBox'].Add_LostFocus({ & $updateWarning })
    $c['AddressBox'].Add_LostFocus({ & $updateWarning })
    $c['SslCheck'].Add_Click({
            if ($c['PortBox'].Text -in @('5985', '5986')) {
                $c['PortBox'].Text = $(if ($c['SslCheck'].IsChecked) { '5986' } else { '5985' })
            }
            & $updateWarning
        })
    & $updateWarning

    # D-054: „Odczytaj nazwę z komputera” — połączenie w tle pod adres, podpowiedź nazwy (bez zapisu formularza).
    $state = @{ Result = $null; ReadTask = $null }
    $c['ReadNameButton'].Add_Click({
            $address = $c['AddressBox'].Text.Trim()
            if ($address -eq '') {
                $address = $c['NameBox'].Text.Trim()
            }
            if ($address -eq '') {
                $c['ReadNameText'].Text = 'Podaj adres (albo nazwę), pod którym jest komputer.'
                $c['ReadNameText'].Visibility = 'Visible'
                return
            }
            $port = 0
            if (-not [int]::TryParse($c['PortBox'].Text.Trim(), [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
                $port = $(if ($c['SslCheck'].IsChecked) { 5986 } else { 5985 })
            }
            $credential = $null
            $cachedTarget = ''
            if ([string]$c['AuthCombo'].SelectedItem.Tag -eq 'Credential') {
                $info = $null
                if ($isEdit) {
                    $info = @(Get-MwpTargetCredentialInfo -Name $Target.Name -SkipStore) | Select-Object -First 1
                }
                if ($null -ne $info -and $info.Cached) {
                    $cachedTarget = [string]$Target.Name
                }
                else {
                    $answer = Show-MwpCredentialDialog -ComputerName $address -UserName $c['UserBox'].Text.Trim() -Owner $window
                    if ($null -eq $answer) {
                        return
                    }
                    $credential = $answer.Credential
                }
            }
            $c['ReadNameButton'].IsEnabled = $false
            $c['ReadNameText'].Text = "Łączenie z '{0}'…" -f $address
            $c['ReadNameText'].Visibility = 'Visible'
            $state.ReadTask = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Odczyt nazwy komputera: {0}' -f $address) -State $c `
                -ArgumentList $address, $port, ([bool]$c['SslCheck'].IsChecked), $credential, $cachedTarget -ScriptBlock {
                param($Progress, [string] $Address, [int] $Port, [bool] $UseSsl, [System.Management.Automation.PSCredential] $Credential, [string] $CachedTarget)
                $Progress.Message = 'połączenie i odczyt nazwy'
                Get-MwpTargetComputerName -Address $Address -Port $Port -UseSsl:$UseSsl -Credential $Credential -CachedTarget $CachedTarget
            } -OnCompleted {
                param($Task)
                $controls = $Task.State
                $controls['ReadNameButton'].IsEnabled = $true
                $result = @($Task.Output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
                if ($null -eq $result) {
                    $controls['ReadNameText'].Text = 'Nie udało się odczytać nazwy: {0}' -f $(if ($Task.Error) { $Task.Error } else { $Task.Status })
                    return
                }
                if (-not $result.Success) {
                    $controls['ReadNameText'].Text = $result.Message
                    return
                }
                $suggested = [string]$result.Data.SuggestedName
                $addresses = @($result.Data.DetectedAddresses)
                $controls['ReadNameText'].Text = '{0} Nazwa wpisana w pole „Nazwa komputera”{1}.' -f $result.Message,
                $(if ($addresses.Count -gt 0) { '; adresy komputera: {0}' -f ($addresses -join ', ') } else { '' })
                $previousName = $controls['NameBox'].Text.Trim()
                if ($controls['AddressBox'].Text.Trim() -eq '' -and $previousName -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    # Wpis zapisany pod adresem IP: adres przechodzi do pola „Adres”, a nazwa — do pola „Nazwa”.
                    $controls['AddressBox'].Text = $previousName
                }
                if ($suggested -ne '') {
                    $controls['NameBox'].Text = $suggested
                }
                $controls['NameBox'].Focus()
            }
        })

    $c['OkButton'].Add_Click({
            $name = $c['NameBox'].Text.Trim()
            $address = $c['AddressBox'].Text.Trim()
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
                Name           = $(if ($isEdit) { [string]$Target.Name } else { $name })
                Authentication = [string]$c['AuthCombo'].SelectedItem.Tag
                UserName       = $c['UserBox'].Text.Trim()
                Port           = $port
            }
            # Przy edycji tylko zmienione pola: niezmieniony adres i nazwa wyświetlana pozwalają Set-MwpTarget -NewName
            # przenieść stary adres IP do pola adresu i nazwę wyświetlaną równą starej nazwie na nową.
            $oldAddress = if ($isEdit -and $null -ne $Target.PSObject.Properties['Address']) { [string]$Target.Address } else { '' }
            if ((-not $isEdit -and $address -ne '') -or ($isEdit -and $address -ne $oldAddress)) {
                $parameters['Address'] = $address
            }
            $display = $c['DisplayNameBox'].Text.Trim()
            if ($display -ne '' -and (-not $isEdit -or $display -ne [string]$Target.DisplayName)) {
                $parameters['DisplayName'] = $display
            }
            if ($isEdit) {
                $parameters['UseSsl'] = [bool]$c['SslCheck'].IsChecked
                if (-not [string]::Equals($name, [string]$Target.Name, [StringComparison]::Ordinal)) {
                    $parameters['NewName'] = $name
                }
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
