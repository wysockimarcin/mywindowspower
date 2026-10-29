function Set-MwpConnectionCredential {
    <#
    .SYNOPSIS
        Ustawia poświadczenie obiektu połączenia (MWP.Connection) i jego pochodzenie.

    .DESCRIPTION
        CredentialShared = $true: poświadczenie pochodzi z pamięci podręcznej procesu (D-052) i przy
        każdym użyciu jest z nią uzgadniane (Resolve-MwpConnectionCredential), więc unieważnienie
        dotyczy od razu wszystkich kontekstów komputera. $false: poświadczenie własne kontekstu
        (np. New-MwpExecutionContext -Credential w CLI). CredentialGeneration = numer generacji
        z pamięci podręcznej albo -1. Obiekty połączeń bez tych pól (starsze) dostają je tutaj.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko obiekt w pamięci; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Connection,

        [AllowNull()]
        [pscredential] $Credential,

        [bool] $Shared = $false,

        [int] $Generation = -1
    )

    foreach ($name in 'CredentialShared', 'CredentialGeneration') {
        if ($null -eq $Connection.PSObject.Properties[$name]) {
            Add-Member -InputObject $Connection -MemberType NoteProperty -Name $name -Value $null
        }
    }
    $Connection.Credential = $Credential
    $Connection.CredentialShared = $Shared -and $null -ne $Credential
    $Connection.CredentialGeneration = $(if ($Shared -and $null -ne $Credential) { $Generation } else { -1 })
}
