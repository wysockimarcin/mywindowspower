function Get-MwpNetworkViewOption {
    <#
    .SYNOPSIS
        Zwraca pozycje list widoku sieci: presety DNS (z Get-MwpDnsPreset i „Własne adresy”) i czas na zatwierdzenie zmiany.

    .DESCRIPTION
        Czysta funkcja (bez WPF). Czas na zatwierdzenie: 60, 120 (domyślnie, decyzja użytkownika
        2026-10-28) i 300 s (D-049).

    .PARAMETER Kind
        DnsPreset albo Rollback.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DnsPreset', 'Rollback')]
        [string] $Kind
    )

    if ($Kind -eq 'DnsPreset') {
        foreach ($preset in @(Get-MwpDnsPreset)) {
            $label = if ($preset.Name -eq 'Dhcp') { $preset.Label } else { '{0} ({1})' -f $preset.Label, (@($preset.Servers | Select-Object -First 2) -join ', ') }
            [pscustomobject]@{ Value = $preset.Name; Label = $label }
        }
        [pscustomobject]@{ Value = 'Custom'; Label = 'Własne adresy (pole obok)' }
        return
    }
    foreach ($seconds in 60, 120, 300) {
        [pscustomobject]@{ Value = $seconds; Label = $(if ($seconds -lt 120) { 'Zatwierdzenie w 60 s' } else { 'Zatwierdzenie w {0} min' -f ($seconds / 60) }) }
    }
}
