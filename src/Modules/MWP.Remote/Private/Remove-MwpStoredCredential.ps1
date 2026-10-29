function Remove-MwpStoredCredential {
    <#
    .SYNOPSIS
        Adapter magazynu poświadczeń: usuwa wpis MWP:<komputer> z Menedżera poświadczeń Windows.

    .DESCRIPTION
        Brak wpisu (kod 1168) to sukces z Removed = $false. Błędy są wynikiem (Success, Removed,
        ErrorCode, Message), nie wyjątkiem. Podgląd, potwierdzenie i log należą do
        Remove-MwpTargetCredential i Remove-MwpTarget.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Prywatny adapter; podgląd i potwierdzenie wykonuje Remove-MwpTargetCredential.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    $entry = Get-MwpStoredCredentialName -ComputerName $ComputerName
    $result = [pscustomobject]@{ PSTypeName = 'MWP.StoredCredentialChange'; Entry = $entry; Success = $false; Removed = $false; ErrorCode = 0; Message = $null }
    try {
        $result.ErrorCode = [int](Invoke-MwpCredentialApi -Action Delete -TargetName $entry).ErrorCode
    }
    catch {
        $result.Message = "Nie udało się usunąć wpisu '{0}' z Menedżera poświadczeń Windows: {1}" -f $entry, $_.Exception.Message
        return $result
    }
    switch ($result.ErrorCode) {
        0 {
            $result.Success = $true
            $result.Removed = $true
            $result.Message = "Usunięto wpis '{0}' z Menedżera poświadczeń Windows." -f $entry
        }
        1168 {
            $result.Success = $true
            $result.Message = "Wpisu '{0}' nie było w Menedżerze poświadczeń Windows." -f $entry
        }
        default {
            $result.Message = "Nie udało się usunąć wpisu '{0}' z Menedżera poświadczeń Windows: {1} (kod {2})." -f $entry, (New-Object -TypeName ComponentModel.Win32Exception -ArgumentList $result.ErrorCode).Message, $result.ErrorCode
        }
    }
    $result
}
