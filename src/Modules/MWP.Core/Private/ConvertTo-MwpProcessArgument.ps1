function ConvertTo-MwpProcessArgument {
    <#
    .SYNOPSIS
        Zamienia argument na postać bezpieczną dla wiersza poleceń Windows (cudzysłowy i ukośniki).

    .DESCRIPTION
        Start-Process łączy argumenty spacjami, więc ścieżki ze spacjami i cudzysłowami trzeba
        zacytować według zasad CommandLineToArgvW. Nie składamy poleceń z tekstu wejściowego (D-015).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    if ($Value -eq '') {
        return '""'
    }
    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    '"' + $escaped + '"'
}
