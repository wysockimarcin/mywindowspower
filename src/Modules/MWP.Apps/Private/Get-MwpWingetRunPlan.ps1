function Get-MwpWingetRunPlan {
    <#
    .SYNOPSIS
        Ustala, w jakich kontekstach uruchomić winget na komputerze docelowym (D-051).

    .DESCRIPTION
        Czysta funkcja. Uruchomienie podstawowe: localhost — Direct (konto aplikacji, jak w D-050);
        komputer zdalny — System (zadanie harmonogramu jako SYSTEM; w sesji WinRM winget nie działa).
        Dla każdego profilu z -UserSid — User (zadanie w sesji zalogowanego użytkownika); lokalnie profil
        konta aplikacji = Direct. Z -UserOnly bez uruchomienia podstawowego (chyba że nie ma profili).
        Wynik: tablica { Mode; UserSid }.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [AllowEmptyCollection()]
        [string[]] $UserSid = @(),

        [switch] $UserOnly
    )

    $local = $Context.Mode -eq 'Local'
    $current = if ($local) { Get-MwpAppsHostSid } else { '' }
    $base = [pscustomobject]@{ Mode = $(if ($local) { 'Direct' } else { 'System' }); UserSid = '' }
    $runs = @()
    $sids = @($UserSid | Where-Object { $_ } | Select-Object -Unique)
    if (-not $UserOnly -or $sids.Count -eq 0) {
        $runs += $base
    }
    foreach ($sid in $sids) {
        if ($local -and $sid -eq $current) {
            if (@($runs | Where-Object { $_.Mode -eq 'Direct' }).Count -eq 0) {
                $runs += $base
            }
            continue
        }
        $runs += [pscustomobject]@{ Mode = 'User'; UserSid = [string]$sid }
    }
    $runs
}
