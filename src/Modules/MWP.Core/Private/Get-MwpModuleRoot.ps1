function Get-MwpModuleRoot {
    <#
    .SYNOPSIS
        Zwraca katalogi modułów: wbudowanych (src\Modules) i zainstalowanych z paczek (src\Modules\Installed).

    .DESCRIPTION
        Jedyne miejsce, które zna położenie modułów (D-031). Katalog Installed może jeszcze nie
        istnieć (powstaje przy pierwszej instalacji). Testy podmieniają tę funkcję mockiem
        (TestDrive), żeby nie instalować niczego w folderze aplikacji. Przeniesienie modułów
        z paczek do katalogu danych (D-032) — FAZA 4.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $builtIn = Join-Path -Path (Get-MwpProjectRoot) -ChildPath 'src\Modules'
    [pscustomobject]@{
        BuiltIn   = $builtIn
        Installed = Join-Path -Path $builtIn -ChildPath 'Installed'
    }
}
