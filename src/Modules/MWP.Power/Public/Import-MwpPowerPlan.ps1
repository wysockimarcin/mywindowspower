function Import-MwpPowerPlan {
    <#
    .SYNOPSIS
        Importuje plan zasilania z pliku .pow na komputer docelowy (powercfg /import) — także jako cofnięcie usunięcia planu.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027). Treść pliku przychodzi jako Base64 (-Content; tak zapisuje ją
        Remove-MwpPowerPlan w rejestrze cofnięć) albo z lokalnego pliku (-Path, do 1 MB). Plik jest
        zapisywany w katalogu tymczasowym komputera docelowego, importowany i usuwany. Plan dostaje
        podany GUID (domyślnie nowy). Odmawia, gdy plan o tym GUID już istnieje. Cofnięcie usuwa
        zaimportowany plan (Remove-MwpPowerPlan).

    .PARAMETER Content
        Treść pliku .pow w Base64.

    .PARAMETER Path
        Lokalny plik .pow (komputer, na którym działa host).

    .PARAMETER Guid
        GUID importowanego planu; domyślnie nowy.

    .EXAMPLE
        Import-MwpPowerPlan -Path .\moj-plan.pow -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Content')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [ValidateNotNullOrEmpty()]
        [string] $Content,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [ValidatePattern('^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')]
        [string] $Guid = ([guid]::NewGuid().ToString()),

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $Guid = $Guid.ToLowerInvariant()
    $computerName = $Context.ComputerName
    $common = @{ Operation = 'Power.ImportPlan'; Target = $Guid; ComputerName = $computerName }

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        try {
            $full = [IO.Path]::GetFullPath($Path)
            $info = New-Object -TypeName IO.FileInfo -ArgumentList $full
            if (-not $info.Exists) {
                return New-MwpResult @common -Success $false -Message ("Plik '{0}' nie istnieje." -f $full)
            }
            if ($info.Length -gt 1MB) {
                return New-MwpResult @common -Success $false -Message ("Plik '{0}' jest za duży na plan zasilania (ponad 1 MB)." -f $full)
            }
            $Content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($full))
        }
        catch {
            return New-MwpResult @common -Success $false -Message ("Nie udało się odczytać pliku '{0}': {1}" -f $Path, $_.Exception.Message) -ErrorMessage $_.Exception.Message
        }
    }
    else {
        try {
            $null = [Convert]::FromBase64String($Content)
        }
        catch {
            return New-MwpResult @common -Success $false -Message 'Treść planu nie jest poprawnym tekstem Base64.' -ErrorMessage $_.Exception.Message
        }
    }

    $state = Read-MwpPowerState -Context $Context -Operation $common.Operation
    if (-not $state.Success) {
        return New-MwpResult @common -Success $false -Message $state.Result.Message -ErrorMessage $state.Result.ErrorMessage
    }
    $existing = @($state.Status.Plans | Where-Object { $_.Guid -eq $Guid }) | Select-Object -First 1
    if ($null -ne $existing) {
        return New-MwpResult @common -Success $false -Message ("Plan {0} już istnieje na komputerze '{1}'." -f (Format-MwpPowerPlanName -Plan $existing), $computerName)
    }

    $target = Format-MwpOperationTarget -Target ('plan zasilania {0}' -f $Guid) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, 'Import planu z pliku .pow')) {
        return New-MwpResult @common -Success $true -IsPreview -Before '(brak)' -After ('plan {0}' -f $Guid) -Message ("Podgląd: import planu zasilania {0}." -f $Guid)
    }

    $import = Invoke-MwpOnTarget -Context $Context -Operation $common.Operation -ScriptBlock (Get-MwpPowerScript -Name ImportPlan) -ArgumentList @($Guid, $Content)
    $file = if ($import.Success) { ConvertFrom-MwpPowerJson -Data $import -Kind 'MWP.PowerFile' }
    if ($null -eq $file -or [int]$file.ExitCode -ne 0) {
        $reason = if (-not $import.Success) { $import.Message } elseif ($null -eq $file) { 'brak wyniku importu.' } else { 'powercfg /import zakończył się kodem {0}: {1}' -f $file.ExitCode, (@($file.Output) -join ' ') }
        $message = "Nie udało się zaimportować planu {0} na komputerze '{1}': {2}" -f $Guid, $computerName, $reason
        Write-MwpLog -Level Error -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $import.ErrorMessage
    }

    $after = 'plan {0}' -f $Guid
    $list = Get-MwpPowerPlan -Context $Context -Guid $Guid
    $plan = if ($list.Success) { @($list.Data) | Select-Object -First 1 }
    if ($null -ne $plan) {
        $after = Format-MwpPowerPlanName -Plan $plan
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Power' -Operation $common.Operation -Target $Guid -ComputerName $computerName `
        -Description ('Zaimportowany plan {0}' -f $after) -Before '(brak)' -After $after `
        -UndoCommand 'Remove-MwpPowerPlan' -UndoParameters @{ Guid = $Guid }
    $message = "Zaimportowano plan zasilania {0} na komputerze '{1}'." -f $after, $computerName
    Write-MwpLog -Level Info -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
    New-MwpResult @common -Success $true -Changed $true -Before '(brak)' -After $after -UndoId $undo.Id -Message $message -Data ([ordered]@{ Guid = $Guid })
}
