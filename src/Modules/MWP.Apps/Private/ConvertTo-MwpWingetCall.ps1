function ConvertTo-MwpWingetCall {
    <#
    .SYNOPSIS
        Zamienia surowy wynik bloku Winget (MWP.WingetRaw) na wynik wywołania z komunikatem po polsku.

    .DESCRIPTION
        Success = winget znaleziony, zakończony w limicie czasu i z kodem 0 (albo dozwolonym w
        -AllowedExitCode, np. „nie znaleziono pakietu” przy liście). Brak winget, przekroczony limit
        i błąd uruchomienia mają osobne komunikaty.
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
    $call = [ordered]@{ Success = $false; Found = $false; ExitCode = $exitCode; Lines = $lines; Message = ''; ErrorMessage = $null; Result = $null; WingetPath = ''; DurationMs = 0 }
    if ($null -eq $raw) {
        $call.Message = "Komputer '{0}' nie zwrócił wyniku winget." -f $ComputerName
        return [pscustomobject]$call
    }
    $call.Found = [bool]$raw.Found
    $call.WingetPath = [string]$raw.WingetPath
    $call.DurationMs = [int]$raw.DurationMs
    if ($raw.Error) {
        $call.Message = "Nie udało się uruchomić winget na komputerze '{0}': {1}" -f $ComputerName, $raw.Error
        $call.ErrorMessage = [string]$raw.Error
    }
    elseif (-not $raw.Found) {
        $call.Message = "winget (Instalator aplikacji) jest niedostępny na komputerze '{0}' dla konta tej sesji." -f $ComputerName
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
            $call.ErrorMessage = $call.Message
        }
    }
    [pscustomobject]$call
}
