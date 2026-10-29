function Resolve-MwpInstalledApp {
    <#
    .SYNOPSIS
        Zamienia surowy wynik inwentarza (Get-MwpInstalledApp -AsOperation, blok Inventory) na obiekt MWP.AppInventory.

    .DESCRIPTION
        Czysta funkcja (poza odczytem listy ochronnej): przyjmuje tekst JSON, MWP.Result albo obiekt
        surowy; gotowy MWP.AppInventory jest zwracany bez zmian. Każda aplikacja (MWP.App) ma
        identyfikator (Registry:<zakres>:<architektura>:<SID>:<klucz> albo Appx:<pełna nazwa pakietu>),
        nazwę, wersję, wydawcę, datę instalacji, rozmiar, zakres (komputer / użytkownik), identyfikator
        lokalny winget (ARP\…, MSIX\…), oznaczenie składnika systemowego, ochronę z powodem
        (Get-MwpAppProtection), ostrzeżenie i sposób odinstalowania (Winget, Appx). Zwraca $null,
        gdy danych nie ma.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.AppInventory') {
        return $Data
    }
    $raw = ConvertFrom-MwpAppsJson -Data $Data -Kind 'MWP.AppInventoryRaw'
    if ($null -eq $raw) {
        return $null
    }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $apps = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($entry in @($raw.Registry | Where-Object { $null -ne $_ })) {
        $installDate = $null
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParseExact([string]$entry.InstallDate, 'yyyyMMdd', $culture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            $installDate = $parsed
        }
        $isUpdate = [bool]$entry.ParentKeyName -or @('Update', 'Hotfix', 'Security Update', 'Update Rollup', 'ServicePack') -contains [string]$entry.ReleaseType
        $scope = [string]$entry.Scope
        $userName = [string]$entry.UserName
        $app = [pscustomobject]@{
            PSTypeName        = 'MWP.App'
            Id                = 'Registry:{0}:{1}:{2}:{3}' -f $scope, $entry.Architecture, $entry.UserSid, $entry.KeyName
            Source            = 'Registry'
            SourceText        = 'Rejestr'
            Name              = [string]$entry.DisplayName
            Version           = [string]$entry.DisplayVersion
            Publisher         = [string]$entry.Publisher
            InstallDate       = $installDate
            SizeBytes         = [long]$entry.EstimatedSizeKb * 1KB
            SizeText          = Format-MwpAppSize -Bytes ([long]$entry.EstimatedSizeKb * 1KB)
            Scope             = $scope
            ScopeText         = $(if ($scope -eq 'User') { 'Użytkownik: {0}' -f $userName } else { 'Komputer' })
            Architecture      = [string]$entry.Architecture
            UserSid           = [string]$entry.UserSid
            UserName          = $userName
            KeyName           = [string]$entry.KeyName
            InstallLocation   = [string]$entry.InstallLocation
            WindowsInstaller  = [bool]$entry.WindowsInstaller
            HasUninstall      = [bool]$entry.HasUninstall
            SystemComponent   = [bool]$entry.SystemComponent
            NoRemove          = [bool]$entry.NoRemove
            IsUpdate          = $isUpdate
            IsSystem          = [bool]$entry.SystemComponent -or $isUpdate
            PackageName       = ''
            PackageFullName   = ''
            PackageFamilyName = ''
            SignatureKind     = ''
            IsFramework       = $false
            IsResourcePackage = $false
            NonRemovable      = $false
            WingetLocalId     = 'ARP\{0}\{1}\{2}' -f $scope, $entry.Architecture, $entry.KeyName
            WingetId          = ''
            WingetName        = ''
            Available         = ''
            IsProtected       = $false
            ProtectedReason   = ''
            Warning           = ''
            UninstallMethod   = 'Winget'
        }
        $apps.Add($app)
    }
    foreach ($package in @($raw.Appx | Where-Object { $null -ne $_ })) {
        $publisher = [string]$package.Publisher
        if ($publisher -match '(?:^|,\s*)O=("?)([^,"]+)\1') {
            $publisher = $Matches[2]
        }
        elseif ($publisher -match '^CN=("?)([^,"]+)\1') {
            $publisher = $Matches[2]
        }
        $system = [string]$package.SignatureKind -eq 'System' -or [bool]$package.IsFramework -or [bool]$package.IsResourcePackage
        $app = [pscustomobject]@{
            PSTypeName        = 'MWP.App'
            Id                = 'Appx:{0}' -f $package.PackageFullName
            Source            = 'Appx'
            SourceText        = 'Appx'
            Name              = $(if ($package.DisplayName) { [string]$package.DisplayName } else { [string]$package.Name })
            Version           = [string]$package.Version
            Publisher         = $publisher
            InstallDate       = $null
            SizeBytes         = [long]0
            SizeText          = ''
            Scope             = 'User'
            ScopeText         = 'Użytkownik: {0}' -f $raw.CurrentUser
            Architecture      = [string]$package.Architecture
            UserSid           = [string]$raw.CurrentUserSid
            UserName          = [string]$raw.CurrentUser
            KeyName           = ''
            InstallLocation   = [string]$package.InstallLocation
            WindowsInstaller  = $false
            HasUninstall      = $true
            SystemComponent   = $false
            NoRemove          = $false
            IsUpdate          = $false
            IsSystem          = $system
            PackageName       = [string]$package.Name
            PackageFullName   = [string]$package.PackageFullName
            PackageFamilyName = [string]$package.PackageFamilyName
            SignatureKind     = [string]$package.SignatureKind
            IsFramework       = [bool]$package.IsFramework
            IsResourcePackage = [bool]$package.IsResourcePackage
            NonRemovable      = [bool]$package.NonRemovable
            WingetLocalId     = 'MSIX\{0}' -f $package.PackageFullName
            WingetId          = ''
            WingetName        = ''
            Available         = ''
            IsProtected       = $false
            ProtectedReason   = ''
            Warning           = ''
            UninstallMethod   = 'Appx'
        }
        $apps.Add($app)
    }
    $protected = @(Get-MwpProtectedItem | Where-Object { 'App', 'AppxPackage' -contains $_.Category })
    $runtime = @((Get-MwpAppsTargetConfig).RuntimePatterns)
    foreach ($app in $apps) {
        $protection = Get-MwpAppProtection -App $app -ProtectedItem $protected -RuntimePattern $runtime
        $app.IsProtected = $protection.IsProtected
        $app.ProtectedReason = [string]$protection.Reason
        $app.Warning = [string]$protection.Warning
    }
    [pscustomobject]@{
        PSTypeName      = 'MWP.AppInventory'
        ComputerName    = [string]$raw.ComputerName
        CollectedAt     = ConvertFrom-MwpAppsDate -Value $raw.CollectedAt
        IsAdministrator = [bool]$raw.IsAdministrator
        CurrentUser     = [string]$raw.CurrentUser
        CurrentUserSid  = [string]$raw.CurrentUserSid
        Apps            = $apps.ToArray()
        Profiles        = @($raw.Profiles | Where-Object { $null -ne $_ } | ForEach-Object {
                [pscustomobject]@{ Sid = [string]$_.Sid; Name = [string]$_.Name; IsCurrent = [bool]$_.IsCurrent }
            })
        Warnings        = @($raw.Warnings | Where-Object { $_ } | ForEach-Object { [string]$_ })
        Error           = $(if ($raw.Error) { [string]$raw.Error } else { $null })
    }
}
