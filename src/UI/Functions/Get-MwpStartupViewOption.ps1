function Get-MwpStartupViewOption {
    <#
    .SYNOPSIS
        Zwraca pozycje list wyboru widoku Autostart i harmonogram (filtry): Value i Label po polsku.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Wartości odpowiadają parametrom
        Select-MwpStartupItem i Select-MwpScheduledTask (MWP.Startup).

    .PARAMETER Kind
        ItemScope, ItemState, ItemRisk albo TaskState.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ItemScope', 'ItemState', 'ItemRisk', 'TaskState')]
        [string] $Kind
    )

    $option = { param([string] $Value, [string] $Label) [pscustomobject]@{ Value = $Value; Label = $Label } }
    switch ($Kind) {
        'ItemScope' {
            & $option 'All' 'Komputer i użytkownicy'
            & $option 'Machine' 'Wszyscy użytkownicy (komputer)'
            & $option 'User' 'Profile użytkowników'
        }
        'ItemState' {
            & $option 'All' 'Każdy stan'
            & $option 'Enabled' 'Włączone'
            & $option 'Disabled' 'Wyłączone'
            & $option 'RunOnce' 'Jednorazowe (RunOnce)'
        }
        'ItemRisk' {
            & $option 'All' 'Każdy podpis'
            & $option 'NotSigned' 'Bez ważnego podpisu'
        }
        'TaskState' {
            & $option 'All' 'Każdy stan'
            & $option 'Enabled' 'Włączone'
            & $option 'Disabled' 'Wyłączone'
            & $option 'Running' 'Uruchomione'
        }
    }
}
