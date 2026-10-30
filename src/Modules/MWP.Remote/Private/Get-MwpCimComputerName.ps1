function Get-MwpCimComputerName {
    <#
    .SYNOPSIS
        Odczytuje przez sesję CIM nazwę komputera, z którym sesja jest połączona (Win32_OperatingSystem.CSName).

    .DESCRIPTION
        D-054: weryfikacja nazwy dla odczytów CIM otwieranych bez wcześniejszego, zweryfikowanego
        Connect-MwpTarget. Testy podmieniają tę funkcję mockiem.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object] $CimSession,

        [Parameter(Mandatory)]
        [int] $TimeoutSeconds
    )

    [string](Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem -Property CSName -OperationTimeoutSec $TimeoutSeconds -ErrorAction Stop).CSName
}
