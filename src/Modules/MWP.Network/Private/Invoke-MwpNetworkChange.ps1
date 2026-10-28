function Invoke-MwpNetworkChange {
    <#
    .SYNOPSIS
        Wspólne wykonanie zmiany adaptera po potwierdzeniu (DNS, wyłączenie, włączenie): zadanie wycofania, zmiana, wpis cofnięcia, log i wynik.

    .DESCRIPTION
        Używana przez Set-MwpDnsServer, Disable-MwpNetAdapter i Enable-MwpNetAdapter po ich sprawdzeniach
        i ShouldProcess (wzorzec funkcji zmieniającej system, ARCHITEKTURA.md). Gdy -RollbackSeconds > 0,
        blok Change rejestruje na komputerze docelowym jednorazowe zadanie wycofania (D-049): bez
        zatwierdzenia (Approve-MwpNetworkChange) stan wraca sam po limicie czasu — także wtedy, gdy
        zmiana odcięła połączenie. Utrata połączenia w trakcie daje wynik z błędem i informacją
        o automatycznym wycofaniu (wpisu cofnięcia wtedy nie ma — host nie zna wyniku). Wpis cofnięcia
        (po udanej zmianie) przywraca stan bez zadania wycofania (-RollbackSeconds 0 — powrót do stanu
        znanego jako działający).

    .PARAMETER Kind
        Dns, AdapterDisable albo AdapterEnable.

    .PARAMETER Adapter
        MWP.NetAdapter z odczytu przed zmianą.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Funkcja wewnętrzna wywoływana po ShouldProcess funkcji publicznej.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [Parameter(Mandatory)]
        [ValidateSet('Dns', 'AdapterDisable', 'AdapterEnable')]
        [string] $Kind,

        [Parameter(Mandatory)]
        [object] $Adapter,

        [AllowEmptyCollection()]
        [string[]] $ServerAddress = @(),

        [ValidateRange(0, 3600)]
        [int] $RollbackSeconds = 0,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Summary
    )

    $computerName = $Context.ComputerName
    $target = "adapter '{0}'" -f $Adapter.Name
    $common = @{ Operation = $Operation; Target = $target; ComputerName = $computerName }
    $config = Get-MwpNetworkTargetConfig
    $changeId = if ($RollbackSeconds -gt 0) { [guid]::NewGuid().ToString() } else { '' }
    $taskName = $config.TaskPrefix + $changeId
    $request = ConvertTo-Json -Compress -Depth 4 -InputObject ([pscustomobject]@{
            Kind             = $Kind
            InterfaceIndex   = [int]$Adapter.InterfaceIndex
            InterfaceGuid    = [string]$Adapter.InterfaceGuid
            ServerAddresses  = @($ServerAddress)
            RollbackSeconds  = $RollbackSeconds
            TaskPath         = $config.TaskPath
            TaskName         = $taskName
            RollbackTemplate = Get-MwpNetworkRollbackScript
            Description      = ('My Windows Power: automatyczne wycofanie zmiany sieci ({0}). Zatwierdzenie zmiany w aplikacji usuwa to zadanie.' -f $Summary)
        })
    $approximate = (Get-Date).AddSeconds($RollbackSeconds)
    Write-MwpLog -Level Info -Source 'MWP.Network' -Operation $Operation -ComputerName $computerName `
        -Message ('{0}: start{1}.' -f $Summary, $(if ($RollbackSeconds -gt 0) { ' (zatwierdzenie w {0} s, zmiana {1})' -f $RollbackSeconds, $changeId } else { '' }))
    $data = [ordered]@{ PSTypeName = 'MWP.NetworkChange'; ChangeId = $changeId; Deadline = $null; RemainingSeconds = 0; RollbackPending = $false; Kind = $Kind; InterfaceIndex = [int]$Adapter.InterfaceIndex }

    $result = Invoke-MwpOnTarget -Context $Context -Operation $Operation -ScriptBlock (Get-MwpNetworkScript -Name Change) -ArgumentList @($request) -TimeoutSeconds 90
    if (-not $result.Success) {
        $message = "{0} na komputerze '{1}' — brak odpowiedzi: {2}" -f $Summary, $computerName, $result.Message
        if ($RollbackSeconds -gt 0) {
            $message = '{0} Jeśli zmiana została wykonana przed utratą połączenia, komputer wycofa ją sam około {1:HH:mm:ss} (zadanie {2}{3}).' -f $message, $approximate, $config.TaskPath, $taskName
            $data.Deadline = $approximate
            $data.RollbackPending = $true
        }
        Write-MwpLog -Level Error -Source 'MWP.Network' -Operation $Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $result.ErrorMessage -Data ([pscustomobject]$data)
    }
    $raw = ConvertFrom-MwpNetworkJson -Data $result -Kind 'MWP.NetworkChangeRaw'
    if ($null -eq $raw) {
        $message = "Komputer '{0}' nie zwrócił wyniku zmiany ({1})." -f $computerName, $Summary
        Write-MwpLog -Level Error -Source 'MWP.Network' -Operation $Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $result.ErrorMessage
    }
    $describe = {
        param($State)
        if ($null -eq $State) { return '' }
        if ($Kind -eq 'Dns') { return Format-MwpDnsServerText -Server @($State.Servers | Where-Object { $_ } | ForEach-Object { [string]$_ }) }
        Get-MwpNetAdapterStatusText -Status ([string]$State.Status)
    }
    $beforeText = & $describe $raw.Before
    $afterText = & $describe $raw.After
    if ($raw.Error) {
        $message = "{0} na komputerze '{1}' nie powiodła się: {2}{3}" -f $Summary, $computerName, $raw.Error, $(if ($raw.RolledBack) { ' Stan sprzed zmiany został przywrócony.' } else { '' })
        Write-MwpLog -Level Error -Source 'MWP.Network' -Operation $Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $beforeText -Message $message -ErrorMessage $raw.Error
    }

    $changed = $beforeText -ne $afterText
    $undoId = $null
    if ($changed) {
        $identity = @{ InterfaceIndex = [int]$Adapter.InterfaceIndex; InterfaceGuid = [string]$Adapter.InterfaceGuid }
        switch ($Kind) {
            'Dns' {
                $previous = @($raw.Before.Servers | Where-Object { $_ } | ForEach-Object { [string]$_ })
                $parameters = $identity.Clone()
                $parameters['RollbackSeconds'] = 0
                if ($previous.Count -gt 0) { $parameters['ServerAddress'] = $previous } else { $parameters['Preset'] = 'Dhcp' }
                $command = 'Set-MwpDnsServer'
            }
            'AdapterDisable' {
                $parameters = $identity.Clone()
                $command = 'Enable-MwpNetAdapter'
            }
            'AdapterEnable' {
                $parameters = $identity.Clone()
                $parameters['RollbackSeconds'] = 0
                $command = 'Disable-MwpNetAdapter'
            }
        }
        $undo = Save-MwpUndoEntry -Module 'MWP.Network' -Operation $Operation -Target $target -ComputerName $computerName `
            -Description ('{0}: {1} → {2}' -f $Summary, $beforeText, $afterText) -Before $beforeText -After $afterText -UndoCommand $command -UndoParameters $parameters
        $undoId = $undo.Id
    }
    $message = "{0} na komputerze '{1}': {2} → {3}." -f $Summary, $computerName, $beforeText, $afterText
    if (-not $changed) {
        $message = "{0} na komputerze '{1}': bez zmian ({2})." -f $Summary, $computerName, $afterText
    }
    if ($raw.RollbackRegistered) {
        $deadline = ConvertFrom-MwpNetworkDate -Value $raw.Deadline
        $data.Deadline = $deadline
        $data.RemainingSeconds = [int]$raw.RemainingSeconds
        $data.RollbackPending = $true
        $message = '{0} Zatwierdź zmianę w ciągu {1} s (Approve-MwpNetworkChange -ChangeId {2}) — bez zatwierdzenia komputer wycofa ją sam o {3:HH:mm:ss}.' -f $message, [int]$raw.RemainingSeconds, $changeId, $deadline
    }
    Write-MwpLog -Level Info -Source 'MWP.Network' -Operation $Operation -ComputerName $computerName -Message $message -Data @{ Before = $beforeText; After = $afterText; ChangeId = $changeId }
    New-MwpResult @common -Success $true -Changed $changed -Before $beforeText -After $afterText -UndoId $undoId -Message $message -Data ([pscustomobject]$data)
}
