function Format-MwpCleanupSize {
    <#
    .SYNOPSIS
        Zwraca rozmiar w bajtach jako tekst po polsku (B, KB, MB, GB, TB; jednostki 1024).

    .EXAMPLE
        Format-MwpCleanupSize -Bytes 1572864   # 1,5 MB
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object] $Bytes
    )

    $value = [double]0
    if ($null -ne $Bytes) {
        $value = [double]$Bytes
    }
    $culture = [Globalization.CultureInfo]::GetCultureInfo('pl-PL')
    $units = @('B', 'KB', 'MB', 'GB', 'TB')
    $index = 0
    while ([Math]::Abs($value) -ge 1024 -and $index -lt $units.Count - 1) {
        $value = $value / 1024
        $index++
    }
    if ($index -eq 0) {
        return '{0} B' -f [long]$value
    }
    '{0} {1}' -f $value.ToString($(if ($value -ge 100) { '0' } else { '0.#' }), $culture), $units[$index]
}
