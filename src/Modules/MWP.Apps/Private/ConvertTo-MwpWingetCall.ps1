function ConvertTo-MwpWingetCall {
    <#
    .SYNOPSIS
        Zamienia surowy wynik przebiegu winget (MWP.WingetRaw) na wynik wywołania z komunikatem po polsku.

    .DESCRIPTION
        Success = winget znaleziony, zakończony w limicie czasu i z kodem 0 (albo dozwolonym w
        -AllowedExitCode, np. „nie znaleziono pakietu” przy liście). Brak winget, przekroczony limit,
        błąd uruchomienia oraz powody z zadań harmonogramu (D-051: brak administratora, użytkownik
        niezalogowany, błąd zadania, przerwanie) mają osobne komunikaty. RunAs, UserSid i UserName
        mówią, w jakim kontekście działał winget (Direct, System, User).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [long[]] $AllowedExitCode = @(),

        [string] $ComputerName = 'localhost'
    )

    $raw = ConvertFrom-MwpAppsJson -Data $Data -Kind 'MWP.WingetRaw'
    $lines = if ($null -ne $raw) { @($raw.Lines | ForEach-Object { [string]$_ }) } else { @() }
    $exitCode = if ($null -ne $raw -and $null -ne $raw.ExitCode) { [long]$raw.ExitCode } else { $null }
    $field = { param([string] $Name) if ($null -ne $raw -and $null -ne $raw.PSObject.Properties[$Name]) { [string]$raw.$Name } else { '' } }
    $call = [ordered]@{
        Success = $false; Found = $false; ExitCode = $exitCode; Lines = $lines; Message = ''; ErrorMessage = $null; Result = $null; WingetPath = ''; DurationMs = 0
        RunAs = $(if (& $field 'RunAs') { & $field 'RunAs' } else { 'Direct' }); UserSid = (& $field 'UserSid'); UserName = (& $field 'UserName'); Reason = (& $field 'Reason')
    }
    if ($null -eq $raw) {
        $call.Message = "Komputer '{0}' nie zwrócił wyniku winget." -f $ComputerName
        return [pscustomobject]$call
    }
    $call.Found = [bool]$raw.Found
    $call.WingetPath = [string]$raw.WingetPath
    $call.DurationMs = [int]$raw.DurationMs
    $who = if ($call.RunAs -eq 'User') { 'użytkownika {0}' -f $(if ($call.UserName) { $call.UserName } else { $call.UserSid }) } elseif ($call.RunAs -eq 'System') { 'konta SYSTEM' } else { 'konta tej sesji' }
    switch ($call.Reason) {
        'NotAdministrator' {
            $call.Message = "winget na komputerze '{0}' jest uruchamiany przez zadanie harmonogramu — wymaga konta administratora w połączeniu." -f $ComputerName
        }
        'UserNotLoggedOn' {
            $call.Message = "Użytkownik {1} nie jest zalogowany na komputerze '{0}' — zaloguj się na nim, żeby obsłużyć programy jego profilu przez winget." -f $ComputerName, $(if ($call.UserName) { $call.UserName } else { $call.UserSid })
        }
        'TaskFailed' {
            $call.Message = "Zadanie harmonogramu winget ({1}) na komputerze '{0}' nie powiodło się: {2}" -f $ComputerName, $who, $raw.Error
        }
        'TimedOut' {
            $call.Message = "winget ({1}) na komputerze '{0}' nie zakończył się w limicie czasu — zadanie zatrzymane, procesy zakończone, zadanie usunięte." -f $ComputerName, $who
        }
        'Cancelled' {
            $call.Message = "winget ({1}) na komputerze '{0}' przerwany — zadanie zatrzymane i usunięte." -f $ComputerName, $who
        }
        default {
            if ($raw.Error) {
                $call.Message = "Nie udało się uruchomić winget na komputerze '{0}': {1}" -f $ComputerName, $raw.Error
            }
            elseif (-not $raw.Found) {
                $call.Message = "winget (Instalator aplikacji) jest niedostępny na komputerze '{0}' dla {1}." -f $ComputerName, $who
            }
            elseif ($raw.TimedOut) {
                $call.Message = "winget na komputerze '{0}' nie zakończył się w limicie czasu (proces przerwany)." -f $ComputerName
            }
            else {
                # Kod HRESULT winget to liczba ujemna w [int]; porównujemy po 32 bitach.
                $code = $exitCode -band 0xFFFFFFFFL
                $allowed = @($AllowedExitCode | ForEach-Object { $_ -band 0xFFFFFFFFL })
                if ($code -eq 0 -or $allowed -contains $code) {
                    $call.Success = $true
                }
                else {
                    $call.Message = Get-MwpWingetErrorText -ExitCode $exitCode -Line $lines
                }
            }
        }
    }
    if (-not $call.Success) {
        $call.ErrorMessage = $(if ($raw.Error) { [string]$raw.Error } else { $call.Message })
    }
    [pscustomobject]$call
}
