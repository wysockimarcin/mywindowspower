function Join-MwpAppWinget {
    <#
    .SYNOPSIS
        Łączy aplikacje z inwentarza (MWP.App) z pakietami winget (MWP.WingetPackage z listy): identyfikator źródła i dostępna aktualizacja.

    .DESCRIPTION
        Czysta funkcja (poza ponowną oceną ochrony). winget list pokazuje nazwę i wersję zainstalowaną
        tak, jak w rejestrze (DisplayName, DisplayVersion) albo nazwę pakietu Appx — dopasowanie po
        nazwie bez rozróżniania wielkości liter, przy kilku kandydatach po wersji. Uzupełnia WingetId,
        WingetName, Available i ochronę (lista ochronna może dotyczyć identyfikatora winget). Zwraca
        aplikacje (te same obiekty).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $App,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $Package
    )

    $byName = @{}
    foreach ($package in @($Package | Where-Object { $null -ne $_ -and -not $_.IsLocalId })) {
        $key = ([string]$package.Name).Trim().ToLowerInvariant()
        if (-not $byName.ContainsKey($key)) {
            $byName[$key] = New-Object -TypeName System.Collections.Generic.List[object]
        }
        $byName[$key].Add($package)
    }
    $protected = @(Get-MwpProtectedItem | Where-Object { 'App', 'AppxPackage' -contains $_.Category })
    $runtime = @((Get-MwpAppsTargetConfig).RuntimePatterns)
    foreach ($item in @($App | Where-Object { $null -ne $_ })) {
        $key = ([string]$item.Name).Trim().ToLowerInvariant()
        $match = $null
        if ($byName.ContainsKey($key)) {
            $candidates = $byName[$key].ToArray()
            $match = @($candidates | Where-Object { [string]$_.Version -eq [string]$item.Version }) | Select-Object -First 1
            if ($null -eq $match -and $candidates.Count -eq 1) {
                $match = $candidates[0]
            }
        }
        if ($null -ne $match) {
            $item.WingetId = [string]$match.Id
            $item.WingetName = [string]$match.Name
            $item.Available = [string]$match.Available
            $protection = Get-MwpAppProtection -App $item -ProtectedItem $protected -RuntimePattern $runtime
            $item.IsProtected = $protection.IsProtected
            $item.ProtectedReason = [string]$protection.Reason
            $item.Warning = [string]$protection.Warning
        }
        $item
    }
}
