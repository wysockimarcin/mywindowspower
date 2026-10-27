function Set-MwpServiceStartupType {
    <#
    .SYNOPSIS
        Zmienia typ uruchomienia usługi na komputerze docelowym: Automatyczny, Automatyczny (opóźniony start), Ręczny, Wyłączony.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt usługi i grafu zależności, lista ochronna (usłudze
        chronionej wolno ustawić tylko typ automatyczny; usługi, od której zależy usługa chroniona,
        nie wolno wyłączyć — D-045), uprawnienia administratora na komputerze docelowym, podgląd
        (-WhatIf) i potwierdzenie z nazwą komputera. Zmiana: sc.exe config <nazwa> start= <tryb>
        (argumenty jako tablica, D-015) i ponowny odczyt typu na komputerze docelowym — niezgodność
        z oczekiwanym typem jest błędem. Wpis cofnięcia: poprzedni typ uruchomienia. Zmiana typu nie
        uruchamia ani nie zatrzymuje usługi.

    .PARAMETER Name
        Nazwa usługi (nie nazwa wyświetlana).

    .PARAMETER StartupType
        Automatic, AutomaticDelayedStart, Manual albo Disabled.

    .EXAMPLE
        Set-MwpServiceStartupType -Name Spooler -StartupType Manual -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ Test-MwpServiceName -Name $_ })]
        [string] $Name,

        [Parameter(Mandatory, Position = 1)]
        [ValidateSet('Automatic', 'AutomaticDelayedStart', 'Manual', 'Disabled')]
        [string] $StartupType,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $common = @{ Operation = 'Services.SetStartupType'; Target = $Name; ComputerName = $computerName }
    $wanted = @(Get-MwpServiceStartupTypeList | Where-Object { $_.Id -eq $StartupType }) | Select-Object -First 1

    $state = Read-MwpServiceState -Context $Context -Operation $common.Operation -Target $Name -Name @($Name) -IncludeGraph
    if (-not $state.Success) {
        return $state.Result
    }
    $service = $state.Service
    $common.Target = $service.Name
    $before = $service.StartupTypeText
    if ($service.StartupType -eq 'Unknown') {
        return New-MwpResult @common -Success $false -Before $before -Message ("Typ uruchomienia usługi '{0}' jest nieznany (np. usługa szablonowa użytkownika) — zmiana jest niedostępna." -f $service.DisplayName)
    }
    if ($service.StartupType -eq $StartupType) {
        return New-MwpResult @common -Success $true -Before $before -After $before -Message ("Usługa '{0}' ma już typ uruchomienia {1}." -f $service.DisplayName, $before)
    }
    if ($service.IsProtected -and -not $wanted.AllowedWhenProtected) {
        return New-MwpResult @common -Success $false -Before $before -After $wanted.Label `
            -Message ("Usługa '{0}' ({1}) jest na liście ochronnej — dozwolony jest tylko typ automatyczny. Powód: {2}" -f $service.DisplayName, $service.Name, $service.ProtectionReason)
    }
    $notes = New-Object -TypeName System.Collections.Generic.List[string]
    if ($StartupType -eq 'Disabled') {
        if (-not $state.List.HasGraph) {
            return New-MwpResult @common -Success $false -Before $before -Message ("Nie udało się odczytać zależności usługi '{0}', więc nie można jej bezpiecznie wyłączyć." -f $service.DisplayName)
        }
        $dependents = @(Get-MwpServiceDependent -Dependencies @($state.List.Dependencies) -Name $service.Name)
        try {
            $protectedItems = @(Get-MwpProtectedItem -Category Service)
        }
        catch {
            return New-MwpResult @common -Success $false -Before $before -Message ('Nie można odczytać listy ochronnej usług, więc zmiana jest zablokowana: {0}' -f $_.Exception.Message)
        }
        foreach ($dependentName in $dependents) {
            $protection = @($protectedItems | Where-Object { $dependentName -like $_.Name }) | Select-Object -First 1
            if ($null -ne $protection) {
                return New-MwpResult @common -Success $false -Before $before -After $wanted.Label `
                    -Message ("Nie można wyłączyć usługi '{0}': zależy od niej usługa chroniona '{1}'. Powód ochrony: {2}" -f $service.DisplayName, $dependentName, $protection.Reason)
            }
        }
        if ($dependents.Count -gt 0) {
            $notes.Add(('Usługi zależne nie uruchomią się: {0}.' -f ($dependents -join ', ')))
        }
        if ($service.Status -ne 'Stopped') {
            $notes.Add('Usługa działa — wyłączenie nie zatrzymuje jej (zatrzymaj ją osobno).')
        }
    }
    $noteText = if ($notes.Count -gt 0) { ' ' + ($notes -join ' ') } else { '' }

    $admin = Test-MwpServiceAdmin -Context $Context
    if (-not $admin.Success) {
        return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
    }
    if (-not $admin.IsAdministrator) {
        return New-MwpResult @common -Success $false -Before $before -Message ("Zmiana typu uruchomienia usług wymaga uprawnień administratora na komputerze '{0}'." -f $computerName)
    }

    $target = Format-MwpOperationTarget -Target ("usługa '{0}' ({1})" -f $service.DisplayName, $service.Name) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Typ uruchomienia: '{0}' → '{1}'" -f $before, $wanted.Label))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $wanted.Label -Message ("Podgląd: typ uruchomienia usługi '{0}': {1} → {2}.{3}" -f $service.DisplayName, $before, $wanted.Label, $noteText)
    }

    $change = Invoke-MwpOnTarget -Context $Context -Operation $common.Operation -ScriptBlock (Get-MwpServiceScript -Name StartupType) -ArgumentList @($service.Name, $wanted.ScMode)
    $raw = if ($change.Success) { ConvertFrom-MwpServiceJson -Data $change -Kind 'MWP.ServiceStartupChange' } else { $null }
    $failure = $null
    $actual = $null
    if (-not $change.Success) {
        $failure = $change.Message
    }
    elseif ($null -eq $raw) {
        $failure = "komputer nie zwrócił wyniku sc.exe"
    }
    else {
        $actual = switch ([string]$raw.StartMode) {
            'Auto' { if ($raw.Delayed) { 'AutomaticDelayedStart' } else { 'Automatic' } }
            'Manual' { 'Manual' }
            'Disabled' { 'Disabled' }
            default { 'Unknown' }
        }
        if ([int]$raw.ExitCode -ne 0) {
            $failure = switch ([int]$raw.ExitCode) {
                5 { 'odmowa dostępu (wymagane uprawnienia administratora)' }
                1060 { 'usługa nie istnieje' }
                1072 { 'usługa jest oznaczona do usunięcia' }
                default { 'sc.exe zakończył się kodem {0}: {1}' -f $raw.ExitCode, (@($raw.Output | Where-Object { $_ }) -join ' ') }
            }
        }
        elseif ($actual -ne $StartupType) {
            $failure = 'po zmianie typ uruchomienia to {0} zamiast {1}' -f (Get-MwpServiceText -StartupType $actual), $wanted.Label
        }
    }

    $undoId = $null
    if ($null -ne $actual -and $actual -ne 'Unknown' -and $actual -ne $service.StartupType) {
        $undo = Save-MwpUndoEntry -Module 'MWP.Services' -Operation $common.Operation -Target $service.Name -ComputerName $computerName `
            -Description ("Typ uruchomienia '{0}': {1} → {2}" -f $service.DisplayName, $before, (Get-MwpServiceText -StartupType $actual)) -Before $before -After (Get-MwpServiceText -StartupType $actual) `
            -UndoCommand 'Set-MwpServiceStartupType' -UndoParameters @{ Name = $service.Name; StartupType = $service.StartupType }
        $undoId = $undo.Id
    }
    if ($null -ne $failure) {
        $message = "Nie udało się zmienić typu uruchomienia usługi '{0}' na komputerze '{1}': {2}" -f $service.DisplayName, $computerName, $failure
        Write-MwpLog -Level Error -Source 'MWP.Services' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Before = $service.StartupType; Wanted = $StartupType; Actual = $actual }
        return New-MwpResult @common -Success $false -Changed ($null -ne $undoId) -Before $before -After $(if ($null -ne $actual) { Get-MwpServiceText -StartupType $actual } else { $null }) `
            -UndoId $undoId -Message $message -ErrorMessage $(if ($null -ne $raw) { @($raw.Output) -join ' ' } else { $change.ErrorMessage })
    }
    $message = "Typ uruchomienia usługi '{0}' na komputerze '{1}': {2} → {3}.{4}" -f $service.DisplayName, $computerName, $before, $wanted.Label, $noteText
    Write-MwpLog -Level Info -Source 'MWP.Services' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Before = $service.StartupType; After = $StartupType }
    New-MwpResult @common -Success $true -Changed $true -Before $before -After $wanted.Label -UndoId $undoId -Message $message
}
