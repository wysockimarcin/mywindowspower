function Format-MwpUpdateSize {
    <#
    .SYNOPSIS
        Zwraca rozmiar w bajtach jako tekst po polsku (B, KB, MB, GB); 0 i brak — pusty tekst.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Bytes
    )

    if ($null -eq $Bytes) {
        return ''
    }
    $value = [double]$Bytes
    if ($value -le 0) {
        return ''
    }
    $culture = [Globalization.CultureInfo]::GetCultureInfo('pl-PL')
    foreach ($unit in @(@('GB', 1GB), @('MB', 1MB), @('KB', 1KB))) {
        if ($value -ge $unit[1]) {
            return ('{0} {1}' -f ($value / $unit[1]).ToString('0.#', $culture), $unit[0])
        }
    }
    '{0} B' -f [long]$value
}
