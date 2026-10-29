function Get-MwpAppTarget {
    <#
    .SYNOPSIS
        Znajduje aplikację do odinstalowania na komputerze docelowym: inwentarz (rejestr, Appx) połączony z listą winget.

    .DESCRIPTION
        -AppId: identyfikator z Resolve-MwpInstalledApp (Registry:…, Appx:…); dla programu profilu
        użytkownika odczytywany jest ten profil (SID z identyfikatora). -WingetId: identyfikator
        źródła albo lokalny (ARP\…, MSIX\…) — aplikacja z inwentarza o tym identyfikatorze, a bez niej
        pakiet z winget list (nazwa i wersja z winget). Lista winget jest czytana zawsze, gdy winget
        działa (identyfikator źródła = możliwość cofnięcia), a dla profilu użytkownika także w jego
        sesji (D-051). Wynik: Success, App, Inventory, WingetOk (uruchomienie podstawowe), UserRun
        (przebieg w profilu użytkownika albo $null), Message, NotFound (aplikacji nie ma na komputerze),
        Result (MWP.Result błędu połączenia).

    .PARAMETER UserSid
        Profil użytkownika, którego programy i pakiety dołączyć (z -WingetId; przy -AppId — SID z identyfikatora).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [string] $AppId = '',

        [string] $WingetId = '',

        [AllowEmptyString()]
        [string] $UserSid = ''
    )

    $fail = { param($Message, $Result, $NotFound) [pscustomobject]@{ Success = $false; NotFound = [bool]$NotFound; App = $null; Inventory = $null; WingetOk = $false; UserRun = $null; Message = $Message; Result = $Result } }
    $sids = @()
    if ($AppId -match '^Registry:User:[^:]*:(S-1-5-21-[0-9-]+):') {
        $sids = @($Matches[1])
    }
    elseif ($UserSid) {
        $sids = @($UserSid)
    }
    $read = Get-MwpInstalledApp -Context $Context -UserSid $sids
    if (-not $read.Success) {
        return & $fail $read.Message $read $false
    }
    $inventory = $read.Data
    $list = Get-MwpWingetPackage -Context $Context -UserSid $sids
    $wingetOk = $list.Success
    $packages = if ($null -ne $list.Data) { @($list.Data.Packages) } else { @() }
    $userRun = if ($null -ne $list.Data) { @($list.Data.Runs | Where-Object { $_.RunAs -eq 'User' }) | Select-Object -First 1 } else { $null }
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
                $userFailed = $null -ne $userRun -and -not $userRun.Success
                $message = if ($userFailed) { $userRun.Message } elseif ($wingetOk) { "Na komputerze '{0}' nie ma zainstalowanego pakietu '{1}'." -f $Context.ComputerName, $WingetId } else { $list.Message }
                return & $fail $message $null ($wingetOk -and -not $userFailed)
            }
            $packageUser = $package.RunAs -eq 'User'
            $app = [pscustomobject]@{
                PSTypeName = 'MWP.App'; Id = 'Winget:' + $package.Id; Source = 'Winget'; SourceText = 'winget'; Name = $package.Name; Version = $package.Version
                Publisher = ''; Scope = $(if ($packageUser) { 'User' } else { '' }); ScopeText = ''; UserSid = $(if ($packageUser) { [string]$package.UserSid } else { '' })
                UserName = $(if ($packageUser) { [string]$package.UserName } else { '' }); WingetLocalId = ''; WingetId = $package.Id; WingetName = $package.Name
                Available = $package.Available; IsProtected = $false; ProtectedReason = ''; Warning = ''; UninstallMethod = 'Winget'
                PackageFullName = ''; PackageName = ''
            }
            $protection = Get-MwpAppProtection -App $app
            $app.IsProtected = $protection.IsProtected
            $app.ProtectedReason = [string]$protection.Reason
            $app.Warning = [string]$protection.Warning
        }
    }
    [pscustomobject]@{ Success = $true; NotFound = $false; App = $app; Inventory = $inventory; WingetOk = $wingetOk; UserRun = $userRun; Message = $(if ($wingetOk) { '' } else { $list.Message }); Result = $null }
}
