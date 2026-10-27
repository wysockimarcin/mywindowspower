function Get-MwpServiceViewOption {
    <#
    .SYNOPSIS
        Zwraca pozycje list widoku Usługi: filtr stanu, filtr typu uruchomienia albo typy uruchomienia dozwolone dla usługi.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Pozycje { Value; Label } dla list rozwijanych.
        Dla -Service zwraca typy uruchomienia, które wolno jej ustawić: usłudze z listy ochronnej
        tylko typy automatyczne (AllowedWhenProtected, D-045); usłudze o nieznanym typie — żadnych.

    .PARAMETER Kind
        StatusFilter, StartupTypeFilter albo StartupType.

    .PARAMETER Service
        Usługa (MWP.Service) — dla Kind StartupType.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('StatusFilter', 'StartupTypeFilter', 'StartupType')]
        [string] $Kind,

        [AllowNull()]
        [object] $Service
    )

    $option = { param([string] $Value, [string] $Label) [pscustomobject]@{ Value = $Value; Label = $Label } }
    switch ($Kind) {
        'StatusFilter' {
            & $option 'All' 'Każdy stan'
            & $option 'Running' 'Działające'
            & $option 'Stopped' 'Zatrzymane'
            & $option 'Other' 'Inne stany'
        }
        'StartupTypeFilter' {
            & $option 'All' 'Każdy typ uruchomienia'
            & $option 'AnyAutomatic' 'Automatyczne (oba)'
            foreach ($type in @(Get-MwpServiceStartupTypeList)) {
                & $option $type.Id $type.Label
            }
        }
        'StartupType' {
            if ($null -eq $Service -or $Service.StartupType -eq 'Unknown') {
                return
            }
            foreach ($type in @(Get-MwpServiceStartupTypeList)) {
                if ($Service.IsProtected -and -not $type.AllowedWhenProtected -and $type.Id -ne $Service.StartupType) {
                    continue
                }
                & $option $type.Id $type.Label
            }
        }
    }
}
