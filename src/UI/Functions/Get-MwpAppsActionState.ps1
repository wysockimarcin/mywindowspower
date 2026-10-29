function Get-MwpAppsActionState {
    <#
    .SYNOPSIS
        Wylicza dostępność przycisków widoku Aplikacje dla zaznaczonej aplikacji, pakietów aktualizacji i wyniku wyszukiwania.

    .DESCRIPTION
        Czysta funkcja (bez WPF). Odinstalowanie: aplikacja niechroniona (lista ochronna i składniki
        systemu — D-050), na komputerze zdalnym administrator i program komputera albo konta połączenia,
        dla programu z rejestru — działający winget. Aktualizacja i instalacja: winget dostępny,
        identyfikator ze źródła winget, na komputerze zdalnym administrator. Reguły i tak egzekwują
        funkcje MWP.Apps (GUI, CLI, komputer zdalny).

    .PARAMETER Inventory
        MWP.AppInventory (ostatni odczyt) albo $null.

    .PARAMETER AppId
        Identyfikator zaznaczonej aplikacji.

    .PARAMETER WingetAvailable
        winget działa na komputerze docelowym (ostatnia lista).

    .PARAMETER Remote
        Komputer zdalny.

    .PARAMETER Ready
        Połączono i nie trwa żadne zadanie widoku ani zmiana.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Inventory,

        [AllowEmptyString()]
        [string] $AppId = '',

        [bool] $WingetAvailable = $false,

        [bool] $Remote = $false,

        [bool] $Ready = $true,

        [int] $SelectedUpgrades = 0,

        [bool] $SearchSelected = $false
    )

    $administrator = $null -ne $Inventory -and [bool]$Inventory.IsAdministrator
    $app = if ($null -ne $Inventory -and $AppId) { @($Inventory.Apps | Where-Object { $_.Id -eq $AppId }) | Select-Object -First 1 } else { $null }
    $adminOk = -not $Remote -or $administrator
    $otherUser = $null -ne $app -and $app.Scope -eq 'User' -and $app.UserSid -and $app.UserSid -ne $Inventory.CurrentUserSid
    $methodOk = $null -ne $app -and ($app.UninstallMethod -eq 'Appx' -or $WingetAvailable)
    $hint = if ($null -eq $Inventory) {
        ''
    }
    elseif ($null -eq $app) {
        'Wybierz aplikację z listy.'
    }
    elseif ($app.IsProtected) {
        'Chroniona: {0}' -f $app.ProtectedReason
    }
    elseif (-not $adminOk) {
        'Zmiany na komputerze zdalnym wymagają konta administratora w połączeniu.'
    }
    elseif ($otherUser) {
        'Program profilu {0} — odinstalowanie tylko z jego konta.' -f $app.UserName
    }
    elseif (-not $methodOk) {
        'winget jest niedostępny na tym komputerze — programów z rejestru nie można odinstalować.'
    }
    elseif ($app.Warning) {
        [string]$app.Warning
    }
    else {
        ''
    }
    $change = $Ready -and $adminOk -and $WingetAvailable
    [pscustomobject]@{
        PSTypeName     = 'MWP.AppsActionState'
        App            = $app
        CanUninstall   = $Ready -and $adminOk -and $null -ne $app -and -not $app.IsProtected -and -not $otherUser -and $methodOk
        CanUpgradeApp  = $change -and $null -ne $app -and [bool]$app.WingetId -and [bool]$app.Available
        CanUpgrade     = $change -and $SelectedUpgrades -gt 0
        CanInstall     = $change -and $SearchSelected
        CanSearch      = $Ready -and $WingetAvailable
        Hint           = $hint
    }
}
