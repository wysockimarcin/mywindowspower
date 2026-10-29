function Test-MwpStoredCredential {
    <#
    .SYNOPSIS
        Adapter magazynu poświadczeń: sprawdza, czy komputer ma wpis MWP:<komputer>, bez odczytu hasła.

    .DESCRIPTION
        Zwraca metadane (Status, UserName, LastWritten, Message) jak Get-MwpStoredCredential -MetadataOnly;
        pole Credential jest zawsze puste. Używane przez wskaźnik „hasło zapisane / niezapisane”.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    Get-MwpStoredCredential -ComputerName $ComputerName -MetadataOnly
}
