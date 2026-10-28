function Clear-MwpDnsCache {
    <#
    .SYNOPSIS
        Opróżnia pamięć podręczną klienta DNS na komputerze docelowym (Clear-DnsClientCache, jak ipconfig /flushdns).

    .DESCRIPTION
        Operacja klasy Zmiana (D-049) bez wpisu cofnięcia — pamięci podręcznej nie da się odtworzyć,
        a jej opróżnienie nie zmienia konfiguracji (wpisy wracają przy kolejnych zapytaniach).
        Podgląd (-WhatIf) i potwierdzenie z nazwą komputera, log.

    .EXAMPLE
        Clear-MwpDnsCache -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Network.FlushDns'
    $computerName = $Context.ComputerName
    $common = @{ Operation = $operation; Target = 'pamięć podręczna DNS'; ComputerName = $computerName }
    $target = Format-MwpOperationTarget -Target 'pamięć podręczna DNS' -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, 'Opróżnienie pamięci podręcznej DNS (bez wpisu cofnięcia)')) {
        return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd: opróżnienie pamięci podręcznej DNS na komputerze '{0}'." -f $computerName)
    }
    $result = Invoke-MwpOnTarget -Context $Context -Operation $operation -ScriptBlock (Get-MwpNetworkScript -Name FlushDns)
    $raw = if ($result.Success) { ConvertFrom-MwpNetworkJson -Data $result -Kind 'MWP.NetworkFlushRaw' } else { $null }
    if ($null -eq $raw -or $raw.Error) {
        $detail = if ($null -ne $raw) { [string]$raw.Error } else { $result.Message }
        $message = "Nie udało się opróżnić pamięci DNS na komputerze '{0}': {1}" -f $computerName, $detail
        Write-MwpLog -Level Error -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $detail
    }
    $message = "Opróżniono pamięć podręczną DNS na komputerze '{0}'." -f $computerName
    Write-MwpLog -Level Info -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message
    New-MwpResult @common -Success $true -Changed $true -Message $message
}
