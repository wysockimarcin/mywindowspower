function Open-MwpUpdatePage {
    <#
    .SYNOPSIS
        Otwiera stronę Windows Update w Ustawieniach Windows (ms-settings:windowsupdate) na komputerze lokalnym.

    .DESCRIPTION
        Dla aktualizacji, których aplikacja nie instaluje (interakcja użytkownika, licencja) i dla
        komputera zdalnego (D-048). Nic nie zmienia. Kontekst zdalny daje wynik z błędem — Ustawień
        innego komputera nie da się otworzyć z tej aplikacji.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $common = @{ Operation = 'Update.OpenSettings'; Target = 'ms-settings:windowsupdate'; ComputerName = $Context.ComputerName }
    if ($Context.Mode -ne 'Local') {
        return New-MwpResult @common -Success $false -Message ("Ustawienia Windows Update komputera zdalnego '{0}' otwiera się na tamtym komputerze." -f $Context.ComputerName)
    }
    try {
        Start-Process -FilePath 'ms-settings:windowsupdate' -ErrorAction Stop
    }
    catch {
        return New-MwpResult @common -Success $false -Message ('Nie udało się otworzyć Ustawień Windows Update: {0}' -f $_.Exception.Message)
    }
    New-MwpResult @common -Success $true -Message 'Otwarto Ustawienia Windows Update.'
}
