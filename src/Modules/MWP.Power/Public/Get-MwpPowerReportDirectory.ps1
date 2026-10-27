function Get-MwpPowerReportDirectory {
    <#
    .SYNOPSIS
        Zwraca domyślny folder raportów zasilania: <katalog danych>\reports (D-032, D-044).

    .DESCRIPTION
        Operacja klasy Odczyt; folder nie jest tworzony (tworzy go Save-MwpPowerReport przy zapisie).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Join-Path -Path (Get-MwpDataLocation).Root -ChildPath 'reports'
}
