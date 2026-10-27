function Copy-MwpPowerPlan {
    <#
    .SYNOPSIS
        Duplikuje plan zasilania na komputerze docelowym (powercfg /duplicatescheme), opcjonalnie z nową nazwą.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt planów, podgląd (-WhatIf) i potwierdzenie z nazwą
        komputera, utworzenie kopii z nowym GUID-em (odczytanym z wyjścia powercfg, niezależnie od
        języka), opcjonalnie zmiana nazwy (/changename), wpis cofnięcia i log. Cofnięcie usuwa kopię
        (Remove-MwpPowerPlan). Źródłem może być plan z listy albo ukryty szablon „Najwyższa wydajność”
        (Add-MwpUltimatePowerPlan). Nowy plan nie jest aktywowany.

    .PARAMETER Guid
        GUID planu źródłowego.

    .PARAMETER Name
        Nazwa nowego planu (bez cudzysłowów i znaków sterujących); domyślnie nazwa nadana przez Windows.

    .EXAMPLE
        Copy-MwpPowerPlan -Guid 381b4222-f694-41f0-9685-ff5bb260df2e -Name 'Mój plan'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')]
        [string] $Guid,

        [ValidatePattern('^[^"\p{Cc}]{1,128}$')]
        [string] $Name,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $Guid = $Guid.ToLowerInvariant()
    $computerName = $Context.ComputerName
    $template = (Get-MwpPowerCatalog).UltimateTemplateGuid
    $common = @{ Operation = 'Power.CopyPlan'; Target = $Guid; ComputerName = $computerName }

    $state = Read-MwpPowerState -Context $Context -Operation $common.Operation
    if (-not $state.Success) {
        return New-MwpResult @common -Success $false -Message $state.Result.Message -ErrorMessage $state.Result.ErrorMessage
    }
    $source = @($state.Status.Plans | Where-Object { $_.Guid -eq $Guid }) | Select-Object -First 1
    if ($null -eq $source -and $Guid -ne $template) {
        return New-MwpResult @common -Success $false -Message ("Na komputerze '{0}' nie ma planu zasilania {1}." -f $computerName, $Guid)
    }
    $sourceText = if ($null -ne $source) { 'planu {0}' -f (Format-MwpPowerPlanName -Plan $source) } else { 'szablonu „Najwyższa wydajność” ({0})' -f $Guid }
    $newName = if ($Name) { $Name.Trim() } else { '(nazwa nadana przez Windows)' }

    $target = Format-MwpOperationTarget -Target ('kopia {0}' -f $sourceText) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Utworzenie kopii planu o nazwie '{0}'" -f $newName))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $null -After ("nowy plan '{0}' — kopia {1}" -f $newName, $sourceText) `
            -Message ("Podgląd: nowy plan zasilania '{0}' jako kopia {1}." -f $newName, $sourceText)
    }

    $copy = Invoke-MwpPowerChange -Context $Context -Operation $common.Operation -Command @(@{ Id = 'duplicate'; Arguments = @('/duplicatescheme', $Guid) })
    $newGuid = $null
    if ($copy.Success) {
        $newGuid = @(ConvertFrom-MwpPowercfgOutput -Line (Get-MwpPowercfgCommand -Raw $copy.Raw -Id 'duplicate').Output -As Guid | Where-Object { $_ -ne $Guid }) | Select-Object -First 1
    }
    if (-not $copy.Success -or $null -eq $newGuid) {
        $reason = if ($copy.Success) { 'powercfg nie podał identyfikatora nowego planu.' } else { $copy.Message }
        if ($Guid -eq $template) {
            $reason += ' Szablon „Najwyższa wydajność” może być niedostępny na tym komputerze (np. w trybie nowoczesnego wstrzymania).'
        }
        $message = "Nie udało się utworzyć kopii {0} na komputerze '{1}': {2}" -f $sourceText, $computerName, $reason
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $copy.ErrorMessage
    }

    $renameError = $null
    if ($Name) {
        $rename = Invoke-MwpPowerChange -Context $Context -Operation $common.Operation -Command @(@{ Id = 'rename'; Arguments = @('/changename', $newGuid, $Name.Trim()) })
        if (-not $rename.Success) {
            $renameError = $rename.Message
        }
    }
    $after = "'{0}' ({1})" -f $(if ($Name -and -not $renameError) { $Name.Trim() } else { 'kopia' }), $newGuid
    $undo = Save-MwpUndoEntry -Module 'MWP.Power' -Operation $common.Operation -Target $newGuid -ComputerName $computerName `
        -Description ('Nowy plan {0} (kopia {1})' -f $after, $sourceText) -Before $null -After $after `
        -UndoCommand 'Remove-MwpPowerPlan' -UndoParameters @{ Guid = $newGuid }
    $message = "Utworzono plan zasilania {0} jako kopię {1}." -f $after, $sourceText
    if ($renameError) {
        $message += " Nie udało się nadać nazwy '{0}': {1}" -f $Name.Trim(), $renameError
    }
    Write-MwpLog -Level $(if ($renameError) { 'Warning' } else { 'Info' }) -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Source = $Guid; Guid = $newGuid }
    New-MwpResult @common -Success $true -Changed $true -Before $null -After $after -UndoId $undo.Id -Message $message -ErrorMessage $renameError `
        -Data ([ordered]@{ Guid = $newGuid; SourceGuid = $Guid })
}
