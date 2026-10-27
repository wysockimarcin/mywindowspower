function Start-MwpService {
    <#
    .SYNOPSIS
        Uruchamia usługę na komputerze docelowym (opcjonalnie także wskazane usługi zależne, np. przy cofnięciu zatrzymania).

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt stanu, sprawdzenie uprawnień administratora na
        komputerze docelowym, podgląd (-WhatIf) i potwierdzenie z nazwą komputera, uruchomienie
        (usługi wymagane uruchamia Menedżer sterowania usługami), log i wpis cofnięcia
        (Stop-MwpService). Uruchomienie usługi z listy ochronnej jest dozwolone (D-045), ale bez wpisu
        cofnięcia, bo jej zatrzymanie jest zablokowane. Usługi wyłączonej nie da się uruchomić —
        najpierw zmień typ uruchomienia.

    .PARAMETER Name
        Nazwa usługi (nie nazwa wyświetlana).

    .PARAMETER DependentService
        Usługi zależne uruchamiane po usłudze, w podanej kolejności (te, które zatrzymał Stop-MwpService).

    .EXAMPLE
        Start-MwpService -Name Spooler -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ Test-MwpServiceName -Name $_ })]
        [string] $Name,

        [ValidateScript({ Test-MwpServiceName -Name $_ })]
        [string[]] $DependentService = @(),

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $common = @{ Operation = 'Services.Start'; Target = $Name; ComputerName = $computerName }

    $state = Read-MwpServiceState -Context $Context -Operation $common.Operation -Target $Name -Name (@($Name) + @($DependentService))
    if (-not $state.Success) {
        return $state.Result
    }
    $service = $state.Service
    $common.Target = $service.Name
    if ($service.StartupType -eq 'Disabled') {
        return New-MwpResult @common -Success $false -Before $service.StatusText -Message ("Usługa '{0}' jest wyłączona — najpierw zmień typ uruchomienia." -f $service.DisplayName)
    }
    $toStart = New-Object -TypeName System.Collections.Generic.List[string]
    $notes = New-Object -TypeName System.Collections.Generic.List[string]
    if ($service.Status -ne 'Running') {
        $toStart.Add($service.Name)
    }
    foreach ($dependentName in $DependentService) {
        $dependent = @($state.List.Services | Where-Object { $_.Name -eq $dependentName }) | Select-Object -First 1
        if ($null -eq $dependent) {
            $notes.Add(("usługi zależnej '{0}' nie ma — pominięta" -f $dependentName))
        }
        elseif ($dependent.StartupType -eq 'Disabled') {
            $notes.Add(("usługa zależna '{0}' jest wyłączona — pominięta" -f $dependent.Name))
        }
        elseif ($dependent.Status -ne 'Running' -and -not $toStart.Contains($dependent.Name)) {
            $toStart.Add($dependent.Name)
        }
    }
    $noteText = if ($notes.Count -gt 0) { ' Uwaga: {0}.' -f ($notes -join '; ') } else { '' }
    if ($toStart.Count -eq 0) {
        return New-MwpResult @common -Success $true -Before $service.StatusText -After $service.StatusText -Message ("Usługa '{0}' już działa.{1}" -f $service.DisplayName, $noteText)
    }

    $admin = Test-MwpServiceAdmin -Context $Context
    if (-not $admin.Success) {
        return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
    }
    if (-not $admin.IsAdministrator) {
        return New-MwpResult @common -Success $false -Message ("Uruchamianie usług wymaga uprawnień administratora na komputerze '{0}'." -f $computerName)
    }

    $list = $toStart -join ', '
    $target = Format-MwpOperationTarget -Target ("usługa '{0}' ({1})" -f $service.DisplayName, $service.Name) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Uruchomienie: {0}' -f $list))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $service.StatusText -After 'Działa' -Message ("Podgląd: uruchomienie {0}.{1}" -f $list, $noteText)
    }

    $steps = @(foreach ($item in $toStart) { @{ Name = $item; Action = 'Start' } })
    $change = Invoke-MwpServiceControl -Context $Context -Operation $common.Operation -Step $steps
    if (-not $change.Success) {
        $message = "Nie udało się uruchomić usług na komputerze '{0}': {1}" -f $computerName, $change.Message
        Write-MwpLog -Level Error -Source 'MWP.Services' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Services = $toStart.ToArray() }
        return New-MwpResult @common -Success $false -Before $service.StatusText -Message $message -ErrorMessage $change.ErrorMessage
    }
    $undoId = $null
    $undoNote = ''
    if ($service.Status -eq 'Running') {
        $undoNote = ' Bez wpisu cofnięcia (usługa działała już wcześniej).'
    }
    elseif ($service.IsProtected) {
        $undoNote = ' Bez wpisu cofnięcia (usługa chroniona — zatrzymanie jest zablokowane).'
    }
    else {
        $undo = Save-MwpUndoEntry -Module 'MWP.Services' -Operation $common.Operation -Target $service.Name -ComputerName $computerName `
            -Description ("Uruchomienie usługi '{0}'" -f $service.DisplayName) -Before $service.StatusText -After 'Działa' `
            -UndoCommand 'Stop-MwpService' -UndoParameters @{ Name = $service.Name }
        $undoId = $undo.Id
    }
    $message = "Uruchomiono na komputerze '{0}': {1}.{2}{3}" -f $computerName, $list, $noteText, $undoNote
    Write-MwpLog -Level Info -Source 'MWP.Services' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Services = $toStart.ToArray() }
    New-MwpResult @common -Success $true -Changed $true -Before $service.StatusText -After 'Działa' -UndoId $undoId -Message $message
}
