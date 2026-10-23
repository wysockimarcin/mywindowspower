function ConvertTo-MwpTarget {
    <#
    .SYNOPSIS
        Buduje obiekt komputera docelowego (MWP.Target) z wpisu rejestru albo dla komputera lokalnego.

    .DESCRIPTION
        Wpis rejestru (klucz targets w settings.local.json): name, displayName, transport (WinRM),
        port, useSsl, authentication (Credential | CurrentUser), userName. Hasła nigdy nie są
        zapisywane (D-034); userName to tylko podpowiedź dla okna poświadczeń.
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
    [pscustomobject]@{
        PSTypeName     = 'MWP.Target'
        Name           = $name
        DisplayName    = [string](& $get 'displayName' $name)
        IsLocal        = $false
        Transport      = [string](& $get 'transport' 'WinRM')
        Port           = [int](& $get 'port' $defaultPort)
        UseSsl         = $useSsl
        Authentication = [string](& $get 'authentication' 'Credential')
        UserName       = [string](& $get 'userName' '')
    }
}
