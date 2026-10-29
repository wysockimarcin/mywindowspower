function Resolve-MwpTargetStatus {
    <#
    .SYNOPSIS
        Zamienia surowy wynik bloku stanu komputerów (JSON albo MWP.Result) na obiekt MWP.TargetStatus.

    .DESCRIPTION
        Czysta funkcja (bez połączeń): wspólna dla Get-MwpTargetStatus i widoku widgetu „Komputery”.
        Zwraca $null, gdy danych nie ma albo są nieczytelne.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.Result') {
        $Data = $Data.Data
    }
    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.TargetStatus') {
        return $Data
    }
    $item = @($Data | Where-Object { $null -ne $_ }) | Select-Object -Last 1
    if ($item -is [string]) {
        try {
            $item = ConvertFrom-Json -InputObject $item -ErrorAction Stop
        }
        catch {
            return $null
        }
    }
    if ($null -eq $item -or $null -eq $item.PSObject.Properties['Kind'] -or $item.Kind -ne 'MWP.TargetStatusRaw') {
        return $null
    }
    $credentialText = @{ Verified = 'hasło sprawdzone'; Invalid = 'hasło odrzucone'; None = 'bez hasła w pamięci' }
    [pscustomobject]@{
        PSTypeName  = 'MWP.TargetStatus'
        CollectedAt = $(if ($null -ne $item.PSObject.Properties['CollectedAt'] -and $item.CollectedAt) { [datetime]$item.CollectedAt } else { $null })
        Probe       = [bool]$item.Probe
        Targets     = @($item.Targets | Where-Object { $null -ne $_ } | ForEach-Object {
                $credential = $(if ($credentialText.ContainsKey([string]$_.Credential)) { [string]$_.Credential } else { 'None' })
                [pscustomobject]@{
                    Name           = [string]$_.Name
                    DisplayName    = [string]$_.DisplayName
                    Port           = [int]$_.Port
                    Reachable      = $_.Reachable
                    LatencyMs      = $_.LatencyMs
                    Error          = [string]$_.Error
                    Credential     = $credential
                    CredentialText = $credentialText[$credential]
                }
            })
    }
}
