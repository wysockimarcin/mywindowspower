function Reset-MwpUpdateComponent {
    <#
    .SYNOPSIS
        Resetuje składniki Windows Update na komputerze docelowym: zatrzymuje usługi, zmienia nazwy SoftwareDistribution i catroot2 (stare foldery zostają) i uruchamia usługi ponownie.

    .DESCRIPTION
        Operacja klasy Destrukcyjna (D-027, D-048): ConfirmImpact High — bez -Confirm:$false funkcja
        zawsze pyta; podgląd (-WhatIf) wymienia wszystkie kroki (Get-MwpUpdateResetStep) z nazwą
        komputera. Wymaga administratora na komputerze docelowym (sprawdzane przed podglądem).
        Foldery dostają sufiks mwp-RRRRMMDD-GGmmss i nie są usuwane, więc reset jest odwracalny:
        wpis cofnięcia wywołuje Restore-MwpUpdateComponent z tym sufiksem. Błąd zatrzymania usługi
        wymaganej przerywa reset przed zmianą folderów; błąd zmiany nazwy wycofuje wcześniejsze
        zmiany nazw; usługi, które działały, są zawsze uruchamiane ponownie. Historia aktualizacji
        (DataStore w SoftwareDistribution) po resecie jest pusta do czasu przywrócenia kopii.
        Działa także na komputerze zdalnym (WinRM).

    .EXAMPLE
        Reset-MwpUpdateComponent -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Update.ResetComponents'
    $computerName = $Context.ComputerName
    $common = @{ Operation = $operation; Target = 'Windows Update'; ComputerName = $computerName }
    $admin = Test-MwpUpdateAdmin -Context $Context
    if (-not $admin.Success) {
        return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
    }
    if (-not $admin.IsAdministrator) {
        return New-MwpResult @common -Success $false -Message ("Reset składników Windows Update wymaga uprawnień administratora na komputerze '{0}'." -f $computerName)
    }
    $suffix = 'mwp-{0:yyyyMMdd-HHmmss}' -f (Get-Date)
    $steps = @(Get-MwpUpdateResetStep -Suffix $suffix)
    $plan = @($steps | ForEach-Object { '{0}. {1}' -f $_.Index, $_.Text }) -join [Environment]::NewLine
    $target = Format-MwpOperationTarget -Target 'składniki Windows Update (usługi, SoftwareDistribution, catroot2)' -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Reset składników Windows Update:{0}{1}' -f [Environment]::NewLine, $plan))) {
        return New-MwpResult @common -Success $true -IsPreview -Data $steps `
            -Message ("Podgląd: reset składników Windows Update na komputerze '{0}' — kroki:{1}{2}" -f $computerName, [Environment]::NewLine, $plan)
    }

    Write-MwpLog -Level Info -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message ("Reset składników Windows Update: start (sufiks kopii {0})." -f $suffix)
    $run = Invoke-MwpUpdateReset -Context $Context -Operation $operation -Mode Reset -Suffix $suffix
    if (-not $run.Success) {
        Write-MwpLog -Level Error -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $run.Result.Message
        return New-MwpResult @common -Success $false -Message $run.Result.Message -ErrorMessage $run.Result.ErrorMessage
    }
    $raw = $run.Raw
    $renamed = @($raw.Renamed | Where-Object { $null -ne $_ })
    $failedStarts = @($raw.Steps | Where-Object { $null -ne $_ -and $_.Step -eq 'Start' -and -not $_.Success })
    $undoId = $null
    if ($renamed.Count -gt 0) {
        $undo = Save-MwpUndoEntry -Module 'MWP.Update' -Operation $operation -Target 'Windows Update' -ComputerName $computerName `
            -Description ('Reset składników Windows Update (kopie *.{0})' -f $suffix) -Before 'SoftwareDistribution, catroot2' -After ('*.{0}' -f $suffix) `
            -UndoCommand 'Restore-MwpUpdateComponent' -UndoParameters @{ Suffix = $suffix }
        $undoId = $undo.Id
    }
    $stepText = @($raw.Steps | Where-Object { $null -ne $_ } | ForEach-Object { '{0} {1}: {2}' -f $_.Step, $_.Target, $_.Message }) -join [Environment]::NewLine
    if ($raw.Error) {
        $message = "Reset składników Windows Update na komputerze '{0}' nie powiódł się: {1}{2}" -f $computerName, $raw.Error, $(if ($renamed.Count -eq 0) { ' Foldery nie zostały zmienione.' } else { '' })
        Write-MwpLog -Level Error -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Steps = $stepText }
        return New-MwpResult @common -Success $false -Changed ($renamed.Count -gt 0) -UndoId $undoId -Message $message -ErrorMessage $stepText -Data $raw
    }
    $message = "Zresetowano składniki Windows Update na komputerze '{0}': {1} (kopie z sufiksem {2})." -f $computerName, $(if ($renamed.Count -gt 0) { @($renamed | ForEach-Object { $_.Folder }) -join ', ' } else { 'brak folderów do zmiany' }), $suffix
    if ($failedStarts.Count -gt 0) {
        $message = '{0} Nie uruchomiono ponownie: {1}.' -f $message, (@($failedStarts | ForEach-Object { $_.Target }) -join ', ')
    }
    Write-MwpLog -Level $(if ($failedStarts.Count -gt 0) { 'Warning' } else { 'Info' }) -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Steps = $stepText }
    New-MwpResult @common -Success $true -Changed ($renamed.Count -gt 0) -Before 'SoftwareDistribution, catroot2' -After ('*.{0}' -f $suffix) -UndoId $undoId -Message $message -Data $raw
}
