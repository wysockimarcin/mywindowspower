function Resolve-MwpCleanupScan {
    <#
    .SYNOPSIS
        Zamienia wynik skanu w tle (blok Estimate, Measure-MwpCleanupCategory -AsOperation) na MWP.CleanupScan.

    .DESCRIPTION
        Czysta funkcja (bez wywołań systemowych): ten sam kształt co Measure-MwpCleanupCategory bez
        -AsOperation (New-MwpCleanupCategoryResult dla każdej kategorii, New-MwpCleanupScan) i te same
        ostrzeżenia (brak administratora, komputer zdalny bez profili użytkowników, niepełne dane
        o lokalizacjach). Przyjmuje MWP.Result, tekst JSON albo gotowy MWP.CleanupScan. Zwraca $null,
        gdy danych nie ma albo komputer nie zwrócił lokalizacji systemu.

    .EXAMPLE
        $operation = Measure-MwpCleanupCategory -AsOperation; Resolve-MwpCleanupScan -Data (Wait-MwpOperation $operation)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.CleanupScan') {
        return $Data
    }
    $raw = ConvertFrom-MwpCleanupJson -Data $Data -Kind 'MWP.CleanupEstimateRaw'
    if ($null -eq $raw) {
        return $null
    }
    $environment = ConvertFrom-MwpCleanupJson -Data @([string]$raw.Environment) -Kind 'MWP.CleanupEnvironment'
    if ($null -eq $environment -or -not $environment.SystemRoot) {
        return $null
    }
    $process = $null
    if ($raw.Process) {
        $process = ConvertFrom-MwpCleanupJson -Data @([string]$raw.Process) -Kind 'MWP.CleanupProcess'
    }
    $isRemote = [bool]$raw.Remote
    $computerName = [string]$environment.ComputerName
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($warning in @($raw.Warnings | Where-Object { $_ })) {
        $warnings.Add([string]$warning)
    }
    $roots = @($raw.Roots | Where-Object { $null -ne $_ })
    if ($environment.Error) {
        $warnings.Add(('Część danych o profilach i dyskach jest niepełna: {0}' -f $environment.Error))
    }
    if (-not $environment.IsAdministrator) {
        $warnings.Add(("Brak uprawnień administratora na komputerze '{0}': lokalizacje systemowe i profile innych użytkowników są pominięte." -f $computerName))
    }
    if ($isRemote) {
        $warnings.Add('Komputer zdalny: skanowane są tylko lokalizacje systemowe; profile użytkowników — w widoku modułu po jawnym wyborze.')
    }
    if ($null -eq $process -and @($roots | Where-Object { $_.Available }).Count -gt 0) {
        $warnings.Add('Komputer nie zwrócił wyniku skanu.')
    }
    $rawRoots = $(if ($null -ne $process) { @($process.Roots) } else { @() })
    $results = @(foreach ($category in @($raw.Categories | Where-Object { $null -ne $_ })) {
            New-MwpCleanupCategoryResult -Category $category -Root @($roots | Where-Object { $_.CategoryId -eq $category.Id }) -RawRoot $rawRoots -Mode Scan
        })
    $users = @($roots | Where-Object { $_.Available -and $_.UserName } | ForEach-Object { [string]$_.UserName } | Select-Object -Unique)
    New-MwpCleanupScan -ComputerName $computerName -Category $results -IsAdministrator ([bool]$environment.IsAdministrator) -IsRemote $isRemote `
        -IncludeUserProfiles $false -UserProfile $users -Cancelled ($null -ne $process -and [bool]$process.Cancelled) -Warning $warnings.ToArray()
}
