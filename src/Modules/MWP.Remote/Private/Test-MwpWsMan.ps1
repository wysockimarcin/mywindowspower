function Test-MwpWsMan {
    <#
    .SYNOPSIS
        Adapter transportu: sprawdza, czy usługa WinRM komputera docelowego odpowiada (bez uwierzytelnienia).

    .DESCRIPTION
        Test-WSMan bez poświadczeń wysyła anonimowe zapytanie identyfikujące, więc oddziela
        dostępność sieciową od uwierzytelnienia. Błąd jest zgłaszany jako wyjątek.
        Testy podmieniają tę funkcję mockiem.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [Parameter(Mandatory)]
        [int] $Port,

        [bool] $UseSsl
    )

    $parameters = @{ ComputerName = $ComputerName; Port = $Port; ErrorAction = 'Stop' }
    if ($UseSsl) {
        $parameters['UseSSL'] = $true
    }
    $null = Test-WSMan @parameters
}
