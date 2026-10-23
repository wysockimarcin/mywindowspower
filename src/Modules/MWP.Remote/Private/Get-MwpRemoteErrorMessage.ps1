function Get-MwpRemoteErrorMessage {
    <#
    .SYNOPSIS
        Zwraca czytelny komunikat po polsku dla rodzaju błędu połączenia (Get-MwpRemoteErrorKind).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Kind,

        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [AllowEmptyString()]
        [string] $Detail = ''
    )

    $computer = $Context.ComputerName
    $message = switch ($Kind) {
        'Unauthorized' {
            "Odmowa dostępu do komputera '{0}': sprawdź nazwę użytkownika i hasło oraz to, czy konto ma prawo zdalnego zarządzania (administrator)." -f $computer
        }
        'CredentialRequired' {
            "Połączenie z komputerem '{0}' wymaga poświadczeń: podaj -Credential (np. Get-Credential)." -f $computer
        }
        'Configuration' {
            "Klient WinRM nie ufa komputerowi '{0}' (grupa robocza): dodaj tę nazwę do TrustedHosts albo użyj HTTPS; instrukcja w ARCHITEKTURA.md. Aplikacja nie zmienia TrustedHosts." -f $computer
        }
        'Timeout' {
            "Przekroczono limit czasu połączenia lub operacji na komputerze '{0}'." -f $computer
        }
        'Network' {
            "Komputer '{0}' jest niedostępny przez WinRM (port {1}): sprawdź, czy jest włączony, czy działa usługa WinRM i czy zapora przepuszcza ruch." -f $computer, $Context.Port
        }
        'ConnectionLost' {
            "Utracono połączenie z komputerem '{0}'." -f $computer
        }
        default {
            "Błąd połączenia z komputerem '{0}'." -f $computer
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($Detail)) {
        $message = '{0} Szczegóły: {1}' -f $message, $Detail.Trim()
    }
    $message
}
