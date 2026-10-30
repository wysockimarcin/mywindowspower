function Get-MwpTargetRow {
    <#
    .SYNOPSIS
        Buduje wiersze siatki „Komputery docelowe” w Ustawieniach (kolumny Nazwa i Adres IP, D-054).

    .DESCRIPTION
        Czysta funkcja (bez WPF). Wiersz to kopia komputera (MWP.Target — te same właściwości, więc
        przyciski Edytuj/Usuń/Diagnostyka działają na wierszu) z polami do wyświetlenia:
        - NameText: komputer zdalny — nazwa; localhost — nazwa hosta (Format-MwpTargetLabel),
        - AddressText i AddressToolTip: localhost — adres LAN z Get-MwpLocalNetworkAddress (tylko
          informacyjnie; „odczyt…”, gdy jeszcze nie ma wyniku), komputer zdalny — zapisany adres albo
          „— (po nazwie)”, a w podpowiedzi adresy wykryte w bieżącym połączeniu (-Detected),
        - NeedsName: nazwa w rejestrze jest adresem IPv4 (wpis sprzed D-054) — baner „ustaw nazwę”.

    .PARAMETER LocalAddress
        Wynik Get-MwpLocalNetworkAddress (MWP.NetworkAddress) albo $null (odczyt w toku).

    .PARAMETER Detected
        Słownik nazwa komputera → adresy wykryte po połączeniu (z otwartych instancji).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Target = @(),

        [AllowNull()]
        [object] $LocalAddress,

        [AllowNull()]
        [Collections.IDictionary] $Detected
    )

    foreach ($item in @($Target | Where-Object { $null -ne $_ })) {
        $row = [ordered]@{}
        foreach ($property in $item.PSObject.Properties) {
            $row[$property.Name] = $property.Value
        }
        $isLocal = [bool]$item.IsLocal
        $name = [string]$item.Name
        $row['NameText'] = Format-MwpTargetLabel -ComputerName $(if ($isLocal) { 'localhost' } else { $name })
        if ($isLocal) {
            if ($null -eq $LocalAddress) {
                $row['AddressText'] = 'odczyt…'
                $row['AddressToolTip'] = 'Adres w sieci LAN jest odczytywany w tle (tylko informacyjnie).'
            }
            else {
                $row['AddressText'] = [string]$LocalAddress.Text
                $tip = 'Adres tego komputera w sieci LAN — tylko informacyjnie; aplikacja łączy się z localhost lokalnie, bez sieci.'
                if (-not [string]::IsNullOrEmpty([string]$LocalAddress.ToolTip)) {
                    $tip = '{0}{1}{2}' -f $tip, [Environment]::NewLine, $LocalAddress.ToolTip
                }
                $row['AddressToolTip'] = $tip
            }
            $row['NeedsName'] = $false
        }
        else {
            $address = if ($null -ne $item.PSObject.Properties['Address']) { [string]$item.Address } else { '' }
            $connectionAddress = if ($null -ne $item.PSObject.Properties['ConnectionAddress']) { [string]$item.ConnectionAddress } else { $name }
            $row['AddressText'] = $(if ($address -ne '') { $address } else { '— (po nazwie)' })
            $lines = New-Object -TypeName System.Collections.Generic.List[string]
            $lines.Add(('Połączenie WinRM idzie pod: {0}' -f $connectionAddress))
            if ($address -ne '' -and $connectionAddress -ne $address) {
                $lines.Add('HTTPS: połączenie po nazwie (certyfikat), zapisany adres jest pomijany.')
            }
            $found = $null
            if ($null -ne $Detected -and $Detected.Contains($name)) {
                $found = @($Detected[$name] | Where-Object { $_ })
            }
            if ($null -ne $found -and $found.Count -gt 0) {
                $lines.Add(('Adresy wykryte w bieżącym połączeniu: {0}' -f ($found -join ', ')))
            }
            $row['AddressToolTip'] = $lines -join [Environment]::NewLine
            $row['NeedsName'] = $name -match '^\d{1,3}(\.\d{1,3}){3}$'
        }
        [pscustomobject]$row
    }
}
