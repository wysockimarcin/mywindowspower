function Invoke-MwpCredentialApi {
    <#
    .SYNOPSIS
        Adapter magazynu poświadczeń: jedno wywołanie Menedżera poświadczeń Windows (odczyt, zapis, usunięcie).

    .DESCRIPTION
        Najcieńsza warstwa nad typem z P/Invoke (Initialize-MwpCredentialType, D-052): przekazuje
        argumenty i zwraca kod błędu Win32 (0 = sukces) oraz dane wpisu. Nie interpretuje wyniku (to
        robią Get-, Set-, Remove- i Test-MwpStoredCredential). Testy podmieniają tę funkcję mockiem,
        więc nie dotykają prawdziwego magazynu. Tylko wpisy typu generic.

    .PARAMETER Action
        Read, Write albo Delete.

    .PARAMETER TargetName
        Nazwa wpisu (Get-MwpStoredCredentialName).

    .PARAMETER IncludePassword
        Read: zwróć hasło (SecureString); bez przełącznika tylko metadane.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Prywatny adapter; podgląd i potwierdzenie należą do funkcji publicznych (Save-, Remove-MwpTargetCredential).')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Read', 'Write', 'Delete')]
        [string] $Action,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $TargetName,

        [switch] $IncludePassword,

        [AllowEmptyString()]
        [string] $UserName,

        [AllowNull()]
        [securestring] $Password,

        [AllowEmptyString()]
        [string] $Comment = ''
    )

    $api = Initialize-MwpCredentialType
    switch ($Action) {
        'Read' {
            $user = $null
            $secret = $null
            $written = [datetime]::MinValue
            $size = 0
            $code = $api::Read($TargetName, [bool]$IncludePassword, [ref]$user, [ref]$secret, [ref]$written, [ref]$size)
            [pscustomobject]@{ ErrorCode = [int]$code; UserName = $user; Password = $secret; LastWritten = $written; BlobSize = [int]$size }
        }
        'Write' {
            [pscustomobject]@{ ErrorCode = [int]$api::Write($TargetName, $UserName, $Password, $Comment) }
        }
        'Delete' {
            [pscustomobject]@{ ErrorCode = [int]$api::Delete($TargetName) }
        }
    }
}
