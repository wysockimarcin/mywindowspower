function Get-MwpPowerQueryCommand {
    <#
    .SYNOPSIS
        Buduje polecenia odczytu stanu zasilania: lista planów i /qh każdego ustawienia z katalogu.

    .DESCRIPTION
        /qh (a nie /q) pokazuje także ustawienia ukryte — w Windows 11 akcje przycisków i pokrywy
        bywają ukryte i /q zwraca dla nich sam nagłówek planu (sprawdzone w FAZIE 6).

    .PARAMETER Plan
        GUID planu albo alias SCHEME_CURRENT (plan aktywny).

    .PARAMETER Setting
        Identyfikatory ustawień; domyślnie wszystkie z katalogu.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $Plan = 'SCHEME_CURRENT',

        [string[]] $Setting,

        [switch] $NoList
    )

    if (-not $NoList) {
        [pscustomobject]@{ Id = 'list'; Arguments = @('/list') }
    }
    foreach ($item in (Get-MwpPowerCatalog).Settings) {
        if ($PSBoundParameters.ContainsKey('Setting') -and $Setting -notcontains $item.Id) {
            continue
        }
        [pscustomobject]@{ Id = 'q:' + $item.Id; Arguments = @('/qh', $Plan, $item.SubGroup, $item.Setting) }
    }
}
