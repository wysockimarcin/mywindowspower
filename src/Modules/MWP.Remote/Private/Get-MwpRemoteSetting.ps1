function Get-MwpRemoteSetting {
    <#
    .SYNOPSIS
        Czyta liczbowe ustawienie połączeń zdalnych z konfiguracji, z wartością domyślną i zakresem.

    .DESCRIPTION
        Brak klucza (np. starszy szablon) albo wartość spoza zakresu nie przerywa pracy:
        zwracana jest wartość domyślna albo najbliższa granica zakresu.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [int] $Default,

        [int] $Minimum = 1,

        [int] $Maximum = [int]::MaxValue
    )

    $value = $Default
    try {
        $raw = Get-MwpSetting -Name $Name -WarningAction SilentlyContinue
        if ($null -ne $raw -and "$raw" -match '^\d+$') {
            $value = [int]$raw
        }
    }
    catch {
        Write-Verbose ("Brak ustawienia {0}; użyto wartości {1}." -f $Name, $Default)
    }
    [Math]::Max($Minimum, [Math]::Min($Maximum, $value))
}
