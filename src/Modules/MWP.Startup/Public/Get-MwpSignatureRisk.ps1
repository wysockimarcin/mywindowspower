function Get-MwpSignatureRisk {
    <#
    .SYNOPSIS
        Ocenia ryzyko pliku na podstawie podpisu cyfrowego (Get-AuthenticodeSignature): podpisany, niepodpisany, podpis nieprawidłowy, brak pliku.

    .DESCRIPTION
        Czysta funkcja (bez wywołań na komputerze docelowym). Wynik: Risk (Signed, Unsigned,
        Invalid, Missing, NotChecked, Unknown), RiskText po polsku i Publisher — nazwa wydawcy
        (CN, a gdy go brak — O) z tematu certyfikatu podpisującego. Plik bez obsługi podpisów
        (np. .bat, .cmd: NotSupportedFileFormat) jest traktowany jak niepodpisany. Podpis ważny
        oznacza tylko znanego wydawcę, nie bezpieczeństwo programu.

    .PARAMETER SignatureStatus
        Status podpisu z bloku odczytu (Valid, NotSigned, HashMismatch, NotTrusted, UnknownError,
        NotSupportedFileFormat, Incompatible) albo Missing, NotChecked, NoProgram (zadanie bez
        akcji uruchamiającej program, np. obsługa COM), Unknown.

    .PARAMETER SignerSubject
        Temat certyfikatu podpisującego (np. 'CN=Microsoft Corporation, O=Microsoft Corporation, ...').

    .EXAMPLE
        Get-MwpSignatureRisk -SignatureStatus Valid -SignerSubject 'CN=Contoso Ltd, O=Contoso Ltd'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $SignatureStatus,

        [AllowEmptyString()]
        [AllowNull()]
        [string] $SignerSubject
    )

    $risk = switch ($SignatureStatus) {
        'Valid' { 'Signed' }
        'NotSigned' { 'Unsigned' }
        'NotSupportedFileFormat' { 'Unsigned' }
        # UnknownError bez certyfikatu: format pliku bez podpisów (np. .bat — TRUST_E_SUBJECT_FORM_UNKNOWN).
        'UnknownError' { if ($SignerSubject) { 'Invalid' } else { 'Unsigned' } }
        { $_ -in 'HashMismatch', 'NotTrusted', 'Incompatible' } { 'Invalid' }
        'Missing' { 'Missing' }
        'NotChecked' { 'NotChecked' }
        'NoProgram' { 'NotApplicable' }
        default { 'Unknown' }
    }
    $text = switch ($risk) {
        'Signed' { 'Podpisany' }
        'Unsigned' { 'Niepodpisany' }
        'Invalid' { 'Podpis nieprawidłowy' }
        'Missing' { 'Brak pliku' }
        'NotChecked' { 'Nie sprawdzano' }
        'NotApplicable' { 'Nie dotyczy (akcja bez programu)' }
        default { 'Nieznany' }
    }
    $publisher = $null
    if ($SignerSubject) {
        foreach ($field in 'CN', 'O') {
            $match = [regex]::Match($SignerSubject, ('(?:^|,\s*){0}=("[^"]*"|[^,]*)' -f $field))
            if ($match.Success -and $match.Groups[1].Value.Trim()) {
                $publisher = $match.Groups[1].Value.Trim().Trim('"')
                break
            }
        }
    }
    [pscustomobject]@{
        Risk      = $risk
        RiskText  = $text
        Publisher = $publisher
    }
}
