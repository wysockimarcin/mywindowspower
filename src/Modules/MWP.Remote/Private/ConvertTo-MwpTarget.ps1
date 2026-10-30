function ConvertTo-MwpTarget {
    <#
    .SYNOPSIS
        Buduje obiekt komputera docelowego (MWP.Target) z wpisu rejestru albo dla komputera lokalnego.

    .DESCRIPTION
        Wpis rejestru (klucz targets w settings.local.json): name, address, displayName, transport
        (WinRM), port, useSsl, authentication (Credential | CurrentUser), userName. Hasła nigdy nie są
        zapisywane (D-034); userName to tylko podpowiedź dla okna poświadczeń.
        D-054: Name to faktyczna nazwa komputera i jego identyfikator w aplikacji (rejestr, poświadczenia,
        log, widgety, cofnięcia); Address — opcjonalny adres połączenia (IPv4 albo nazwa DNS).
        ConnectionAddress to adres, pod który idą połączenia WinRM/CIM: Address, a gdy pusty — Name.
        Przy HTTPS (useSsl) zawsze Name, bo certyfikat jest wystawiony na nazwę, a sprawdzania
        certyfikatu aplikacja nie wyłącza. Dla localhost adres połączenia nie jest używany.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Entry')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Entry')]
        [Collections.IDictionary] $Entry,

        [Parameter(Mandatory, ParameterSetName = 'Local')]
        [switch] $Local
    )

    if ($Local) {
        return [pscustomobject]@{
            PSTypeName     = 'MWP.Target'
            Name           = 'localhost'
            Address        = ''
            ConnectionAddress = 'localhost'
            DisplayName    = 'Ten komputer (localhost)'
            IsLocal        = $true
            Transport      = 'Local'
            Port           = 0
            UseSsl         = $false
            Authentication = 'CurrentUser'
            UserName       = [Environment]::UserName
        }
    }

    $get = {
        param($Key, $Default)
        if ($Entry.Contains($Key) -and $null -ne $Entry[$Key] -and "$($Entry[$Key])" -ne '') { $Entry[$Key] } else { $Default }
    }
    $useSsl = [bool](& $get 'useSsl' $false)
    $defaultPort = if ($useSsl) { 5986 } else { 5985 }
    $name = [string]$Entry['name']
    $address = [string](& $get 'address' '')
    $connectionAddress = if ($address -eq '' -or $useSsl) { $name } else { $address }
    [pscustomobject]@{
        PSTypeName     = 'MWP.Target'
        Name           = $name
        Address        = $address
        ConnectionAddress = $connectionAddress
        DisplayName    = [string](& $get 'displayName' $name)
        IsLocal        = $false
        Transport      = [string](& $get 'transport' 'WinRM')
        Port           = [int](& $get 'port' $defaultPort)
        UseSsl         = $useSsl
        Authentication = [string](& $get 'authentication' 'Credential')
        UserName       = [string](& $get 'userName' '')
    }
}
