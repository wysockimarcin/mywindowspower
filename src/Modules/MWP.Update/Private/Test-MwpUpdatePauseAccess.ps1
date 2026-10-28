function Test-MwpUpdatePauseAccess {
    <#
    .SYNOPSIS
        Sprawdza uprawnienia administratora do zmiany pauzy na komputerze docelowym; zwraca MWP.Result odmowy albo $null, gdy zmiana jest dozwolona.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [string] $Operation,

        [AllowEmptyString()]
        [string] $BeforeText = ''
    )

    $common = @{ Operation = $Operation; Target = 'Windows Update'; ComputerName = $Context.ComputerName }
    $admin = Test-MwpUpdateAdmin -Context $Context
    if (-not $admin.Success) {
        return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
    }
    if (-not $admin.IsAdministrator) {
        return New-MwpResult @common -Success $false -Before $BeforeText -Message ("Pauza aktualizacji wymaga uprawnień administratora na komputerze '{0}' (klucz HKLM)." -f $Context.ComputerName)
    }
    $null
}
