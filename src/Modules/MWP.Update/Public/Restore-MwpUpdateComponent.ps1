function Restore-MwpUpdateComponent {
    <#
    .SYNOPSIS
        Przywraca foldery SoftwareDistribution i catroot2 z kopii po resecie (polecenie cofające Reset-MwpUpdateComponent).

    .DESCRIPTION
        Operacja klasy Zmiana: zatrzymuje usługi Windows Update, zmienia nazwy bieżących folderów na
        <nazwa>.mwp-replaced-RRRRMMDD-GGmmss (nie są usuwane), przywraca kopie <nazwa>.<sufiks> pod
        dawną nazwą i uruchamia ponownie usługi, które działały. Folder bez kopii jest pomijany.
        Wymaga administratora na komputerze docelowym; podgląd (-WhatIf) wymienia kroki; potwierdzenie
        z nazwą komputera. Nie tworzy nowego wpisu cofnięcia (bieżące foldery zostają pod nową nazwą).

    .PARAMETER Suffix
        Sufiks kopii z resetu (mwp-RRRRMMDD-GGmmss).

    .EXAMPLE
        Restore-MwpUpdateComponent -Suffix 'mwp-20261028-120000' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^mwp-\d{8}-\d{6}$')]
        [string] $Suffix,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Update.RestoreComponents'
    $computerName = $Context.ComputerName
    $common = @{ Operation = $operation; Target = 'Windows Update'; ComputerName = $computerName }
    $admin = Test-MwpUpdateAdmin -Context $Context
    if (-not $admin.Success) {
        return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
    }
    if (-not $admin.IsAdministrator) {
        return New-MwpResult @common -Success $false -Message ("Przywrócenie składników Windows Update wymaga uprawnień administratora na komputerze '{0}'." -f $computerName)
    }
    $replaced = 'mwp-replaced-{0:yyyyMMdd-HHmmss}' -f (Get-Date)
    $plan = @(Get-MwpUpdateResetStep -Suffix $Suffix -Restore -ReplacedSuffix $replaced | ForEach-Object { '{0}. {1}' -f $_.Index, $_.Text }) -join [Environment]::NewLine
    $target = Format-MwpOperationTarget -Target ('składniki Windows Update (kopie *.{0})' -f $Suffix) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Przywrócenie folderów z kopii:{0}{1}' -f [Environment]::NewLine, $plan))) {
        return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd: przywrócenie składników Windows Update z kopii {0} na komputerze '{1}' — kroki:{2}{3}" -f $Suffix, $computerName, [Environment]::NewLine, $plan)
    }
    $run = Invoke-MwpUpdateReset -Context $Context -Operation $operation -Mode Restore -Suffix $Suffix -ReplacedSuffix $replaced
    if (-not $run.Success) {
        Write-MwpLog -Level Error -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $run.Result.Message
        return New-MwpResult @common -Success $false -Message $run.Result.Message -ErrorMessage $run.Result.ErrorMessage
    }
    $raw = $run.Raw
    $renamed = @($raw.Renamed | Where-Object { $null -ne $_ })
    $restored = @($renamed | Where-Object { [string]$_.From -like ('*.' + $Suffix) })
    $stepText = @($raw.Steps | Where-Object { $null -ne $_ } | ForEach-Object { '{0} {1}: {2}' -f $_.Step, $_.Target, $_.Message }) -join [Environment]::NewLine
    if ($raw.Error) {
        $message = "Przywrócenie składników Windows Update z kopii {0} na komputerze '{1}' nie powiodło się: {2}" -f $Suffix, $computerName, $raw.Error
        Write-MwpLog -Level Error -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Steps = $stepText }
        return New-MwpResult @common -Success $false -Changed ($renamed.Count -gt 0) -Message $message -ErrorMessage $stepText -Data $raw
    }
    if ($restored.Count -eq 0) {
        $message = "Na komputerze '{0}' nie ma kopii folderów z sufiksem {1} — nic nie przywrócono." -f $computerName, $Suffix
        Write-MwpLog -Level Warning -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Steps = $stepText }
        return New-MwpResult @common -Success $false -Message $message -Data $raw
    }
    $message = "Przywrócono z kopii {0} na komputerze '{1}': {2} (bieżące foldery: *.{3})." -f $Suffix, $computerName, (@($restored | ForEach-Object { $_.Folder }) -join ', '), $replaced
    Write-MwpLog -Level Info -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Steps = $stepText }
    New-MwpResult @common -Success $true -Changed $true -Before ('*.{0}' -f $Suffix) -After 'SoftwareDistribution, catroot2' -Message $message -Data $raw
}
