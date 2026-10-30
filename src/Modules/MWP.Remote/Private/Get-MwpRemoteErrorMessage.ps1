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
        [string] $Detail = '',

        # Nazwa zgłoszona przez komputer zdalny (NameMismatch, D-054).
        [AllowNull()]
        [AllowEmptyString()]
        [string] $RemoteName = ''
    )

    $computer = $Context.ComputerName
    $address = $computer
    if ($null -ne $Context.PSObject.Properties['Address'] -and -not [string]::IsNullOrEmpty([string]$Context.Address)) {
        $address = [string]$Context.Address
    }
    $message = switch ($Kind) {
        'NameMismatch' {
            $reported = if ([string]::IsNullOrEmpty($RemoteName)) { 'nieznany' } else { $RemoteName }
            $text = "Pod adresem '{0}' odpowiada komputer '{1}', a nie '{2}' (np. serwer DHCP nadał ten adres innemu komputerowi). " +
            "Operacje na komputerze '{2}' są zablokowane: popraw adres w edytorze komputera (Ustawienia → Komputery docelowe)."
            $text -f $address, $reported, $computer
        }
        'Unauthorized' {
            "Odmowa dostępu do komputera '{0}': sprawdź nazwę użytkownika i hasło oraz to, czy konto ma prawo zdalnego zarządzania (administrator)." -f $computer
        }
        'CredentialRequired' {
            "Połączenie z komputerem '{0}' wymaga poświadczeń: podaj -Credential (np. Get-Credential)." -f $computer
        }
        'CredentialRejected' {
            'Komputer ''{0}'' odrzucił poświadczenie w tym uruchomieniu; automatyczne ponowienia są wstrzymane (ochrona konta przed blokadą). Kliknij „Połącz”, aby podać hasło.' -f $computer
        }
        'StoredCredentialRejected' {
            'Komputer ''{0}'' odrzucił hasło zapisane w Menedżerze poświadczeń Windows (np. zmienione na komputerze zdalnym). Aplikacja nie użyje go ponownie w tym uruchomieniu; kliknij „Połącz”, aby podać nowe hasło, albo usuń zapisane w edytorze komputera („Zapomnij hasło”).' -f $computer
        }
        'Configuration' {
            if ($address -ne $computer) {
                $text = "Klient WinRM nie ufa komputerowi '{0}' (grupa robocza): połączenie idzie pod adres '{1}', więc do TrustedHosts trzeba dopisać '{1}' " +
                "(przy adresie IP działa tylko NTLM) albo użyć HTTPS; instrukcja w ARCHITEKTURA.md. Aplikacja nie zmienia TrustedHosts."
                $text -f $computer, $address
            }
            else {
                "Klient WinRM nie ufa komputerowi '{0}' (grupa robocza): dodaj tę nazwę do TrustedHosts albo użyj HTTPS; instrukcja w ARCHITEKTURA.md. Aplikacja nie zmienia TrustedHosts." -f $computer
            }
        }
        'Timeout' {
            "Przekroczono limit czasu połączenia lub operacji na komputerze '{0}'." -f $computer
        }
        'Network' {
            $where = if ($address -ne $computer) { "'{0}' (adres {1})" -f $computer, $address } else { "'{0}'" -f $computer }
            "Komputer {0} jest niedostępny przez WinRM (port {1}): sprawdź, czy jest włączony, czy działa usługa WinRM i czy zapora przepuszcza ruch." -f $where, $Context.Port
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
