function Get-MwpUiCredentialPlan {
    <#
    .SYNOPSIS
        Decyduje, skąd wziąć poświadczenie przy „Połącz” instancji lub widgetu: pamięć, magazyn czy okno.

    .DESCRIPTION
        Kolejność D-052 (bez WPF, testowalna): Action =
        - None: połączenie nie potrzebuje nowego poświadczenia (localhost, CurrentUser, poświadczenie
          w kontekście bez odmowy dostępu) — samo połączenie,
        - Cache: sprawdzone hasło komputera jest w pamięci tego uruchomienia — połączenie bez okna,
        - Store: wpis w Menedżerze poświadczeń, zapamiętywanie włączone, hasło nie zostało odrzucone
          w tym uruchomieniu — połączenie bez okna (Connect-MwpTarget -UseStoredCredential; ta jawna
          akcja użytkownika jest pierwszym użyciem zapisanego hasła po starcie),
        - Dialog: okno poświadczeń; OfferSave mówi, czy pokazać pole „Zapamiętaj”, a Notice — ostrzeżenie
          (zapisane hasło odrzucone, błąd odczytu magazynu).
        UserName: podpowiedź konta do okna.

    .PARAMETER State
        Stan połączenia (Get-MwpConnectionStateInfo).

    .PARAMETER Info
        Metadane poświadczeń komputera (Get-MwpTargetCredentialInfo) albo $null.

    .PARAMETER UserName
        Podpowiedź konta z kontekstu (rejestr komputerów).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'UserName i Info są używane w zagnieżdżonym bloku $plan, czego reguła nie widzi.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $State,

        [AllowNull()]
        [object] $Info,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $UserName
    )

    $plan = {
        param([string] $Action, [bool] $OfferSave, [string] $Notice)
        $hint = $UserName
        if ($null -ne $Info -and -not [string]::IsNullOrWhiteSpace([string]$Info.StoredUserName)) {
            $hint = [string]$Info.StoredUserName
        }
        elseif ($null -ne $Info -and -not [string]::IsNullOrWhiteSpace([string]$Info.CachedUserName)) {
            $hint = [string]$Info.CachedUserName
        }
        [pscustomobject]@{
            PSTypeName = 'MWP.UiCredentialPlan'
            Action     = $Action
            OfferSave  = $OfferSave
            Notice     = $(if ([string]::IsNullOrWhiteSpace($Notice)) { $null } else { $Notice })
            UserName   = $hint
        }
    }

    $required = [bool]$State.NeedsCredential -or ([bool]$State.IsRemote -and [string]$State.State -eq 'Unauthorized')
    if (-not [bool]$State.IsRemote -or -not $required) {
        return & $plan 'None' $false $null
    }
    if ($null -ne $Info -and [bool]$Info.Cached) {
        return & $plan 'Cache' $false $null
    }
    $enabled = $null -ne $Info -and [bool]$Info.StoreEnabled
    if ($enabled -and [bool]$Info.Stored -and -not [bool]$Info.Invalid) {
        return & $plan 'Store' $false $null
    }
    $notice = $null
    if ($null -ne $Info -and [bool]$Info.Stored -and [bool]$Info.Invalid) {
        $notice = 'Komputer odrzucił hasło zapisane w Menedżerze poświadczeń Windows (np. zmienione na komputerze zdalnym); w tym uruchomieniu nie jest używane. Podaj aktualne hasło — zaznacz „Zapamiętaj”, aby zastąpić zapisane, albo usuń je w edytorze komputera („Zapomnij hasło”).'
    }
    elseif ($null -ne $Info -and [bool]$Info.Invalid) {
        $notice = 'Komputer odrzucił poprzednie hasło; automatyczne ponowienia są wstrzymane do czasu podania nowego.'
    }
    elseif ($null -ne $Info -and -not [string]::IsNullOrWhiteSpace([string]$Info.StoreError)) {
        $notice = [string]$Info.StoreError
    }
    & $plan 'Dialog' $enabled $notice
}
