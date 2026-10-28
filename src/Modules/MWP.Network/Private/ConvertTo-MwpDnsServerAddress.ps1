function ConvertTo-MwpDnsServerAddress {
    <#
    .SYNOPSIS
        Sprawdza i normalizuje adresy serwerów DNS (IPv4 i IPv6); zwraca obiekt z listą albo błędem.

    .DESCRIPTION
        Adres musi dać się odczytać jako IP (IPv4 w pełnej postaci a.b.c.d); odrzucane są adresy nieokreślone (0.0.0.0, ::), rozgłoszeniowy
        255.255.255.255, grupowe (multicast) i duplikaty. Wynik: Addresses (tekst w postaci kanonicznej)
        i Error (opis albo $null).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [string[]] $Address = @()
    )

    $list = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($text in $Address) {
        $value = ([string]$text).Trim()
        if ($value -eq '') {
            continue
        }
        $parsed = $null
        # IPAddress.TryParse przyjmuje też skróty („1.1.1” = 1.1.0.1) — IPv4 tylko w pełnej postaci z czterema liczbami.
        $fullIPv4 = $value -match '^\d{1,3}(\.\d{1,3}){3}$'
        if (($value -notmatch ':' -and -not $fullIPv4) -or -not [Net.IPAddress]::TryParse($value, [ref]$parsed)) {
            return [pscustomobject]@{ Addresses = @(); Error = ("'{0}' nie jest adresem IP." -f $value) }
        }
        $bytes = $parsed.GetAddressBytes()
        $isUnspecified = $parsed.Equals([Net.IPAddress]::Any) -or $parsed.Equals([Net.IPAddress]::IPv6Any)
        $isMulticast = ($parsed.AddressFamily -eq 'InterNetwork' -and $bytes[0] -ge 224 -and $bytes[0] -le 239) -or $parsed.IsIPv6Multicast
        if ($isUnspecified -or $parsed.Equals([Net.IPAddress]::Broadcast) -or $isMulticast) {
            return [pscustomobject]@{ Addresses = @(); Error = ("Adres '{0}' nie może być serwerem DNS." -f $value) }
        }
        $canonical = $parsed.ToString()
        if (-not $list.Contains($canonical)) {
            $list.Add($canonical)
        }
    }
    [pscustomobject]@{ Addresses = $list.ToArray(); Error = $null }
}
