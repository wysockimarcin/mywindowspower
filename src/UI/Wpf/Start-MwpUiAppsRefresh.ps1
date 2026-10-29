function Start-MwpUiAppsRefresh {
    <#
    .SYNOPSIS
        Odczytuje w tle listę programów (Inventory), pakiety winget z aktualizacjami (Packages) albo wyniki wyszukiwania (Search) komputera instancji.

    .DESCRIPTION
        Operacje w puli MWP.Remote (Get-MwpInstalledApp, Get-MwpWingetPackage i Find-MwpWingetPackage
        z -AsOperation; limit czasu, anulowanie z paska stanu, zamknięcie instancji je anuluje). Domyślnie
        (All) — programy i pakiety równolegle; po obu wynikach lista programów jest łączona z winget
        (Join-MwpAppWinget: identyfikator i dostępna aktualizacja). Błąd lub utrata połączenia zmienia
        tylko ten widok (komunikat), nie aplikację (D-019). Komputer zdalny bez poświadczeń: komunikat
        z prośbą o „Połącz”.

    .PARAMETER Kind
        All (domyślnie), Inventory, Packages albo Search.

    .PARAMETER Query
        Zapytanie wyszukiwania (Search).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt (bez zmian systemu).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [ValidateSet('All', 'Inventory', 'Packages', 'Search')]
        [string] $Kind = 'All',

        [AllowEmptyString()]
        [string] $Query = ''
    )

    if ($Kind -eq 'All') {
        Start-MwpUiAppsRefresh -Entry $Entry -Kind Inventory
        Start-MwpUiAppsRefresh -Entry $Entry -Kind Packages
        return
    }
    $context = $Entry.Instance.Context
    $view = $Entry.Apps
    if ($view[$Kind + 'Loading']) {
        return
    }
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        $view[$Kind + 'Error'] = 'Połącz instancję z komputerem {0} (przycisk „Połącz”), żeby odczytać programy.' -f $context.ComputerName
        Update-MwpAppsView -Entry $Entry
        return
    }
    switch ($Kind) {
        'Inventory' {
            $parameters = @{ Context = $context; AsOperation = $true }
            if (@($view.UserSid).Count -gt 0) {
                $parameters['UserSid'] = [string[]]@($view.UserSid)
            }
            $operation = Get-MwpInstalledApp @parameters
            $name = 'Aplikacje: lista programów ({0})' -f $context.ComputerName
        }
        'Packages' {
            $operation = Get-MwpWingetPackage -Context $context -AsOperation
            $name = 'Aplikacje: winget list ({0})' -f $context.ComputerName
        }
        'Search' {
            try {
                $operation = Find-MwpWingetPackage -Context $context -Query $Query -AsOperation
            }
            catch {
                $view.SearchError = 'Niepoprawne zapytanie: użyj liter, cyfr, spacji i znaków . _ + - # (do 100 znaków).'
                Update-MwpAppsView -Entry $Entry
                return
            }
            $view.SearchQuery = $Query
            $name = 'Aplikacje: wyszukiwanie „{0}” ({1})' -f $Query, $context.ComputerName
        }
    }
    $view[$Kind + 'Loading'] = $true
    $view[$Kind + 'Error'] = $null
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation $operation -Name $name -State @{ InstanceId = $Entry.Id; Kind = $Kind } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $kind = [string]$Task.State.Kind
        $view = $entry.Apps
        $view[$kind + 'Loading'] = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $data = $null
        if ($null -ne $result -and $result.Success) {
            $data = switch ($kind) {
                'Inventory' { Resolve-MwpInstalledApp -Data $result }
                'Packages' { Resolve-MwpWingetPackage -Kind List -Data $result }
                'Search' { Resolve-MwpWingetPackage -Kind Search -Data $result }
            }
        }
        if ($null -ne $data -and -not ($kind -eq 'Inventory' -and $data.Error)) {
            $view[$kind] = $data
            $view[$kind + 'Error'] = $(if ($kind -ne 'Inventory' -and -not $data.Success) { [string]$data.Message } else { $null })
            if ($kind -eq 'Inventory') {
                $view.InventoryReadAt = Get-Date
            }
        }
        elseif ($Task.Status -eq 'Cancelled') {
            $view[$kind + 'Error'] = 'Anulowano.'
        }
        else {
            $detail = if ($null -ne $data -and $kind -eq 'Inventory') { $data.Error } elseif ($null -ne $result) { $result.Message } else { $Task.Error }
            $view[$kind + 'Error'] = 'Odczyt nie powiódł się ({0}): {1}' -f $Task.Status, $detail
        }
        if ($null -ne $view.Inventory -and $null -ne $view.Packages -and $view.Packages.Success -and ($kind -eq 'Inventory' -or $kind -eq 'Packages')) {
            $null = Join-MwpAppWinget -App @($view.Inventory.Apps) -Package @($view.Packages.Packages)
        }
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpAppsView -Entry $Entry
}
