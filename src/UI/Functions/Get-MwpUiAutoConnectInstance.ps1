function Get-MwpUiAutoConnectInstance {
    <#
    .SYNOPSIS
        Wybiera instancje komputera zdalnego, które można połączyć w tle sprawdzonym hasłem z pamięci procesu.

    .DESCRIPTION
        Widoki modułów czytają dane operacjami w tle (Start-MwpOperation) z własnym, krótkim połączeniem,
        więc przy haśle komputera w pamięci procesu (D-052) instancja działa, ale jej połączenie zostaje
        w stanie „Rozłączono”, a przycisk „Połącz” wygląda na potrzebny. Instancje zwrócone tutaj host
        łączy sam (Connect-MwpUiInstance -Automatic): bez okna, bez Menedżera poświadczeń, tylko hasłem,
        które w tym uruchomieniu już przeszło uwierzytelnienie. Pomijane są: localhost, instancje
        innych komputerów, połączone lub łączące się, zajęte (Busy), rozłączone ręcznie przez
        użytkownika (ManualDisconnect), bez sprawdzonego hasła w pamięci (także po jego odrzuceniu)
        i z uwierzytelnieniem CurrentUser. Bez WPF, testowalna.

    .PARAMETER Entry
        Wpisy instancji okna (tabele z Open-MwpUiInstance).

    .PARAMETER ComputerName
        Komputer; bez niego — wszystkie komputery.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $Entry = @(),

        [AllowNull()]
        [AllowEmptyString()]
        [string] $ComputerName
    )

    foreach ($item in @($Entry)) {
        if ($null -eq $item -or $null -eq $item['Instance']) {
            continue
        }
        $context = $item.Instance.Context
        if ($context.Mode -ne 'Remote' -or $context.Identity.Authentication -ne 'Credential') {
            continue
        }
        if (-not [string]::IsNullOrEmpty($ComputerName) -and $context.ComputerName -ne $ComputerName) {
            continue
        }
        if ([int]$item['Busy'] -gt 0 -or [bool]$item['ManualDisconnect']) {
            continue
        }
        if ([string]$context.Connection.State -in @('Connected', 'Connecting')) {
            continue
        }
        $info = @(Get-MwpTargetCredentialInfo -Name $context.ComputerName -SkipStore) | Select-Object -First 1
        if ($null -ne $info -and [bool]$info.Cached) {
            $item
        }
    }
}
