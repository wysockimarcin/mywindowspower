function Disconnect-MwpTarget {
    <#
    .SYNOPSIS
        Zamyka połączenie kontekstu wykonania (sesje WinRM i CIM) i zwalnia poświadczenia z pamięci.

    .DESCRIPTION
        Stan połączenia zmienia się na Disconnected. Inne konteksty (także dla tego samego komputera)
        nie są zmieniane. Poświadczenia są usuwane z obiektu połączenia, chyba że podano
        -KeepCredential. Dla komputera lokalnego nic się nie dzieje.

    .EXAMPLE
        Disconnect-MwpTarget -Context $remote
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [switch] $KeepCredential
    )

    process {
        $operation = 'Remote.Disconnect'
        $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
        $connection = $Context.Connection

        if ($Context.Mode -eq 'Local') {
            return New-MwpResult @common -Success $true -Message 'Komputer lokalny: brak połączenia do zamknięcia.'
        }

        $hadSession = $null -ne $connection.Session -or $null -ne $connection.CimSession
        Remove-MwpCimSession -CimSession $connection.CimSession
        Remove-MwpPSSession -Session $connection.Session
        $connection.CimSession = $null
        $connection.Session = $null
        if (-not $KeepCredential) {
            $connection.Credential = $null
        }
        Set-MwpConnectionState -Connection $connection -State Disconnected

        $message = "Rozłączono z komputerem '{0}'." -f $Context.ComputerName
        if ($hadSession) {
            Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName $Context.ComputerName -Message $message
        }
        New-MwpResult @common -Success $true -Changed $hadSession -Message $message
    }
}
