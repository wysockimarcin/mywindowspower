function Set-MwpPowerSetting {
    <#
    .SYNOPSIS
        Zmienia ustawienie planu zasilania dla zasilania sieciowego (AC) albo bateryjnego (DC): czas wygaszania ekranu, uśpienia, hibernacji albo akcję przycisku lub pokrywy.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt bieżącej wartości (/qh), podgląd (-WhatIf) z nazwą
        komputera, zmiana (/setacvalueindex albo /setdcvalueindex po GUID-ach podgrupy i ustawienia;
        dla planu aktywnego także /setactive, żeby zmiana zadziałała od razu), wpis cofnięcia
        (poprzednia wartość w tym samym planie) i log. Nie wymaga uprawnień administratora.
        Wartości: dla czasów — sekundy (0 = nigdy); dla akcji — indeks: 0 nic nie rób, 1 uśpij,
        2 hibernuj, 3 zamknij system, 4 wyłącz ekran (tylko przyciski).

    .PARAMETER Setting
        MonitorTimeout, SleepTimeout, HibernateTimeout, LidAction, PowerButtonAction, SleepButtonAction.

    .PARAMETER PowerSource
        AC (zasilanie sieciowe) albo DC (bateria).

    .PARAMETER Value
        Nowa wartość (sekundy albo indeks akcji).

    .PARAMETER PlanGuid
        GUID planu; domyślnie plan aktywny (jego GUID trafia do wpisu cofnięcia).

    .EXAMPLE
        Set-MwpPowerSetting -Setting MonitorTimeout -PowerSource AC -Value 600 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('MonitorTimeout', 'SleepTimeout', 'HibernateTimeout', 'LidAction', 'PowerButtonAction', 'SleepButtonAction')]
        [string] $Setting,

        [Parameter(Mandatory, Position = 1)]
        [ValidateSet('AC', 'DC')]
        [string] $PowerSource,

        [Parameter(Mandatory, Position = 2)]
        [ValidateRange(0, 2147483647)]
        [int] $Value,

        [ValidatePattern('^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')]
        [string] $PlanGuid,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $definition = @((Get-MwpPowerCatalog).Settings | Where-Object { $_.Id -eq $Setting })[0]
    $sourceText = if ($PowerSource -eq 'AC') { 'zasilanie sieciowe' } else { 'bateria' }
    $common = @{ Operation = 'Power.SetSetting'; Target = ('{0}/{1}' -f $Setting, $PowerSource); ComputerName = $computerName }

    if ($definition.Kind -eq 'Action' -and $Value -gt $definition.MaxIndex) {
        return New-MwpResult @common -Success $false -Message ("Niedozwolona akcja {0} dla ustawienia '{1}' (dozwolone 0–{2})." -f $Value, $definition.Label, $definition.MaxIndex)
    }
    $plan = if ($PSBoundParameters.ContainsKey('PlanGuid')) { $PlanGuid.ToLowerInvariant() } else { 'SCHEME_CURRENT' }
    $state = Read-MwpPowerState -Context $Context -Operation $common.Operation -Plan $plan -Setting $Setting
    if (-not $state.Success) {
        return New-MwpResult @common -Success $false -Message $state.Result.Message -ErrorMessage $state.Result.ErrorMessage
    }
    $planObject = if ($plan -eq 'SCHEME_CURRENT') { $state.Status.ActivePlan } else { @($state.Status.Plans | Where-Object { $_.Guid -eq $plan }) | Select-Object -First 1 }
    if ($null -eq $planObject) {
        return New-MwpResult @common -Success $false -Message ("Na komputerze '{0}' nie ma planu zasilania {1}." -f $computerName, $(if ($plan -eq 'SCHEME_CURRENT') { '(aktywnego)' } else { $plan }))
    }
    $current = @($state.Status.Settings | Where-Object { $_.Id -eq $Setting }) | Select-Object -First 1
    if ($null -eq $current -or -not $current.Available) {
        return New-MwpResult @common -Success $false -Message ("Ustawienie '{0}' jest niedostępne na komputerze '{1}' (np. pokrywa na komputerze stacjonarnym)." -f $definition.Label, $computerName)
    }
    $before = [long]$(if ($PowerSource -eq 'AC') { $current.Ac } else { $current.Dc })
    $beforeText = Format-MwpPowerValue -Value $before -Kind $definition.Kind
    $afterText = Format-MwpPowerValue -Value $Value -Kind $definition.Kind
    $planName = Format-MwpPowerPlanName -Plan $planObject
    $description = "{0} ({1}), plan {2}" -f $definition.Label, $sourceText, $planName
    if ($before -eq $Value) {
        return New-MwpResult @common -Success $true -Before $beforeText -After $afterText -Message ("{0}: bez zmian ({1})." -f $description, $afterText)
    }

    $target = Format-MwpOperationTarget -Target $description -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Zmiana z '{0}' na '{1}'" -f $beforeText, $afterText))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $beforeText -After $afterText -Message ("Podgląd: {0}: {1} → {2}." -f $description, $beforeText, $afterText)
    }

    $verb = if ($PowerSource -eq 'AC') { '/setacvalueindex' } else { '/setdcvalueindex' }
    $commands = @(@{ Id = 'set'; Arguments = @($verb, $planObject.Guid, $definition.SubGroup, $definition.Setting, [string]$Value) })
    if ($planObject.IsActive) {
        $commands += @{ Id = 'apply'; Arguments = @('/setactive', $planObject.Guid) }
    }
    $change = Invoke-MwpPowerChange -Context $Context -Operation $common.Operation -Command $commands
    if (-not $change.Success) {
        $message = "Nie udało się zmienić ustawienia {0} na komputerze '{1}': {2}" -f $description, $computerName, $change.Message
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $beforeText -Message $message -ErrorMessage $change.ErrorMessage
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Power' -Operation $common.Operation -Target $common.Target -ComputerName $computerName `
        -Description ("{0}: {1} → {2}" -f $description, $beforeText, $afterText) -Before $beforeText -After $afterText `
        -UndoCommand 'Set-MwpPowerSetting' -UndoParameters @{ Setting = $Setting; PowerSource = $PowerSource; Value = [int][Math]::Min($before, [long][int]::MaxValue); PlanGuid = $planObject.Guid }
    $message = "Zmieniono: {0}: {1} → {2}." -f $description, $beforeText, $afterText
    Write-MwpLog -Level Info -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Before = $before; After = $Value; Plan = $planObject.Guid }
    New-MwpResult @common -Success $true -Changed $true -Before $beforeText -After $afterText -UndoId $undo.Id -Message $message
}
