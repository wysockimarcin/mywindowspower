function Open-MwpPowerReport {
    <#
    .SYNOPSIS
        Otwiera zapisany raport zasilania (plik .html) w domyślnej przeglądarce komputera lokalnego.

    .DESCRIPTION
        Dotyczy tylko komputera, na którym działa host (raport z komputera zdalnego jest już zapisany
        lokalnie przez Save-MwpPowerReport). Przyjmuje wyłącznie istniejący plik .html.
        Zwraca MWP.Result.

    .PARAMETER Path
        Ścieżka pliku raportu.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $common = @{ Operation = 'Power.OpenReport'; Target = $Path; ComputerName = 'localhost' }
    if ([IO.Path]::GetExtension($Path) -ne '.html' -or -not [IO.File]::Exists($Path)) {
        return New-MwpResult @common -Success $false -Message ("Nie ma raportu '{0}' (oczekiwany istniejący plik .html)." -f $Path)
    }
    try {
        Invoke-Item -LiteralPath $Path -ErrorAction Stop
        New-MwpResult @common -Success $true -Message ("Otwarto raport '{0}'." -f $Path)
    }
    catch {
        New-MwpResult @common -Success $false -Message ("Nie udało się otworzyć raportu '{0}': {1}" -f $Path, $_.Exception.Message) -ErrorMessage $_.Exception.Message
    }
}
