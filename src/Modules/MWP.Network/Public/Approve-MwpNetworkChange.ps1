function Approve-MwpNetworkChange {
    <#
    .SYNOPSIS
        Zatwierdza zmianę sieci czekającą na potwierdzenie: usuwa zadanie automatycznego wycofania na komputerze docelowym.

    .DESCRIPTION
        Operacja klasy Zmiana (D-049). Zatwierdzenie idzie tym samym połączeniem, którego działanie
        potwierdza — jeśli zmiana odcięła komputer, zatwierdzenie się nie uda, a zadanie przywróci stan
        sprzed zmiany. Wymaga administratora na komputerze docelowym. Brak zadania (zmiana już wycofana
        albo zatwierdzona) daje wynik bez zmiany z wyjaśnieniem. Bez wpisu cofnięcia — zmianę cofa się
        wpisem cofnięcia samej zmiany (Invoke-MwpUndo).

    .PARAMETER ChangeId
        Identyfikator zmiany (wynik Set-MwpDnsServer / Disable-MwpNetAdapter, pole Data.ChangeId, albo
        Get-MwpNetworkStatus, pole Pending).

    .EXAMPLE
        Approve-MwpNetworkChange -ChangeId $result.Data.ChangeId
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')]
        [string] $ChangeId,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Network.ApproveChange'
    $computerName = $Context.ComputerName
    $config = Get-MwpNetworkTargetConfig
    $taskName = $config.TaskPrefix + $ChangeId
    $common = @{ Operation = $operation; Target = ('zmiana {0}' -f $ChangeId); ComputerName = $computerName }
    $action = 'Zatwierdzenie zmiany sieci — usunięcie zadania automatycznego wycofania {0}{1}' -f $config.TaskPath, $taskName
    $target = Format-MwpOperationTarget -Target ('zmiana sieci {0}' -f $ChangeId) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before 'czeka na zatwierdzenie' -After 'zatwierdzona' -Message ('Podgląd: {0}.' -f $action)
    }
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ TaskPath = $config.TaskPath; TaskName = $taskName })
    $result = Invoke-MwpOnTarget -Context $Context -Operation $operation -ScriptBlock (Get-MwpNetworkScript -Name Approve) -ArgumentList @($request)
    if (-not $result.Success) {
        $message = "Nie udało się zatwierdzić zmiany {0} na komputerze '{1}': {2} Bez zatwierdzenia zmiana zostanie wycofana automatycznie." -f $ChangeId, $computerName, $result.Message
        Write-MwpLog -Level Warning -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $result.ErrorMessage
    }
    $raw = ConvertFrom-MwpNetworkJson -Data $result -Kind 'MWP.NetworkApproveRaw'
    if ($null -eq $raw -or $raw.Error) {
        $detail = if ($null -ne $raw) { [string]$raw.Error } else { 'brak wyniku' }
        $message = "Nie udało się zatwierdzić zmiany {0} na komputerze '{1}': {2}" -f $ChangeId, $computerName, $detail
        Write-MwpLog -Level Warning -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $detail
    }
    if (-not $raw.Found) {
        $message = "Zmiana {0} nie czeka na zatwierdzenie na komputerze '{1}' (już zatwierdzona albo wycofana automatycznie)." -f $ChangeId, $computerName
        Write-MwpLog -Level Warning -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $true -Message $message
    }
    $message = "Zatwierdzono zmianę sieci {0} na komputerze '{1}' — automatyczne wycofanie anulowane." -f $ChangeId, $computerName
    Write-MwpLog -Level Info -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message
    New-MwpResult @common -Success $true -Changed $true -Before 'czeka na zatwierdzenie' -After 'zatwierdzona' -Message $message
}
