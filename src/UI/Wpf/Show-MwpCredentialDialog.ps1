function Show-MwpCredentialDialog {
    <#
    .SYNOPSIS
        Pyta o poświadczenia do komputera zdalnego; zwraca MWP.CredentialDialogResult (Credential, Save) albo $null (anulowano).

    .DESCRIPTION
        Warstwa UI wyświetla okno poświadczeń; logika (MWP.Remote) nigdy o nie nie pyta (D-034).
        Hasło pochodzi z PasswordBox.SecurePassword (SecureString) i nie trafia do tekstu, logu
        ani pliku. Własne okno zamiast Get-Credential, bo w PowerShell 7 Get-Credential pyta
        w konsoli, a nie w oknie. Z -OfferSave okno pokazuje pole „Zapamiętaj w Menedżerze
        poświadczeń Windows” — zawsze domyślnie niezaznaczone (D-052); Save = $true tylko po jego
        zaznaczeniu. Zapis wykonuje Connect-MwpTarget -SaveCredential po udanym połączeniu, w tle.

    .PARAMETER ComputerName
        Komputer, do którego dotyczą poświadczenia (pokazany w oknie).

    .PARAMETER UserName
        Podpowiedź konta z rejestru komputerów albo z zapisanego wpisu.

    .PARAMETER OfferSave
        Pokaż pole „Zapamiętaj” (zapamiętywanie włączone w Ustawieniach).

    .PARAMETER Notice
        Ostrzeżenie nad formularzem (np. że zapisane hasło zostało odrzucone).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [AllowEmptyString()]
        [AllowNull()]
        [string] $UserName,

        [AllowNull()]
        [object] $Owner,

        [switch] $OfferSave,

        [AllowEmptyString()]
        [AllowNull()]
        [string] $Notice
    )

    $dialog = Import-MwpXaml -Path (Join-Path -Path $script:MwpUi.UiRoot -ChildPath 'Dialogs\Credential.xaml')
    $window = $dialog.Root
    $c = $dialog.Controls
    if ($null -eq $Owner) {
        $Owner = $script:MwpUi.Window
    }
    if ($null -ne $Owner -and $Owner.IsVisible) {
        $window.Owner = $Owner
    }
    $c['ComputerText'].Text = 'Komputer: {0}' -f $ComputerName
    $c['UserBox'].Text = [string]$UserName
    $c['SaveCheck'].IsChecked = $false
    $c['SavePanel'].Visibility = $(if ($OfferSave) { 'Visible' } else { 'Collapsed' })
    if (-not [string]::IsNullOrWhiteSpace($Notice)) {
        $c['NoticeText'].Text = $Notice
        $c['NoticeText'].Visibility = 'Visible'
    }

    $state = @{ Result = $null }
    $c['OkButton'].Add_Click({
            $user = $c['UserBox'].Text.Trim()
            if ($user -eq '' -or $c['PasswordInput'].SecurePassword.Length -eq 0) {
                $c['ErrorText'].Text = 'Podaj konto i hasło.'
                $c['ErrorText'].Visibility = 'Visible'
                return
            }
            $secure = $c['PasswordInput'].SecurePassword.Copy()
            $secure.MakeReadOnly()
            $state.Result = [pscustomobject]@{
                PSTypeName = 'MWP.CredentialDialogResult'
                Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $secure
                Save       = [bool]$OfferSave -and [bool]$c['SaveCheck'].IsChecked
            }
            $window.Close()
        })
    $c['CancelButton'].Add_Click({ $window.Close() })
    $window.Add_ContentRendered({
            if ($c['UserBox'].Text -eq '') { $null = $c['UserBox'].Focus() } else { $null = $c['PasswordInput'].Focus() }
        })

    $null = $window.ShowDialog()
    $c['PasswordInput'].Clear()
    $state.Result
}
