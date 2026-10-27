function Format-MwpByteSize {
    <#
    .SYNOPSIS
        Formatuje liczbę bajtów jako tekst (KB, MB, GB, TB; podstawa 1024, format polski).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Bytes
    )

    if ($null -eq $Bytes) {
        return 'brak danych'
    }
    $culture = [Globalization.CultureInfo]::GetCultureInfo('pl-PL')
    $value = [double]$Bytes
    $units = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    $index = 0
    while ($value -ge 1024 -and $index -lt $units.Count - 1) {
        $value = $value / 1024
        $index++
    }
    $format = if ($index -eq 0) { '{0:N0} {1}' } else { '{0:N1} {1}' }
    [string]::Format($culture, $format, $value, $units[$index])
}
