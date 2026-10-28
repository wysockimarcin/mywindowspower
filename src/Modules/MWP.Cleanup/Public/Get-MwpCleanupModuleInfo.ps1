function Get-MwpCleanupModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Cleanup.

    .DESCRIPTION
        Funkcja wejścia kontraktu modułu (EntryPoint, D-024). Nie zmienia systemu.

    .EXAMPLE
        Get-MwpCleanupModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name    = $module.Name
        Version = $module.Version
        Status  = 'Czyszczenie dysku: kategorie z pliku danych, skan (odczyt), usuwanie po potwierdzeniu z raportem, analiza magazynu składników DISM (FAZA 9)'
    }
}
