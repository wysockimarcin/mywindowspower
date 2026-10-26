function Get-MwpModuleRoot {
    <#
    .SYNOPSIS
        Zwraca katalogi modułów: wbudowanych (src\Modules), zainstalowanych z paczek (<katalog danych>\modules)
        i dawny katalog modułów z paczek (src\Modules\Installed).

    .DESCRIPTION
        Jedyne miejsce, które zna położenie modułów (D-031, D-038). Moduły z paczek leżą w katalogu
        danych (Get-MwpDataPath -Kind Modules), więc są przenoszone razem z danymi (Move-MwpDataDirectory)
        i trafiają do trybu zapasowego, gdy folder aplikacji jest niezapisywalny. Katalog Legacy
        (FAZA 3) jest nadal odkrywany, dopóki Move-MwpInstalledModule nie przeniesie z niego modułów.
        Katalogi Installed i Legacy mogą nie istnieć. Testy podmieniają tę funkcję mockiem (TestDrive).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $builtIn = Join-Path -Path (Get-MwpProjectRoot) -ChildPath 'src\Modules'
    [pscustomobject]@{
        BuiltIn   = $builtIn
        Installed = Get-MwpDataPath -Kind Modules
        Legacy    = Join-Path -Path $builtIn -ChildPath 'Installed'
    }
}
