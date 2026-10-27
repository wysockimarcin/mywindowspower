function Get-MwpPowercfgCommand {
    <#
    .SYNOPSIS
        Zwraca wynik jednego polecenia (Id) z surowych danych MWP.PowerRaw oraz opis błędu, gdy polecenie się nie powiodło.

    .DESCRIPTION
        Wynik: Found, ExitCode, Output (linie), Success (kod 0) i Message — komunikat po polsku
        z kodem wyjścia i tekstem powercfg (do wyniku MWP.Result).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Raw,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $command = $null
    if ($null -ne $Raw -and $null -ne $Raw.PSObject.Properties['Commands']) {
        $command = @($Raw.Commands | Where-Object { $null -ne $_ -and $_.Id -eq $Id }) | Select-Object -First 1
    }
    if ($null -eq $command) {
        return [pscustomobject]@{ Found = $false; Success = $false; ExitCode = $null; Output = @(); Message = "Polecenie powercfg ($Id) nie zostało wykonane." }
    }
    $output = @(@($command.Output) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
    $code = [int]$command.ExitCode
    $text = (@($output | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }) -join ' ')
    [pscustomobject]@{
        Found    = $true
        Success  = $code -eq 0
        ExitCode = $code
        Output   = $output
        Message  = $(if ($code -eq 0) { '' } else { 'powercfg zakończył się kodem {0}{1}' -f $code, $(if ($text) { ': ' + $text } else { '.' }) })
    }
}
