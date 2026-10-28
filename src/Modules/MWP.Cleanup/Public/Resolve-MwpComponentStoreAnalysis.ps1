function Resolve-MwpComponentStoreAnalysis {
    <#
    .SYNOPSIS
        Zamienia surowy wynik analizy DISM (blok ComponentStore) na MWP.ComponentStoreAnalysis.

    .DESCRIPTION
        Czysta funkcja: przyjmuje tekst JSON, MWP.Result (także z operacji w tle) albo obiekt
        MWP.ComponentStoreRaw; gotowa analiza jest zwracana bez zmian. Parsuje angielski wynik DISM
        (/English): rozmiar zgłaszany przez Eksplorator, rzeczywisty rozmiar, część współdzieloną
        z Windows, kopie zapasowe i wyłączone funkcje, pamięć podręczną i dane tymczasowe, datę
        ostatniego czyszczenia, liczbę pakietów do odzyskania i zalecenie czyszczenia. Kod 740 albo
        brak administratora → Success = $false z wyjaśnieniem. Zwraca $null, gdy danych nie ma.

    .PARAMETER ComputerName
        Nazwa komputera do komunikatu (domyślnie z MWP.Result).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data,

        [AllowEmptyString()]
        [string] $ComputerName = ''
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.ComponentStoreAnalysis') {
        return $Data
    }
    if (-not $ComputerName -and $null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.Result') {
        $ComputerName = [string]$Data.ComputerName
    }
    if (-not $ComputerName) {
        $ComputerName = 'localhost'
    }
    $raw = ConvertFrom-MwpCleanupJson -Data $Data -Kind 'MWP.ComponentStoreRaw'
    if ($null -eq $raw) {
        return $null
    }
    $lines = @(@($raw.Lines) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
    $values = @{}
    foreach ($line in $lines) {
        if ($line -match '^\s*([A-Za-z][A-Za-z ()]+?)\s*:\s*(.*?)\s*$') {
            $values[$Matches[1].Trim()] = $Matches[2]
        }
    }
    $size = {
        param([string] $Key)
        $text = if ($values.ContainsKey($Key)) { [string]$values[$Key] } else { '' }
        $bytes = $null
        if ($text -match '^([0-9]+(?:[.,][0-9]+)?)\s*(bytes|KB|MB|GB|TB)$') {
            $number = [double]::Parse($Matches[1].Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture)
            $power = @{ bytes = 0; KB = 1; MB = 2; GB = 3; TB = 4 }[$Matches[2]]
            $bytes = [long]($number * [Math]::Pow(1024, $power))
        }
        [pscustomobject]@{ Text = $(if ($null -ne $bytes) { Format-MwpCleanupSize -Bytes $bytes } else { $text }); Bytes = $bytes }
    }
    $explorer = & $size 'Windows Explorer Reported Size of Component Store'
    $actual = & $size 'Actual Size of Component Store'
    $shared = & $size 'Shared with Windows'
    $backups = & $size 'Backups and Disabled Features'
    $cache = & $size 'Cache and Temporary Data'
    $lastCleanup = $null
    $lastCleanupText = if ($values.ContainsKey('Date of Last Cleanup')) { [string]$values['Date of Last Cleanup'] } else { '' }
    $parsed = [datetime]::MinValue
    if ($lastCleanupText -and [datetime]::TryParse($lastCleanupText, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        $lastCleanup = $parsed
    }
    $reclaimable = $null
    if ($values.ContainsKey('Number of Reclaimable Packages') -and [string]$values['Number of Reclaimable Packages'] -match '^\d+$') {
        $reclaimable = [int]$values['Number of Reclaimable Packages']
    }
    $recommended = $null
    if ($values.ContainsKey('Component Store Cleanup Recommended')) {
        $recommended = [string]$values['Component Store Cleanup Recommended'] -match '^(Yes|Tak)$'
    }

    $exitCode = if ($null -ne $raw.ExitCode) { [int]$raw.ExitCode } else { $null }
    $errorText = ''
    if (-not $raw.IsAdministrator -or $exitCode -eq 740) {
        $success = $false
        $errorText = 'wymagane uprawnienia administratora'
        $message = "Analiza magazynu składników na komputerze '{0}' wymaga uprawnień administratora (uruchom aplikację jako administrator albo połącz się kontem administratora)." -f $ComputerName
    }
    elseif ($raw.Error -or $exitCode -ne 0 -or $null -eq $actual.Bytes) {
        $success = $false
        $errorLines = @($lines | Where-Object { $_ -match 'Error|error' }) -join ' '
        $errorText = @($raw.Error, $errorLines, $(if ($null -ne $exitCode) { 'kod wyjścia {0}' -f $exitCode } else { '' })) -join ' ' -replace '\s+', ' '
        $message = "Analiza magazynu składników na komputerze '{0}' nie powiodła się: {1}" -f $ComputerName, $errorText.Trim()
    }
    else {
        $success = $true
        $message = "Magazyn składników na komputerze '{0}': rzeczywisty rozmiar {1}, kopie zapasowe i wyłączone funkcje {2}, pamięć podręczna {3}; czyszczenie {4}." -f $ComputerName,
        $actual.Text, $backups.Text, $cache.Text, $(if ($recommended) { 'zalecane' } else { 'niezalecane' })
    }

    [pscustomobject]@{
        PSTypeName          = 'MWP.ComponentStoreAnalysis'
        ComputerName        = $ComputerName
        Success             = $success
        Message             = $message
        ErrorText           = $errorText.Trim()
        IsAdministrator     = [bool]$raw.IsAdministrator
        ExitCode            = $exitCode
        ExplorerSizeBytes   = $explorer.Bytes
        ExplorerSizeText    = $explorer.Text
        ActualSizeBytes     = $actual.Bytes
        ActualSizeText      = $actual.Text
        SharedBytes         = $shared.Bytes
        SharedText          = $shared.Text
        BackupsBytes        = $backups.Bytes
        BackupsText         = $backups.Text
        CacheBytes          = $cache.Bytes
        CacheText           = $cache.Text
        LastCleanup         = $lastCleanup
        LastCleanupText     = $lastCleanupText
        ReclaimablePackages = $reclaimable
        CleanupRecommended  = $recommended
        Lines               = $lines
        CollectedAt         = Get-Date
    }
}
