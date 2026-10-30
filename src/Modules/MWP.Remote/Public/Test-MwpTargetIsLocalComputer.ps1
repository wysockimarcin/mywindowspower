function Test-MwpTargetIsLocalComputer {
    <#
    .SYNOPSIS
        Sprawdza, czy nazwa lub adres komputera zdalnego wskazuje na ten komputer (ostrzeżenie „użyj localhost”).

    .DESCRIPTION
        D-054: wywoływana przy dodawaniu i edycji komputera. Porównuje nazwę z nazwą tego komputera
        (pierwszy człon, bez wielkości liter), a nazwę i adres — z adresami LAN tego komputera
        (Get-MwpLocalNetworkAddress) i adresami pętli zwrotnej. Wynik jest tylko ostrzeżeniem
        (IsLocalComputer, Message); niczego nie blokuje i nie zmienia trybu łączenia: komputer
        zdalny pozostaje zdalny (Test-MwpLocalTargetName bez zmian).

    .EXAMPLE
        Test-MwpTargetIsLocalComputer -Name 'PC-BIURO' -Address '192.0.2.10'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [string] $Name = '',

        [AllowEmptyString()]
        [string] $Address = ''
    )

    $reasons = New-Object -TypeName System.Collections.Generic.List[string]
    $hostName = ''
    try {
        $hostName = [Net.Dns]::GetHostName()
    }
    catch {
        $hostName = ''
    }
    if ($Name -ne '' -and (Test-MwpRemoteNameMatch -Name $Name -RemoteNames @($env:COMPUTERNAME, $hostName)) -eq $true) {
        $reasons.Add(("nazwa '{0}' to nazwa tego komputera" -f $Name))
    }
    $values = @(@($Name, $Address) | Where-Object { $_ -ne '' } | Select-Object -Unique)
    $loopback = @($values | Where-Object { $_ -in @('localhost', '::1') -or $_ -like '127.*' })
    foreach ($value in $loopback) {
        $reasons.Add(("'{0}' to adres pętli zwrotnej tego komputera" -f $value))
    }
    $addresses = @($values | Where-Object { (Test-MwpIPv4Address -Value $_) -and $loopback -notcontains $_ })
    if ($addresses.Count -gt 0) {
        $local = Get-MwpLocalNetworkAddress
        foreach ($value in $addresses) {
            if (@($local.AllAddresses) -contains $value) {
                $reasons.Add(("adres '{0}' należy do tego komputera" -f $value))
            }
        }
    }

    $message = ''
    if ($reasons.Count -gt 0) {
        $message = 'To ten komputer ({0}): użyj localhost — działa lokalnie, bez WinRM i bez hasła.' -f ($reasons -join '; ')
    }
    [pscustomobject]@{
        PSTypeName      = 'MWP.LocalComputerCheck'
        IsLocalComputer = $reasons.Count -gt 0
        Message         = $message
    }
}
