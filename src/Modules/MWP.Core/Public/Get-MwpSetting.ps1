function Get-MwpSetting {
    <#
    .SYNOPSIS
        Zwraca ustawienia aplikacji albo wartość jednego ustawienia.

    .DESCRIPTION
        Wartości domyślne pochodzą z config\settings.example.json (repozytorium), nadpisania
        z config\settings.local.json (poza repozytorium). Uszkodzony plik lokalny nie blokuje
        działania: zostaje zachowany pod inną nazwą, a funkcja zwraca wartości domyślne
        i wypisuje ostrzeżenie (D-015).

    .PARAMETER Name
        Nazwa ustawienia. Bez nazwy funkcja zwraca obiekt ze wszystkimi ustawieniami.

    .EXAMPLE
        Get-MwpSetting -Name logLevel
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $data = Read-MwpSettingsData
    foreach ($warning in $data.Warnings) {
        Write-Warning $warning
        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation 'Settings.Read' -Message $warning
    }

    if (-not $PSBoundParameters.ContainsKey('Name')) {
        return [pscustomobject]$data.Settings
    }
    if (-not $data.Settings.Contains($Name)) {
        throw ("Nieznane ustawienie '{0}'. Dostępne: {1}." -f $Name, (@($data.Settings.Keys) -join ', '))
    }
    $data.Settings[$Name]
}
