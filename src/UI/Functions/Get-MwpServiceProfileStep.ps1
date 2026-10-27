function Get-MwpServiceProfileStep {
    <#
    .SYNOPSIS
        Zamienia wiersze różnic profilu usług (Compare-MwpServiceProfile) na kroki zmian dla Invoke-MwpUiInstanceChange.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Krok powstaje tylko dla wiersza Action = Change:
        Set-MwpServiceStartupType z nazwą usługi i typem z profilu — każdy krok ma własny podgląd
        (-WhatIf), log i wpis cofnięcia. Wiersze chronione, brakujące i bez zmian są pomijane.

    .PARAMETER Row
        Wiersze MWP.ServiceProfileDiff (wszystkie albo zaznaczone w widoku).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $Row
    )

    foreach ($item in @($Row | Where-Object { $null -ne $_ -and $_.Action -eq 'Change' })) {
        @{
            Command    = 'Set-MwpServiceStartupType'
            Parameters = @{ Name = [string]$item.Name; StartupType = [string]$item.Wanted }
            Label      = '{0}: {1} → {2}' -f $item.DisplayName, $item.CurrentText, $item.WantedText
        }
    }
}
