function Invoke-MwpLogRotation {
    <#
    .SYNOPSIS
        Usuwa dzienne pliki logu starsze niż liczba dni przechowywania.

    .DESCRIPTION
        Data pliku jest brana z nazwy (mwp-RRRR-MM-DD.log), nie z daty modyfikacji, więc wynik
        jest przewidywalny. Inne pliki w katalogu logów nie są ruszane.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Directory,

        [Parameter(Mandatory)]
        [ValidateRange(1, 3650)]
        [int] $RetentionDays,

        [datetime] $Today = (Get-Date)
    )

    if (-not (Test-Path -LiteralPath $Directory)) {
        return
    }

    $limit = $Today.Date.AddDays(-$RetentionDays)
    foreach ($file in Get-ChildItem -LiteralPath $Directory -Filter 'mwp-*.log' -File) {
        if ($file.BaseName -notmatch '^mwp-(\d{4}-\d{2}-\d{2})$') {
            continue
        }
        $date = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        if ($date -lt $limit) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}
