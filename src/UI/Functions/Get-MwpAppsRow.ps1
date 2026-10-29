function Get-MwpAppsRow {
    <#
    .SYNOPSIS
        Wiersze siatek widoku Aplikacje: zainstalowane (z filtrem), aktualizacje winget i wyniki wyszukiwania.

    .DESCRIPTION
        Czysta funkcja (bez WPF). -Inventory: aplikacje po filtrze Select-MwpInstalledApp (parametry
        z -Filter: Search, Source, Scope, IncludeSystemComponent, UpgradeOnly) z tekstami kolumn (data,
        rozmiar, ochrona). -Package: pakiety MWP.WingetList (aktualizacje albo wyszukiwanie);
        -Installed (MWP.WingetList listy) oznacza wyniki wyszukiwania już zainstalowane. Wiersz pakietu
        ma kontekst listy (D-051): RunAs, UserSid i tekst — SYSTEM, użytkownik albo pusty (konto aplikacji).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Inventory')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Inventory')]
        [AllowNull()]
        [object] $Inventory,

        [Parameter(ParameterSetName = 'Inventory')]
        [hashtable] $Filter = @{},

        [Parameter(Mandatory, ParameterSetName = 'Package')]
        [AllowNull()]
        [object] $Package,

        [Parameter(ParameterSetName = 'Package')]
        [AllowNull()]
        [object] $Installed
    )

    if ($PSCmdlet.ParameterSetName -eq 'Package') {
        if ($null -eq $Package) {
            return
        }
        $installedIds = @{}
        if ($null -ne $Installed) {
            foreach ($item in @($Installed.Packages)) {
                $installedIds[[string]$item.Id] = [string]$item.Version
            }
        }
        foreach ($item in @($Package.Packages | Where-Object { $null -ne $_ })) {
            [pscustomobject]@{
                PSTypeName    = 'MWP.UiAppsPackageRow'
                Id            = [string]$item.Id
                Name          = [string]$item.Name
                Version       = [string]$item.Version
                Available     = [string]$item.Available
                Match         = [string]$item.Match
                InstalledText = $(if ($installedIds.ContainsKey([string]$item.Id)) { 'Tak ({0})' -f $installedIds[[string]$item.Id] } else { '' })
                Note          = $(if ($item.Truncated) { 'Wartość ucięta przez winget' } elseif ($item.Table -gt 1) { 'Wymaga jawnego wskazania' } else { '' })
                RunAs         = $(if ($null -ne $item.PSObject.Properties['RunAs']) { [string]$item.RunAs } else { '' })
                UserSid       = $(if ($null -ne $item.PSObject.Properties['UserSid']) { [string]$item.UserSid } else { '' })
                ContextText   = $(if ($null -eq $item.PSObject.Properties['RunAs']) { '' } elseif ($item.RunAs -eq 'System') { 'SYSTEM' } elseif ($item.RunAs -eq 'User') { $(if ($item.UserName) { [string]$item.UserName } else { [string]$item.UserSid }) } else { '' })
            }
        }
        return
    }
    if ($null -eq $Inventory) {
        return
    }
    $select = @{}
    foreach ($key in 'Search', 'Source', 'Scope') {
        if ($Filter.ContainsKey($key) -and $null -ne $Filter[$key]) {
            $select[$key] = [string]$Filter[$key]
        }
    }
    foreach ($key in 'IncludeSystemComponent', 'UpgradeOnly') {
        if ($Filter.ContainsKey($key) -and $Filter[$key]) {
            $select[$key] = $true
        }
    }
    foreach ($app in @(Select-MwpInstalledApp -App @($Inventory.Apps) @select)) {
        [pscustomobject]@{
            PSTypeName      = 'MWP.UiAppsRow'
            Id              = [string]$app.Id
            Name            = [string]$app.Name
            Version         = [string]$app.Version
            Available       = [string]$app.Available
            Publisher       = [string]$app.Publisher
            SourceText      = $(if ($app.WingetId) { '{0} · winget' -f $app.SourceText } else { [string]$app.SourceText })
            ScopeText       = [string]$app.ScopeText
            InstallDateText = $(if ($null -ne $app.InstallDate) { ([datetime]$app.InstallDate).ToString('yyyy-MM-dd') } else { '' })
            SizeBytes       = [long]$app.SizeBytes
            SizeText        = [string]$app.SizeText
            ProtectionText  = $(if ($app.IsProtected) { 'Chroniona' } elseif ($app.Warning) { 'Uwaga' } else { '' })
        }
    }
}
