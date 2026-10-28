function Get-MwpNetworkRollbackScript {
    <#
    .SYNOPSIS
        Zwraca stały tekst bloku wycofania zmiany sieci, uruchamianego przez jednorazowe zadanie harmonogramu na komputerze docelowym.

    .DESCRIPTION
        Blok (D-049) działa jako SYSTEM w Windows PowerShell 5.1 (powershell.exe -EncodedCommand),
        niezależnie od aplikacji i połączenia: przywraca stan sprzed zmiany (DNS: reset do DHCP
        i statyczna lista sprzed zmiany; adapter: włączenie) i zawsze usuwa swoje zadanie. Stan
        (JSON w Base64) wstawia blok Change w miejsce znacznika __MWP_STATE__ — Base64 nie zawiera
        znaków, które zmieniłyby kod. Adapter jest sprawdzany po indeksie i identyfikatorze (GUID).
        Ten sam blok wykonuje się od razu, gdy zmiana się nie powiedzie.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    @'
$ErrorActionPreference = 'Stop'
$state = ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__MWP_STATE__')))
try {
    $index = [int]$state.InterfaceIndex
    $adapter = Get-NetAdapter -InterfaceIndex $index
    if (([string]$adapter.InterfaceGuid).Trim('{}') -ne ([string]$state.InterfaceGuid).Trim('{}')) {
        throw 'MyWindowsPower: adapter nie pasuje do zapisanego stanu - wycofanie pominięte.'
    }
    if ([string]$state.Kind -eq 'Dns') {
        Set-DnsClientServerAddress -InterfaceIndex $index -ResetServerAddresses
        $servers = @($state.ServerAddresses | Where-Object { $_ } | ForEach-Object { [string]$_ })
        if ($servers.Count -gt 0) {
            Set-DnsClientServerAddress -InterfaceIndex $index -ServerAddresses $servers
        }
        Clear-DnsClientCache -ErrorAction SilentlyContinue
    }
    elseif ([string]$state.Kind -eq 'Enable') {
        Enable-NetAdapter -InputObject $adapter -Confirm:$false
    }
}
finally {
    Unregister-ScheduledTask -TaskPath ([string]$state.TaskPath) -TaskName ([string]$state.TaskName) -Confirm:$false -ErrorAction SilentlyContinue
}
'@
}
