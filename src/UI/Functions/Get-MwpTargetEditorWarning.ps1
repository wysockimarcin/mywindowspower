function Get-MwpTargetEditorWarning {
    <#
    .SYNOPSIS
        Zwraca ostrzeżenia edytora komputera (D-054): ten komputer jako zdalny, HTTPS z adresem, nazwa będąca adresem IP.

    .DESCRIPTION
        Czysta funkcja (bez WPF) — ostrzeżenia niczego nie blokują. Sprawdzenie „to ten komputer”
        należy do logiki (Test-MwpTargetIsLocalComputer, MWP.Remote); tu tylko składanie tekstów.
        Pusta nazwa — brak ostrzeżeń (walidację pól robi formularz, zapis i walidację — MWP.Remote).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Name = '',

        [AllowEmptyString()]
        [string] $Address = '',

        [bool] $UseSsl,

        [AllowNull()]
        [object] $LocalCheck
    )

    $Name = $Name.Trim()
    $Address = $Address.Trim()
    if ($Name -eq '') {
        return
    }
    if ($null -ne $LocalCheck -and $LocalCheck.IsLocalComputer) {
        [string]$LocalCheck.Message
    }
    if ($Address -ne '' -and $UseSsl) {
        "Przy HTTPS połączenie idzie po nazwie '{0}' (certyfikat jest wystawiony na nazwę), więc adres '{1}' jest pomijany." -f $Name, $Address
    }
    if ($Name -match '^\d{1,3}(\.\d{1,3}){3}$') {
        'Nazwa jest adresem IP: aplikacja nie sprawdzi, czy pod tym adresem jest właściwy komputer. Wpisz faktyczną nazwę komputera (przycisk „Odczytaj nazwę z komputera”), a adres w polu „Adres”.'
    }
}
