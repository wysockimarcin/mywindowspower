function Format-MwpTargetLabel {
    <#
    .SYNOPSIS
        Zwraca etykietę komputera do pokazania w oknie: nazwę komputera (localhost — nazwę hosta) albo podtytuł z adresem i trybem.

    .DESCRIPTION
        Czysta funkcja (bez WPF), wspólna dla wszystkich widoków (D-054): tytuły instancji i widgetów,
        wiersze stanu, komunikaty, nazwy zadań w tle, karty komputerów i pasek stanu. Widoki nie sklejają
        etykiety z ComputerName samodzielnie (sprawdza to test statyczny w Xaml.Tests.ps1).
        Formaty:
        - Name (domyślnie): komputer zdalny — jego nazwa (identyfikator z rejestru); komputer lokalny —
          nazwa hosta ($env:COMPUTERNAME), bo „localhost” to tylko identyfikator wewnętrzny,
        - Subtitle: nazwa z adresem i trybem, np. „PC-BIURO (192.0.2.10, zdalnie, WinRM)”,
          „PC-BIURO (zdalnie, WinRM)” przy połączeniu po nazwie, „NAZWA-HOSTA (ten komputer, lokalnie)”.
        Adres LAN komputera lokalnego nie jest tu odczytywany (tylko Ustawienia, poza wątkiem UI).
        Wpis zapisany pod adresem IP (sprzed D-054) pokazuje adres jako nazwę — to oczekiwane do zmiany nazwy.

    .PARAMETER Context
        Kontekst wykonania (MWP.ExecutionContext): nazwa, tryb i adres połączenia.

    .PARAMETER ComputerName
        Sam identyfikator komputera (np. z konfiguracji widgetu albo wyniku operacji), gdy nie ma kontekstu.

    .EXAMPLE
        'Komputer {0} · {1} usług' -f (Format-MwpTargetLabel -Context $context), $count
    #>
    [CmdletBinding(DefaultParameterSetName = 'Context')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Context')]
        [AllowNull()]
        [object] $Context,

        [Parameter(Mandatory, ParameterSetName = 'Name')]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $ComputerName,

        [ValidateSet('Name', 'Subtitle')]
        [string] $Format = 'Name'
    )

    $address = ''
    if ($PSCmdlet.ParameterSetName -eq 'Context') {
        if ($null -eq $Context) {
            return ''
        }
        $name = [string]$Context.ComputerName
        $isLocal = [string]$Context.Mode -eq 'Local'
        if ($null -ne $Context.PSObject.Properties['Address']) {
            $address = [string]$Context.Address
        }
    }
    else {
        $name = [string]$ComputerName
        $isLocal = $name -eq '' -or $name -in @('localhost', '.', '127.0.0.1', '::1')
    }

    $label = $name
    if ($isLocal) {
        $label = $(if ([string]::IsNullOrEmpty($env:COMPUTERNAME)) { 'localhost' } else { $env:COMPUTERNAME })
    }
    if ($Format -eq 'Name') {
        return $label
    }
    if ($isLocal) {
        return '{0} (ten komputer, lokalnie)' -f $label
    }
    if ($address -ne '' -and -not [string]::Equals($address, $name, [StringComparison]::OrdinalIgnoreCase)) {
        return '{0} ({1}, zdalnie, WinRM)' -f $label, $address
    }
    '{0} (zdalnie, WinRM)' -f $label
}
