function Get-MwpStoredCredential {
    <#
    .SYNOPSIS
        Adapter magazynu poświadczeń: czyta wpis MWP:<komputer> z Menedżera poświadczeń Windows.

    .DESCRIPTION
        Błędy są wynikiem, nie wyjątkiem (D-052). Status: Found (Credential = PSCredential z hasłem
        w SecureString), NotFound (brak wpisu, kod 1168), InvalidFormat (brak konta albo hasła, blob
        o nieparzystej długości — wpis nie pochodzi z aplikacji albo jest uszkodzony), Error (inny kod
        Win32 albo błąd kompilacji adaptera). Message nigdy nie zawiera hasła. -MetadataOnly czyta
        tylko konto i datę zapisu (bez hasła).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [switch] $MetadataOnly
    )

    $entry = Get-MwpStoredCredentialName -ComputerName $ComputerName
    $result = [pscustomobject]@{
        PSTypeName   = 'MWP.StoredCredential'
        ComputerName = $ComputerName
        Entry        = $entry
        Status       = 'Error'
        UserName     = $null
        LastWritten  = $null
        Credential   = $null
        ErrorCode    = 0
        Message      = $null
    }
    try {
        $answer = Invoke-MwpCredentialApi -Action Read -TargetName $entry -IncludePassword:(-not $MetadataOnly)
    }
    catch {
        $result.Message = "Nie udało się odczytać Menedżera poświadczeń Windows (wpis '{0}'): {1}" -f $entry, $_.Exception.Message
        return $result
    }
    $result.ErrorCode = [int]$answer.ErrorCode
    if ($result.ErrorCode -eq 1168) {
        $result.Status = 'NotFound'
        $result.Message = "Brak zapisanego hasła dla komputera '{0}' (wpis '{1}')." -f $ComputerName, $entry
        return $result
    }
    if ($result.ErrorCode -ne 0) {
        $result.Message = "Nie udało się odczytać wpisu '{0}' z Menedżera poświadczeń Windows: {1} (kod {2})." -f $entry, (New-Object -TypeName ComponentModel.Win32Exception -ArgumentList $result.ErrorCode).Message, $result.ErrorCode
        return $result
    }

    $result.UserName = $(if ([string]::IsNullOrWhiteSpace([string]$answer.UserName)) { $null } else { [string]$answer.UserName })
    $result.LastWritten = $(if ($answer.LastWritten -is [datetime] -and $answer.LastWritten -gt [datetime]::MinValue) { $answer.LastWritten } else { $null })
    $badBlob = [int]$answer.BlobSize -le 0 -or [int]$answer.BlobSize % 2 -ne 0
    if ($null -eq $result.UserName -or $badBlob -or (-not $MetadataOnly -and ($null -eq $answer.Password -or $answer.Password.Length -eq 0))) {
        if ($null -ne $answer.Password) {
            $answer.Password.Dispose()
        }
        $result.Status = 'InvalidFormat'
        $result.Message = "Wpis '{0}' w Menedżerze poświadczeń Windows ma nieoczekiwany format (brak konta albo hasła); nie zostanie użyty." -f $entry
        return $result
    }
    if (-not $MetadataOnly) {
        $result.Credential = New-Object -TypeName Management.Automation.PSCredential -ArgumentList $result.UserName, $answer.Password
    }
    $result.Status = 'Found'
    $result.Message = "Znaleziono zapisane hasło konta '{0}' dla komputera '{1}'." -f $result.UserName, $ComputerName
    $result
}
