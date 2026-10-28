function Get-MwpDnsPreset {
    <#
    .SYNOPSIS
        Zwraca presety serwerów DNS: automatycznie (DHCP), Cloudflare, Google i Quad9 (IPv4 i IPv6).

    .DESCRIPTION
        Dane stałe (D-049); używane przez Set-MwpDnsServer -Preset i widok sieci. Preset Dhcp ma pustą
        listę serwerów (powrót do adresów z DHCP). Adresy IPv6 są ustawiane tylko na adapterach
        z włączonym IPv6.

    .PARAMETER Name
        Zwraca tylko ten preset.

    .EXAMPLE
        Get-MwpDnsPreset | Format-Table Name, Label, ServersText
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateSet('Dhcp', 'Cloudflare', 'Google', 'Quad9')]
        [string] $Name
    )

    $presets = @(
        @{ Name = 'Dhcp'; Label = 'Automatycznie (DHCP)'; Servers = @() }
        @{ Name = 'Cloudflare'; Label = 'Cloudflare'; Servers = @('1.1.1.1', '1.0.0.1', '2606:4700:4700::1111', '2606:4700:4700::1001') }
        @{ Name = 'Google'; Label = 'Google Public DNS'; Servers = @('8.8.8.8', '8.8.4.4', '2001:4860:4860::8888', '2001:4860:4860::8844') }
        @{ Name = 'Quad9'; Label = 'Quad9'; Servers = @('9.9.9.9', '149.112.112.112', '2620:fe::fe', '2620:fe::9') }
    )
    foreach ($preset in $presets) {
        if (-not $PSBoundParameters.ContainsKey('Name') -or $preset.Name -eq $Name) {
            [pscustomobject]@{
                PSTypeName  = 'MWP.DnsPreset'
                Name        = $preset.Name
                Label       = $preset.Label
                Servers     = [string[]]$preset.Servers
                ServersText = Format-MwpDnsServerText -Server $preset.Servers
            }
        }
    }
}
