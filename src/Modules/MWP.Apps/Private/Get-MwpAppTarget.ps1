function Get-MwpAppTarget {
    <#
    .SYNOPSIS
        Znajduje aplikację do odinstalowania na komputerze docelowym: inwentarz (rejestr, Appx) połączony z listą winget.

    .DESCRIPTION
        -AppId: identyfikator z Resolve-MwpInstalledApp (Registry:…, Appx:…); dla programu profilu
        użytkownika odczytywany jest ten profil (SID z identyfikatora). -WingetId: identyfikator
        źródła albo lokalny (ARP\…, MSIX\…) — aplikacja z inwentarza o tym identyfikatorze, a bez niej
        pakiet z winget list (nazwa i wersja z winget). Lista winget jest czytana zawsze, gdy winget
        działa (identyfikator źródła = możliwość cofnięcia). Wynik: Success, App, Inventory, WingetOk,
        Message, NotFound (aplikacji nie ma na komputerze), Result (MWP.Result błędu połączenia).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [string] $AppId = '',

        [string] $WingetId = ''
    )

    $fail = { param($Message, $Result, $NotFound) [pscustomobject]@{ Success = $false; NotFound = [bool]$NotFound; App = $null; Inventory = $null; WingetOk = $false; Message = $Message; Result = $Result } }
    $userSid = @()
    if ($AppId -match '^Registry:User:[^:]*:(S-1-5-21-[0-9-]+):') {
        $userSid = @($Matches[1])
    }
    $read = Get-MwpInstalledApp -Context $Context -UserSid $userSid
    if (-not $read.Success) {
        return & $fail $read.Message $read $false
    }
    $inventory = $read.Data
    $list = Get-MwpWingetPackage -Context $Context
    $wingetOk = $list.Success
    $packages = if ($wingetOk) { @($list.Data.Packages) } else { @() }
    $null = Join-MwpAppWinget -App $inventory.Apps -Package $packages

    $app = $null
    if ($AppId) {
        $app = @($inventory.Apps | Where-Object { $_.Id -eq $AppId }) | Select-Object -First 1
        if ($null -eq $app) {
            return & $fail ("Na komputerze '{0}' nie ma już aplikacji o identyfikatorze '{1}' (odśwież listę)." -f $Context.ComputerName, $AppId) $null $true
        }
    }
    else {
        $app = @($inventory.Apps | Where-Object { $_.WingetId -eq $WingetId -or $_.WingetLocalId -eq $WingetId }) | Select-Object -First 1
        if ($null -eq $app) {
            $package = @($packages | Where-Object { $_.Id -eq $WingetId }) | Select-Object -First 1
            if ($null -eq $package) {
                $message = if ($wingetOk) { "Na komputerze '{0}' nie ma zainstalowanego pakietu '{1}'." -f $Context.ComputerName, $WingetId } else { $list.Message }
                return & $fail $message $null $wingetOk
            }
            $app = [pscustomobject]@{
                PSTypeName = 'MWP.App'; Id = 'Winget:' + $package.Id; Source = 'Winget'; SourceText = 'winget'; Name = $package.Name; Version = $package.Version
                Publisher = ''; Scope = ''; ScopeText = ''; UserSid = ''; WingetLocalId = ''; WingetId = $package.Id; WingetName = $package.Name
                Available = $package.Available; IsProtected = $false; ProtectedReason = ''; Warning = ''; UninstallMethod = 'Winget'
                PackageFullName = ''; PackageName = ''
            }
            $protection = Get-MwpAppProtection -App $app
            $app.IsProtected = $protection.IsProtected
            $app.ProtectedReason = [string]$protection.Reason
            $app.Warning = [string]$protection.Warning
        }
    }
    [pscustomobject]@{ Success = $true; NotFound = $false; App = $app; Inventory = $inventory; WingetOk = $wingetOk; Message = $(if ($wingetOk) { '' } else { $list.Message }); Result = $null }
}
