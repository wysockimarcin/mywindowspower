function Set-MwpStoredCredential {
    <#
    .SYNOPSIS
        Adapter magazynu poświadczeń: zapisuje konto i hasło komputera we wpisie MWP:<komputer>.

    .DESCRIPTION
        Wpis typu generic z trwałością CRED_PERSIST_LOCAL_MACHINE (bez roamingu); istniejący wpis jest
        zastępowany. Błędy są wynikiem (Success, ErrorCode, Message), nie wyjątkiem; komunikat nie
        zawiera hasła. Podgląd, potwierdzenie i log należą do Save-MwpTargetCredential.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Prywatny adapter; podgląd i potwierdzenie wykonuje Save-MwpTargetCredential.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    $entry = Get-MwpStoredCredentialName -ComputerName $ComputerName
    $result = [pscustomobject]@{ PSTypeName = 'MWP.StoredCredentialChange'; Entry = $entry; Success = $false; ErrorCode = 0; Message = $null }
    if ([string]::IsNullOrWhiteSpace($Credential.UserName) -or $Credential.Password.Length -eq 0) {
        $result.ErrorCode = 87
        $result.Message = 'Nie zapisano hasła: brak konta albo hasła.'
        return $result
    }
    try {
        $answer = Invoke-MwpCredentialApi -Action Write -TargetName $entry -UserName $Credential.UserName -Password $Credential.Password `
            -Comment ('MyWindowsPower: konto WinRM komputera {0}' -f $ComputerName)
        $result.ErrorCode = [int]$answer.ErrorCode
    }
    catch {
        $result.Message = "Nie udało się zapisać wpisu '{0}' w Menedżerze poświadczeń Windows: {1}" -f $entry, $_.Exception.Message
        return $result
    }
    if ($result.ErrorCode -ne 0) {
        $result.Message = "Nie udało się zapisać wpisu '{0}' w Menedżerze poświadczeń Windows: {1} (kod {2})." -f $entry, (New-Object -TypeName ComponentModel.Win32Exception -ArgumentList $result.ErrorCode).Message, $result.ErrorCode
        return $result
    }
    $result.Success = $true
    $result.Message = "Zapisano wpis '{0}' w Menedżerze poświadczeń Windows." -f $entry
    $result
}
