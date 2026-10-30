function Invoke-MwpUiInstanceChange {
    <#
    .SYNOPSIS
        Zmiana systemu z widoku modułu: podgląd w tle (-WhatIf), okno potwierdzenia z komputerem docelowym, wykonanie w tle, odświeżenie widoku.

    .DESCRIPTION
        Wzorzec zmian z GUI (D-039) dla widoków modułów (D-044): kroki { Command; Parameters; Label }
        to funkcje logiki modułu, wykonywane z kontekstem instancji w puli zadań GUI
        (Get-MwpUiChangeScript), więc okno nie czeka na powercfg ani na komputer zdalny. Najpierw
        wszystkie kroki z -WhatIf; okno potwierdzenia pokazuje „Podgląd zmian” (ConvertTo-MwpPreviewLine)
        i komputer docelowy; kroki, których podgląd odmówił albo nic nie zmienia, są pomijane.
        Po potwierdzeniu kroki wykonują się z -Confirm:$false (log i wpisy cofnięcia tworzą funkcje
        logiki); niepowodzenia trafiają do okna komunikatu, a po wszystkim wywoływane jest
        -AfterCommand -Entry (np. ponowny odczyt stanu). Błąd jednej instancji nie wpływa na inne.

    .PARAMETER Steps
        Kroki zmian.

    .PARAMETER Class
        Change albo Destructive (okno potwierdzenia, D-027).

    .PARAMETER RequireText
        Tekst do wpisania przed potwierdzeniem (operacja destrukcyjna).

    .PARAMETER AfterCommand
        Funkcja okna wywoływana z -Entry po wykonaniu (np. Start-MwpUiPowerRefresh).

    .PARAMETER ConfirmText
        Napis przycisku potwierdzenia; domyślnie „Wykonaj”, dla operacji destrukcyjnej „Usuń”.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Podgląd i potwierdzenie zapewnia okno potwierdzenia i funkcje logiki (-WhatIf).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Steps,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Header,

        [ValidateSet('Change', 'Destructive')]
        [string] $Class = 'Change',

        [AllowEmptyString()]
        [string] $Target = '',

        [AllowEmptyString()]
        [string] $RequireText = '',

        [AllowEmptyString()]
        [string] $AfterCommand = '',

        [AllowEmptyString()]
        [string] $ConfirmText = '',

        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    $context = $Entry.Instance.Context
    if ($Steps.Count -eq 0) {
        Show-MwpMessage -Text 'Brak zmian do wykonania.' -Owner $Owner
        return
    }
    $state = Get-MwpConnectionStateInfo -Context $context
    if ($state.NeedsCredential) {
        Show-MwpMessage -Text ('Najpierw połącz instancję z komputerem {0} (przycisk „Połącz”), żeby podać poświadczenia.' -f (Format-MwpTargetLabel -Context $context)) -Owner $Owner
        return
    }
    $module = @(Get-Module -Name $Entry.Instance.ModuleName) | Select-Object -First 1
    $data = @{
        InstanceId   = $Entry.Id
        Steps        = @($Steps)
        Header       = $Header
        Class        = $Class
        Target       = $Target
        RequireText  = $RequireText
        AfterCommand = $AfterCommand
        ConfirmText  = $(if ($ConfirmText) { $ConfirmText } elseif ($Class -eq 'Destructive') { 'Usuń' } else { 'Wykonaj' })
        ModulePath   = $(if ($null -ne $module) { $module.Path } else { '' })
        Owner        = $Owner
    }
    $Entry.Busy++
    Update-MwpInstanceView -Entry $Entry -StateOnly
    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Podgląd: {0} ({1})' -f $Header, (Format-MwpTargetLabel -Context $context)) -State $data -Cancellable `
        -ArgumentList $data.ModulePath, $context, $data.Steps, $true -ScriptBlock (Get-MwpUiChangeScript) -OnCompleted {
        param($Task)
        $data = $Task.State
        $entry = $script:MwpUi.Instances[[string]$data.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Busy = [Math]::Max(0, $entry.Busy - 1)
        Update-MwpInstanceView -Entry $entry -StateOnly
        if ($Task.Status -ne 'Completed') {
            if ($Task.Status -ne 'Cancelled') {
                Show-MwpMessage -Text ('Podgląd zmian nie powiódł się: {0}' -f $Task.Error) -Kind Warning -Owner $data.Owner
            }
            return
        }
        $lines = New-Object -TypeName System.Collections.Generic.List[string]
        $apply = New-Object -TypeName System.Collections.Generic.List[object]
        foreach ($item in @($Task.Output | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties['Index'] })) {
            $step = $data.Steps[[int]$item.Index]
            if ($null -eq $item.Result) {
                $lines.Add(('{0}: brak wyniku podglądu.' -f $step.Label))
                continue
            }
            foreach ($line in @(ConvertTo-MwpPreviewLine -Result $item.Result)) {
                if ($line -notlike 'Komputer:*') {
                    $lines.Add($line)
                }
            }
            if ($item.Result.Success -and $item.Result.IsPreview) {
                $apply.Add($step)
            }
        }
        $computerName = $entry.Instance.Context.ComputerName
        if ($apply.Count -eq 0) {
            Show-MwpMessage -Text ("Nic do zmiany na komputerze {0}:{1}{2}" -f $computerName, [Environment]::NewLine, ($lines -join [Environment]::NewLine)) -Kind Warning -Owner $data.Owner
            return
        }
        $warning = if ($apply.Count -lt $data.Steps.Count) { 'Część pozycji zostanie pominięta (bez zmian albo odmowa — patrz podgląd).' } else { '' }
        $confirmed = Show-MwpConfirmDialog -Header $data.Header -Target $data.Target -ComputerName $computerName -PreviewLine $lines.ToArray() `
            -Class $data.Class -RequireText $data.RequireText -Warning $warning -ConfirmText $data.ConfirmText -Owner $data.Owner
        if (-not $confirmed) {
            return
        }
        $entry.Busy++
        Update-MwpInstanceView -Entry $entry -StateOnly
        $null = Start-MwpUiTask -Registry $script:MwpUi.Tasks -Pool $script:MwpUi.Pool -Name ('{0} ({1})' -f $data.Header, $computerName) -State $data `
            -ArgumentList $data.ModulePath, $entry.Instance.Context, $apply.ToArray(), $false -ScriptBlock (Get-MwpUiChangeScript) -OnCompleted {
            param($Task)
            $data = $Task.State
            $entry = $script:MwpUi.Instances[[string]$data.InstanceId]
            if ($null -eq $entry) {
                return
            }
            $entry.Busy = [Math]::Max(0, $entry.Busy - 1)
            $failed = @($Task.Output | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties['Result'] -and ($null -eq $_.Result -or -not $_.Result.Success) })
            if ($Task.Status -ne 'Completed') {
                Show-MwpMessage -Text ('{0}: zadanie nie powiodło się ({1}): {2}' -f $data.Header, $Task.Status, $Task.Error) -Kind Warning -Owner $data.Owner
            }
            elseif ($failed.Count -gt 0) {
                $text = @($failed | ForEach-Object { if ($null -ne $_.Result) { $_.Result.Message } else { 'brak wyniku' } }) -join [Environment]::NewLine
                Show-MwpMessage -Text ("{0}: nie wszystkie zmiany się udały:{1}{2}" -f $data.Header, [Environment]::NewLine, $text) -Kind Warning -Owner $data.Owner
            }
            if ($data.AfterCommand) {
                & $data.AfterCommand -Entry $entry
            }
            Update-MwpInstanceView -Entry $entry
        }
    }
}
