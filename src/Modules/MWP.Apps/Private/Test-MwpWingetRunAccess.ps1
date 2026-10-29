function Test-MwpWingetRunAccess {
    <#
    .SYNOPSIS
        Sprawdza przed podglądem zmiany, czy winget da się uruchomić w wybranym kontekście (D-050, D-051).

    .DESCRIPTION
        Komputer zdalny: administrator w sesji (zadania harmonogramu). localhost z profilem innego
        użytkownika: aplikacja uruchomiona jako administrator (zadanie w jego sesji). Wynik: Success
        (można kontynuować), Message (odmowa po polsku), Result (MWP.Result błędu połączenia).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [AllowEmptyString()]
        [string] $UserSid = '',

        [Parameter(Mandatory)]
        [string] $What
    )

    $computerName = $Context.ComputerName
    if ($Context.Mode -eq 'Remote') {
        $admin = Test-MwpAppsAdmin -Context $Context
        if (-not $admin.Success) {
            return [pscustomobject]@{ Success = $false; Message = $admin.Result.Message; Result = $admin.Result }
        }
        if (-not $admin.IsAdministrator) {
            return [pscustomobject]@{ Success = $false; Message = ("{0} na komputerze zdalnym '{1}' wymaga konta administratora w połączeniu." -f $What, $computerName); Result = $null }
        }
    }
    elseif ($UserSid -and $UserSid -ne (Get-MwpAppsHostSid) -and -not (Test-MwpAdmin)) {
        return [pscustomobject]@{ Success = $false; Message = ("{0} w profilu innego użytkownika na komputerze '{1}' wymaga uruchomienia aplikacji jako administrator (zadanie w sesji tego użytkownika)." -f $What, $computerName); Result = $null }
    }
    [pscustomobject]@{ Success = $true; Message = ''; Result = $null }
}
