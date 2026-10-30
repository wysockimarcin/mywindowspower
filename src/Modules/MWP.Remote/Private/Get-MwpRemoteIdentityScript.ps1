function Get-MwpRemoteIdentityScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu odczytujący tożsamość komputera zdalnego: nazwę NetBIOS, nazwę hosta i dane kart sieciowych.

    .DESCRIPTION
        D-054: wynik (słownik z kluczem MwpIdentity) służy do weryfikacji nazwy po połączeniu
        (NameMismatch) i do pokazania adresów wykrytych. Blok jest samowystarczalny i zgodny z 5.1;
        jako argument dostaje tekst bloku Get-MwpNetworkDataScript (ta sama logika odczytu co lokalnie).
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    {
        param([string] $NetworkScript)
        $identity = @{ MwpIdentity = $true; ComputerName = $env:COMPUTERNAME; HostName = $null; Network = $null }
        try {
            $identity.HostName = [System.Net.Dns]::GetHostName()
        }
        catch {
            $identity.HostName = $null
        }
        if (-not [string]::IsNullOrEmpty($NetworkScript)) {
            try {
                $identity.Network = & ([scriptblock]::Create($NetworkScript))
            }
            catch {
                $identity.Network = @{ Interfaces = @(); PreferredAddress = $null; Error = $_.Exception.Message }
            }
        }
        $identity
    }
}
