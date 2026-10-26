function Update-MwpAboutView {
    <#
    .SYNOPSIS
        Odświeża „O programie": wersje (host, PowerShell, Windows), środowisko i stan katalogu danych.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $ui = $script:MwpUi
    $environment = $ui.Environment
    $location = Get-MwpDataLocation
    $remote = Get-Module -Name 'MWP.Remote'
    $definitions = @($ui.Definitions)
    $View.Controls['AboutList'].ItemsSource = @(
        [pscustomobject]@{ Key = 'Wersja hosta (MWP.Core)'; Value = [string]$environment.HostVersion }
        [pscustomobject]@{ Key = 'MWP.Remote'; Value = $(if ($null -ne $remote) { [string]$remote.Version } else { '(nie załadowano)' }) }
        [pscustomobject]@{ Key = 'PowerShell'; Value = '{0} ({1}) · {2}' -f $environment.PSVersion, $environment.PSEdition, $environment.HostPath }
        [pscustomobject]@{ Key = 'Windows'; Value = '{0}{1}' -f $environment.OSVersion, $(if ($environment.IsWindows11) { ' (Windows 11)' } else { ' (nie Windows 11)' }) }
        [pscustomobject]@{ Key = 'Administrator'; Value = $(if ($environment.IsAdmin) { 'tak' } else { 'nie (operacje wymagające uprawnień poproszą o nie osobno)' }) }
        [pscustomobject]@{ Key = 'Wątek okna'; Value = [string]$environment.ApartmentState }
        [pscustomobject]@{ Key = 'Folder aplikacji'; Value = $ui.AppRoot }
        [pscustomobject]@{ Key = 'Katalog danych'; Value = '{0}{1}' -f $location.Root, $(if ($location.IsFallback) { ' (tryb zapasowy)' } else { '' }) }
        [pscustomobject]@{ Key = 'Moduły z paczek'; Value = $location.Modules }
        [pscustomobject]@{ Key = 'Moduły'; Value = 'wykryte: {0}, poprawne: {1}, z paczek: {2}' -f $definitions.Count, @($definitions | Where-Object { $_.IsValid }).Count, @($definitions | Where-Object { $_.Source -eq 'Installed' }).Count }
        [pscustomobject]@{ Key = 'Otwarte instancje'; Value = [string]$ui.Instances.Count }
        [pscustomobject]@{ Key = 'Repozytorium'; Value = 'https://github.com/wysockimarcin/mywindowspower' }
    )
    if ($location.IsFallback) {
        $View.Controls['DataWarningText'].Text = $location.Warning
        $View.Controls['DataWarningBanner'].Visibility = 'Visible'
    }
    else {
        $View.Controls['DataWarningBanner'].Visibility = 'Collapsed'
    }
}
