function Get-MwpTargetCredentialText {
    <#
    .SYNOPSIS
        Opis wskaźnika „hasło zapisane / niezapisane” komputera do edytora komputera (bez WPF).

    .DESCRIPTION
        Na podstawie metadanych Get-MwpTargetCredentialInfo (nigdy hasła, D-052) zwraca: Text (po polsku),
        Tone (Success, Info, Warning, Danger, Neutral), CanForget (jest co zapomnieć: wpis w magazynie
        albo hasło w pamięci aplikacji).

    .PARAMETER Info
        Metadane poświadczeń komputera (MWP.TargetCredentialInfo).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Info
    )

    $when = if ($Info.LastWritten -is [datetime]) { ', zapisane {0}' -f $Info.LastWritten.ToString('yyyy-MM-dd HH:mm') } else { '' }
    $account = if ($Info.StoredUserName) { ' (konto {0}{1})' -f $Info.StoredUserName, $when } else { '' }
    if ([bool]$Info.Stored -and [bool]$Info.Invalid) {
        $text = 'Hasło zapisane w Menedżerze poświadczeń Windows{0} zostało odrzucone przez komputer w tym uruchomieniu i nie jest używane.' -f $account
        $tone = 'Warning'
    }
    elseif ([bool]$Info.Stored) {
        $text = 'Hasło zapisane w Menedżerze poświadczeń Windows{0}, wpis {1}.' -f $account, $Info.Entry
        $tone = 'Success'
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$Info.StoreError)) {
        $text = 'Nie udało się sprawdzić Menedżera poświadczeń: {0}' -f $Info.StoreError
        $tone = 'Danger'
    }
    elseif ([bool]$Info.Cached) {
        $text = 'Hasło niezapisane — jest tylko w pamięci aplikacji do jej zamknięcia.'
        $tone = 'Info'
    }
    elseif ([bool]$Info.Invalid) {
        $text = 'Hasło niezapisane; komputer odrzucił ostatnie hasło w tym uruchomieniu.'
        $tone = 'Warning'
    }
    else {
        $text = 'Hasło niezapisane: aplikacja zapyta o nie przy połączeniu.'
        $tone = 'Neutral'
    }
    if ($Info.StoreEnabled -is [bool] -and -not $Info.StoreEnabled) {
        $text = '{0} Zapamiętywanie haseł jest wyłączone w Ustawieniach.' -f $text
    }
    [pscustomobject]@{
        PSTypeName = 'MWP.UiCredentialText'
        Text       = $text
        Tone       = $tone
        CanForget  = [bool]$Info.Stored -or [bool]$Info.Cached -or [bool]$Info.Invalid -or -not [string]::IsNullOrWhiteSpace([string]$Info.StoreError)
    }
}
