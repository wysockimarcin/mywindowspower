function Test-MwpServiceAdmin {
    <#
    .SYNOPSIS
        Sprawdza uprawnienia administratora na komputerze docelowym kontekstu (jak New-MwpRestorePoint).

    .DESCRIPTION
        Lokalnie: Test-MwpAdmin (token procesu hosta). Zdalnie: krótki blok w sesji kontekstu.
        Wynik: Success (sprawdzenie się udało), IsAdministrator, Result (MWP.Result błędu połączenia).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context
    )

    if ($Context.Mode -eq 'Local') {
        return [pscustomobject]@{ Success = $true; IsAdministrator = [bool](Test-MwpAdmin); Result = $null }
    }
    $check = Invoke-MwpOnTarget -Context $Context -Operation 'Services.CheckAdmin' -ScriptBlock {
        $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
        $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    if (-not $check.Success) {
        return [pscustomobject]@{ Success = $false; IsAdministrator = $false; Result = $check }
    }
    [pscustomobject]@{ Success = $true; IsAdministrator = (@($check.Data) -contains $true); Result = $check }
}
