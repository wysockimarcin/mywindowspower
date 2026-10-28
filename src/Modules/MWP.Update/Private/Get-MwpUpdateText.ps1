function Get-MwpUpdateText {
    <#
    .SYNOPSIS
        Zwraca polski opis wartości Windows Update Agent: kod wyniku, operacji historii, zachowania restartu, ważności, kodu błędu (HRESULT), stanu i typu uruchomienia usługi.

    .PARAMETER Kind
        Rodzaj wartości.

    .PARAMETER Value
        Wartość (liczba, tekst albo HRESULT w postaci 0xXXXXXXXX).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ResultCode', 'Operation', 'RebootBehavior', 'Severity', 'HResult', 'ServiceStatus', 'StartupType', 'UpdateType')]
        [string] $Kind,

        [AllowNull()]
        [AllowEmptyString()]
        [object] $Value
    )

    $text = [string]$Value
    switch ($Kind) {
        'ResultCode' {
            switch ($text) {
                '0' { 'Nie rozpoczęto' }
                '1' { 'W toku' }
                '2' { 'Powodzenie' }
                '3' { 'Powodzenie z błędami' }
                '4' { 'Niepowodzenie' }
                '5' { 'Przerwano' }
                default { 'Nieznany' }
            }
        }
        'Operation' {
            switch ($text) {
                '1' { 'Instalacja' }
                '2' { 'Odinstalowanie' }
                default { 'Inna' }
            }
        }
        'RebootBehavior' {
            switch ($text) {
                '0' { 'Nie' }
                '1' { 'Tak' }
                '2' { 'Możliwy' }
                default { 'Nieznany' }
            }
        }
        'Severity' {
            switch ($text) {
                'Critical' { 'Krytyczna' }
                'Important' { 'Ważna' }
                'Moderate' { 'Umiarkowana' }
                'Low' { 'Niska' }
                '' { '' }
                default { $text }
            }
        }
        'UpdateType' {
            switch ($text) {
                '1' { 'Oprogramowanie' }
                '2' { 'Sterownik' }
                default { 'Inna' }
            }
        }
        'HResult' {
            switch ($text.ToUpperInvariant()) {
                '0X00000000' { '' }
                '0X80070005' { 'odmowa dostępu — wymagane uprawnienia administratora; w sesji zdalnej (WinRM) Windows Update Agent blokuje część operacji' }
                '0X80240016' { 'inna instalacja jest w toku (WU_E_OPERATIONINPROGRESS)' }
                '0X8024001E' { 'usługa Windows Update jest zatrzymywana albo system się zamyka (WU_E_SERVICE_STOP)' }
                '0X80240024' { 'brak aktualizacji (WU_E_NO_UPDATE)' }
                '0X8024402C' { 'brak połączenia z serwerem aktualizacji (nazwa serwera lub serwer proxy)' }
                '0X8024401C' { 'przekroczony limit czasu połączenia z serwerem aktualizacji' }
                '0X80072EE2' { 'przekroczony limit czasu połączenia (sieć)' }
                '0X80072EFD' { 'nie można połączyć się z serwerem aktualizacji (sieć)' }
                '0X8024000B' { 'operacja anulowana (WU_E_CALL_CANCELLED)' }
                '0X80240438' { 'brak połączenia z usługą Windows Update (sieć lub zasady)' }
                '0X800F0922' { 'instalacja nie powiodła się (miejsce w partycji systemowej, sieć VPN albo .NET)' }
                '0X80073712' { 'uszkodzony magazyn składników (DISM /RestoreHealth)' }
                default { '' }
            }
        }
        'ServiceStatus' {
            switch ($text -replace '\s', '') {
                'Running' { 'Działa' }
                'Stopped' { 'Zatrzymana' }
                'StartPending' { 'Uruchamianie' }
                'StopPending' { 'Zatrzymywanie' }
                'Paused' { 'Wstrzymana' }
                'Missing' { 'Brak usługi' }
                default { 'Nieznany' }
            }
        }
        'StartupType' {
            switch ($text) {
                'Automatic' { 'Automatyczny' }
                'AutomaticDelayedStart' { 'Automatyczny (opóźniony start)' }
                'Manual' { 'Ręczny' }
                'Disabled' { 'Wyłączony' }
                default { 'Nieznany' }
            }
        }
    }
}
