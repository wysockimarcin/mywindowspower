function Get-MwpPrzykladModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module przykładowym (funkcja wejścia z kontraktu).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    [pscustomobject]@{
        Name        = 'MWP.Przyklad'
        Description = 'Moduł przykładowy (paczka .mwpmod).'
    }
}
