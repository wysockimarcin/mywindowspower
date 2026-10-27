function Test-MwpServiceName {
    <#
    .SYNOPSIS
        Sprawdza, czy tekst jest bezpieczną nazwą usługi do użycia w poleceniach (bez symboli wieloznacznych, cudzysłowów i ukośników).

    .DESCRIPTION
        Nazwy usług są walidowane przed wysłaniem na komputer docelowy (D-015, D-019): litery, cyfry,
        spacje (nie na początku i końcu) oraz znaki _ . - $ @ # + { } ( ) (np. 'Intel(R) TPM
        Provisioning Service'); długość do 256 znaków.
        Nie przepuszcza * ? [ ] (Get-Service traktuje je jak wzorce), " ' = / \ ani znaków sterujących.

    .OUTPUTS
        [bool]

    .EXAMPLE
        Test-MwpServiceName -Name 'MSSQL$SQLEXPRESS'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Name
    )

    if ([string]::IsNullOrEmpty($Name) -or $Name.Length -gt 256) {
        return $false
    }
    $Name -match '^[\w.$@#+{}()-](?:[\w .$@#+{}()-]*[\w.$@#+{}()-])?$'
}
