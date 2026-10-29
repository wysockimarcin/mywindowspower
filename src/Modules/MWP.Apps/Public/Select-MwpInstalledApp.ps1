function Select-MwpInstalledApp {
    <#
    .SYNOPSIS
        Filtruje i sortuje aplikacje (MWP.App) — wspólna logika widoku i CLI.

    .DESCRIPTION
        Czysta funkcja. Domyślnie ukrywa składniki systemowe (IsSystem: SystemComponent, aktualizacje,
        pakiety Appx systemowe, struktury i zasobów) — pokazuje je -IncludeSystemComponent. Wyszukiwanie
        bez rozróżniania wielkości liter w nazwie, wydawcy, wersji i identyfikatorach winget.

    .PARAMETER Source
        All, Registry albo Appx.

    .PARAMETER Scope
        All, Machine albo User.

    .PARAMETER SortBy
        Name, Publisher, Version, InstallDate, Size, Source.

    .EXAMPLE
        $apps | Select-MwpInstalledApp -Search 'microsoft' -SortBy Size -Descending
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $App,

        [AllowEmptyString()]
        [string] $Search = '',

        [ValidateSet('All', 'Registry', 'Appx')]
        [string] $Source = 'All',

        [ValidateSet('All', 'Machine', 'User')]
        [string] $Scope = 'All',

        [switch] $IncludeSystemComponent,

        [switch] $UpgradeOnly,

        [switch] $ProtectedOnly,

        [ValidateSet('Name', 'Publisher', 'Version', 'InstallDate', 'Size', 'Source')]
        [string] $SortBy = 'Name',

        [switch] $Descending
    )

    begin {
        $items = New-Object -TypeName System.Collections.Generic.List[object]
        $text = $Search.Trim()
    }
    process {
        foreach ($item in @($App)) {
            if ($null -eq $item) {
                continue
            }
            if (-not $IncludeSystemComponent -and $item.IsSystem) {
                continue
            }
            if ($Source -ne 'All' -and $item.Source -ne $Source) {
                continue
            }
            if ($Scope -ne 'All' -and $item.Scope -ne $Scope) {
                continue
            }
            if ($UpgradeOnly -and -not $item.Available) {
                continue
            }
            if ($ProtectedOnly -and -not $item.IsProtected) {
                continue
            }
            if ($text) {
                $haystack = '{0}|{1}|{2}|{3}|{4}|{5}' -f $item.Name, $item.Publisher, $item.Version, $item.WingetId, $item.WingetLocalId, $item.PackageName
                if ($haystack.IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                    continue
                }
            }
            $items.Add($item)
        }
    }
    end {
        $property = switch ($SortBy) {
            'Size' { 'SizeBytes' }
            'Version' { @{ Expression = { [string]$_.Version } } }
            default { $SortBy }
        }
        $secondary = @{ Expression = { [string]$_.Name } }
        $items.ToArray() | Sort-Object -Property $property, $secondary -Descending:$Descending
    }
}
