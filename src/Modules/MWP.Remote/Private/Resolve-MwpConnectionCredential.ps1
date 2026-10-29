function Resolve-MwpConnectionCredential {
    <#
    .SYNOPSIS
        Ustala poświadczenie, którym kontekst może się teraz uwierzytelnić (bez magazynu i bez okna).

    .DESCRIPTION
        Kolejność D-052 bez udziału użytkownika: (1) własne poświadczenie kontekstu (nie ze wspólnej
        pamięci), (2) poświadczenie komputera ze wspólnej pamięci podręcznej procesu w stanie Verified.
        Kontekst używający poświadczenia wspólnego uzgadnia je przy każdym wywołaniu: nowsze hasło jest
        przejmowane, a po unieważnieniu (Invalid) poświadczenie znika także z tego połączenia — żadna
        instancja ani widget nie próbuje ponownie starym hasłem. Magazyn (Menedżer poświadczeń) jest
        czytany tylko przy jawnym „Połącz” (Connect-MwpTarget -UseStoredCredential). Zwraca PSCredential
        albo $null; dla localhost i uwierzytelnienia CurrentUser zwraca poświadczenie połączenia (zwykle $null).
    #>
    [CmdletBinding()]
    [OutputType([pscredential])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context
    )

    $connection = $Context.Connection
    if ($Context.Mode -ne 'Remote' -or $Context.Identity.Authentication -ne 'Credential') {
        return $connection.Credential
    }
    $shared = $null -ne $connection.PSObject.Properties['CredentialShared'] -and [bool]$connection.CredentialShared
    if (-not $shared -and $null -ne $connection.Credential) {
        return $connection.Credential
    }
    $entry = Get-MwpCachedCredential -ComputerName $Context.ComputerName
    if ($null -ne $entry -and $entry['State'] -eq 'Verified' -and $null -ne $entry['Credential']) {
        Set-MwpConnectionCredential -Connection $connection -Credential $entry['Credential'] -Shared $true -Generation ([int]$entry['Generation'])
    }
    elseif ($shared) {
        Set-MwpConnectionCredential -Connection $connection -Credential $null
    }
    $connection.Credential
}
