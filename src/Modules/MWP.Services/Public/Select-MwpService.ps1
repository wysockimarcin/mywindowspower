function Select-MwpService {
    <#
    .SYNOPSIS
        Filtruje listę usług (MWP.Service) po stanie, typie uruchomienia, tekście i liście ochronnej.

    .DESCRIPTION
        Czysta funkcja bez wywołań systemowych — tych samych filtrów używa Get-MwpService (CLI)
        i widok Usługi (filtrowanie ostatniego odczytu bez ponownego odczytu z komputera).

    .PARAMETER Status
        All, Running (działające), Stopped (zatrzymane) albo Other (pozostałe stany przejściowe).

    .PARAMETER StartupType
        All, AnyAutomatic (oba typy automatyczne) albo konkretny typ uruchomienia.

    .PARAMETER Search
        Tekst szukany (bez rozróżniania wielkości liter) w nazwie, nazwie wyświetlanej i opisie.

    .PARAMETER ProtectedOnly
        Tylko usługi z listy ochronnej.

    .EXAMPLE
        (Get-MwpService).Data.Services | Select-MwpService -Status Stopped -StartupType AnyAutomatic
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $Service,

        [ValidateSet('All', 'Running', 'Stopped', 'Other')]
        [string] $Status = 'All',

        [ValidateSet('All', 'AnyAutomatic', 'Automatic', 'AutomaticDelayedStart', 'Manual', 'Disabled', 'Unknown')]
        [string] $StartupType = 'All',

        [AllowEmptyString()]
        [AllowNull()]
        [string] $Search,

        [switch] $ProtectedOnly
    )

    begin {
        $text = if ($null -ne $Search) { $Search.Trim() } else { '' }
    }

    process {
        foreach ($item in @($Service | Where-Object { $null -ne $_ })) {
            if ($Status -eq 'Running' -and $item.Status -ne 'Running') { continue }
            if ($Status -eq 'Stopped' -and $item.Status -ne 'Stopped') { continue }
            if ($Status -eq 'Other' -and $item.Status -in @('Running', 'Stopped')) { continue }
            if ($StartupType -eq 'AnyAutomatic') {
                if ($item.StartupType -notin @('Automatic', 'AutomaticDelayedStart')) { continue }
            }
            elseif ($StartupType -ne 'All' -and $item.StartupType -ne $StartupType) {
                continue
            }
            if ($ProtectedOnly -and -not $item.IsProtected) { continue }
            if ($text) {
                $found = $false
                foreach ($value in @($item.Name, $item.DisplayName, $item.Description)) {
                    if ($value -and ([string]$value).IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        $found = $true
                        break
                    }
                }
                if (-not $found) { continue }
            }
            $item
        }
    }
}
