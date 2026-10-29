function Format-MwpAppSize {
    <#
    .SYNOPSIS
        Rozmiar w bajtach jako tekst po polsku (KB, MB, GB); 0 albo brak = pusty tekst.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Bytes
    )

    if ($null -eq $Bytes -or [double]$Bytes -le 0) {
        return ''
    }
    $value = [double]$Bytes
    $culture = [Globalization.CultureInfo]::GetCultureInfo('pl-PL')
    if ($value -ge 1GB) {
        return ('{0} GB' -f ($value / 1GB).ToString('0.0', $culture))
    }
    if ($value -ge 1MB) {
        return ('{0} MB' -f ($value / 1MB).ToString('0.0', $culture))
    }
    '{0} KB' -f [Math]::Max(1, [Math]::Round($value / 1KB)).ToString($culture)
}
