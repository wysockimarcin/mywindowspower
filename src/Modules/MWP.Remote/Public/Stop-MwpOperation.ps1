function Stop-MwpOperation {
    <#
    .SYNOPSIS
        Anuluje operację asynchroniczną i zwalnia jej zasoby.

    .DESCRIPTION
        Zatrzymuje wykonanie w runspace puli (zdalnie: przerywa wywołanie WinRM i zamyka jego
        połączenie). Anulowanie nie cofa zmian, które blok zdążył wykonać; służy do tego rejestr
        cofnięć funkcji obszaru. Operacja zakończona wcześniej nie jest zmieniana.

    .EXAMPLE
        Stop-MwpOperation -Operation $operation
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PSTypeName('MWP.Operation')]
        [object] $Operation
    )

    process {
        if ($Operation.Status -ne 'Running') {
            return $Operation.Result
        }
        $common = @{ Operation = $Operation.Operation; Target = $Operation.ComputerName; ComputerName = $Operation.ComputerName }
        $target = Format-MwpOperationTarget -Target ("operacja {0} ({1})" -f $Operation.Operation, $Operation.Id) -ComputerName $Operation.ComputerName
        if (-not $PSCmdlet.ShouldProcess($target, 'Anulowanie operacji')) {
            return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd: operacja {0} zostanie anulowana." -f $Operation.Operation)
        }
        try {
            $Operation.PowerShell.Stop()
        }
        catch {
            Write-Verbose ("Zatrzymanie operacji {0}: {1}" -f $Operation.Id, $_.Exception.Message)
        }
        $message = "Anulowano operację {0} na komputerze '{1}'." -f $Operation.Operation, $Operation.ComputerName
        Complete-MwpOperation -Operation $Operation -Status Cancelled -Result (New-MwpResult @common -Success $false -Message $message)
    }
}
