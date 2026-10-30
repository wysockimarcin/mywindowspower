function Get-MwpNameGuardScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu, który na komputerze docelowym sprawdza jego nazwę, a dopiero potem wykonuje blok modułu (D-054).

    .DESCRIPTION
        Używany przez Start-MwpOperation: każda operacja w tle otwiera własne połączenie, więc nazwa
        jest sprawdzana w każdym wywołaniu, zanim wykona się kod modułu. Argumenty: oczekiwana nazwa
        (pierwszy człon nazwy z rejestru; pusta — bez sprawdzania), tekst bloku modułu, a dalej argumenty
        bloku modułu (w $args, na najwyższym poziomie listy — ta sama głębokość serializacji co bez strażnika).
        Reguła jak w Test-MwpRemoteNameMatch: $env:COMPUTERNAME albo nazwa hosta, pierwszy człon, bez
        wielkości liter. Niezgodność zgłasza wyjątek ze znacznikiem MWP-NAMEMISMATCH:<nazwa zgłoszona>
        (Get-MwpRemoteErrorKind → NameMismatch). Blok jest samowystarczalny i zgodny z 5.1.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    {
        param([string] $MwpExpectedName, [string] $MwpScriptText)
        if (-not [string]::IsNullOrEmpty($MwpExpectedName)) {
            $MwpReported = @($env:COMPUTERNAME)
            try {
                $MwpReported += [System.Net.Dns]::GetHostName()
            }
            catch {
                $MwpReported += ''
            }
            $MwpMatch = @($MwpReported | Where-Object {
                    -not [string]::IsNullOrEmpty($_) -and [string]::Equals($_.Split('.')[0], $MwpExpectedName, [StringComparison]::OrdinalIgnoreCase)
                })
            if ($MwpMatch.Count -eq 0) {
                throw ('MWP-NAMEMISMATCH:' + $env:COMPUTERNAME)
            }
        }
        $MwpCode = [scriptblock]::Create($MwpScriptText)
        & $MwpCode @args
    }
}
