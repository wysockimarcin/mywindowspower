function Get-MwpAppsActionState {
    <#
    .SYNOPSIS
        Wylicza dostępność przycisków widoku Aplikacje dla zaznaczonej aplikacji, pakietów aktualizacji i wyniku wyszukiwania.

    .DESCRIPTION
        Czysta funkcja (bez WPF). Odinstalowanie: aplikacja niechroniona (lista ochronna i składniki
        systemu — D-050), na komputerze zdalnym administrator, dla programu z rejestru — działający
        winget. Program profilu innego użytkownika (D-051): odinstalowanie w jego sesji — lokalnie
        wymaga administratora, a gdy lista winget tego profilu się nie udała (np. użytkownik nie jest
        zalogowany) — zablokowane z powodem. Aktualizacja i instalacja: winget dostępny, identyfikator
        ze źródła winget, na komputerze zdalnym administrator. UpgradeUserSid — profil, w którego sesji
        aktualizować pakiet zaznaczonej aplikacji (pakiet tylko z listy użytkownika). Reguły i tak
        egzekwują funkcje MWP.Apps (GUI, CLI, komputer zdalny).

    .PARAMETER Inventory
        MWP.AppInventory (ostatni odczyt) albo $null.

    .PARAMETER AppId
        Identyfikator zaznaczonej aplikacji.

    .PARAMETER WingetAvailable
        winget działa na komputerze docelowym (ostatnia lista, uruchomienie podstawowe).

    .PARAMETER Packages
        MWP.WingetList ostatniej listy (przebiegi profili użytkowników i kontekst pakietów) albo $null.

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

        [AllowNull()]
        [object] $Packages = $null,

        [bool] $Remote = $false,

        [bool] $Ready = $true,

        [int] $SelectedUpgrades = 0,

        [bool] $SearchSelected = $false
    )

    $administrator = $null -ne $Inventory -and [bool]$Inventory.IsAdministrator
    $app = if ($null -ne $Inventory -and $AppId) { @($Inventory.Apps | Where-Object { $_.Id -eq $AppId }) | Select-Object -First 1 } else { $null }
    $adminOk = -not $Remote -or $administrator
    $ownerSid = if ($null -ne $app -and $app.Scope -eq 'User' -and $app.UserSid -and $app.UninstallMethod -eq 'Winget') { [string]$app.UserSid } else { '' }
    $otherUser = [bool]$ownerSid -and ($Remote -or $ownerSid -ne [string]$Inventory.CurrentUserSid)
    $userRun = if ($otherUser -and $null -ne $Packages) { @($Packages.Runs | Where-Object { $_.RunAs -eq 'User' -and $_.UserSid -eq $ownerSid }) | Select-Object -First 1 } else { $null }
    $userBlocked = if (-not $otherUser) { '' } elseif (-not $Remote -and -not $administrator) { 'Program profilu {0} — odinstalowanie w jego sesji wymaga uruchomienia aplikacji jako administrator.' -f $app.UserName } elseif ($null -ne $userRun -and -not $userRun.Success) { [string]$userRun.Message } else { '' }
    $methodOk = $null -ne $app -and ($app.UninstallMethod -eq 'Appx' -or ($(if ($otherUser) { $null -eq $userRun -or $userRun.Success } else { $WingetAvailable })))
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
    elseif ($userBlocked) {
        $userBlocked
    }
    elseif (-not $methodOk) {
        'winget jest niedostępny na tym komputerze — programów z rejestru nie można odinstalować.'
    }
    elseif ($otherUser) {
        'Program profilu {0} — winget zadziała w sesji tego użytkownika (musi być zalogowany).{1}' -f $app.UserName, $(if ($app.Warning) { ' ' + $app.Warning } else { '' })
    }
    elseif ($app.Warning) {
        [string]$app.Warning
    }
    else {
        ''
    }
    $change = $Ready -and $adminOk -and $WingetAvailable
    $package = if ($null -ne $app -and $app.WingetId -and $null -ne $Packages) { @($Packages.Packages | Where-Object { $_.Id -eq $app.WingetId }) | Select-Object -First 1 } else { $null }
    $upgradeSid = if ($null -ne $package -and $package.RunAs -eq 'User') { [string]$package.UserSid } else { '' }
    [pscustomobject]@{
        PSTypeName     = 'MWP.AppsActionState'
        App            = $app
        CanUninstall   = $Ready -and $adminOk -and $null -ne $app -and -not $app.IsProtected -and -not $userBlocked -and $methodOk
        CanUpgradeApp  = $change -and $null -ne $app -and [bool]$app.WingetId -and [bool]$app.Available -and -not $userBlocked
        CanUpgrade     = $change -and $SelectedUpgrades -gt 0
        CanInstall     = $change -and $SearchSelected
        CanSearch      = $Ready -and $WingetAvailable
        UpgradeUserSid = $upgradeSid
        Hint           = $hint
    }
}
