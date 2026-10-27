function Set-MwpStartupItemState {
    <#
    .SYNOPSIS
        Włącza albo wyłącza pozycję autostartu tak jak Menedżer zadań (wartość StartupApproved), bez kasowania wpisu Run ani pliku w folderze Startup.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt pozycji na komputerze docelowym, sprawdzenie, czy
        miejsce obsługuje przełączanie (RunOnce — nie), uprawnienia (pozycje komputera i profili
        innych użytkowników wymagają administratora na komputerze docelowym; własny profil — nie),
        podgląd (-WhatIf) i potwierdzenie z nazwą komputera. Zmiana: 12-bajtowa wartość
        StartupApproved (Run, Run32, StartupFolder) — włączona 02 00…, wyłączona 03 + czas
        wyłączenia (FILETIME), wyższe bity pierwszego bajtu zostają; ponowny odczyt potwierdza stan.
        Wpis cofnięcia: poprzedni stan.

    .PARAMETER Id
        Identyfikator pozycji z Get-MwpStartupItem (miejsce|SID|nazwa).

    .PARAMETER Enabled
        $true — włącz, $false — wyłącz.

    .EXAMPLE
        Set-MwpStartupItemState -Id 'UserRun|S-1-5-21-…|OneDrive' -Enabled $false -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(Machine|User)[A-Za-z0-9]+\|[^|]*\|.+$')]
        [string] $Id,

        [Parameter(Mandatory, Position = 1)]
        [bool] $Enabled,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $operation = 'Startup.SetItemState'
    $common = @{ Operation = $operation; Target = $Id; ComputerName = $computerName }
    $wantedText = if ($Enabled) { 'Włączony' } else { 'Wyłączony' }

    $read = Invoke-MwpStartupRead -Context $Context -Operation $operation -Kind Item -NoSignature
    if (-not $read.Success) {
        return New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
    }
    $list = Resolve-MwpStartupItemList -Data $read.Raw
    $item = @($list.Items | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if ($null -eq $item) {
        return New-MwpResult @common -Success $false -Message ("Na komputerze '{0}' nie ma pozycji autostartu '{1}' (odśwież listę)." -f $computerName, $Id)
    }
    $common.Target = '{0} ({1})' -f $item.Name, $item.LocationText
    if (-not $item.CanToggle) {
        return New-MwpResult @common -Success $false -Before $item.StateText `
            -Message ("Pozycji '{0}' ({1}) nie można włączać ani wyłączać — wpisy RunOnce uruchamiają się jednorazowo i Menedżer zadań ich nie obsługuje." -f $item.Name, $item.LocationText)
    }
    if ($item.Enabled -eq $Enabled) {
        return New-MwpResult @common -Success $true -Before $item.StateText -After $item.StateText -Message ("Pozycja autostartu '{0}' jest już w stanie: {1}." -f $item.Name, $item.StateText)
    }

    $needsAdmin = $item.Scope -eq 'Machine' -or $item.UserSid -ne $list.CurrentUserSid
    if ($needsAdmin) {
        $admin = Test-MwpStartupAdmin -Context $Context
        if (-not $admin.Success) {
            return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
        }
        if (-not $admin.IsAdministrator) {
            $whose = if ($item.Scope -eq 'Machine') { 'wszystkich użytkowników' } else { 'innego użytkownika ({0})' -f $item.UserName }
            return New-MwpResult @common -Success $false -Before $item.StateText `
                -Message ("Zmiana pozycji autostartu {0} wymaga uprawnień administratora na komputerze '{1}'." -f $whose, $computerName)
        }
    }

    $target = Format-MwpOperationTarget -Target ("pozycja autostartu '{0}' ({1}, {2})" -f $item.Name, $item.LocationText, $item.UserName) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Stan: '{0}' → '{1}' (StartupApproved, wpis zostaje)" -f $item.StateText, $wantedText))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $item.StateText -After $wantedText `
            -Message ("Podgląd: pozycja autostartu '{0}' ({1}): {2} → {3}. Wpis nie jest kasowany." -f $item.Name, $item.LocationText, $item.StateText, $wantedText)
    }

    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            Location = $item.Location
            UserSid  = [string]$item.UserSid
            Name     = $item.Name
            Enabled  = $Enabled
        })
    $change = Invoke-MwpOnTarget -Context $Context -Operation $operation -ScriptBlock (Get-MwpStartupScript -Name ItemState) -ArgumentList @($request)
    $raw = if ($change.Success) { ConvertFrom-MwpStartupJson -Data $change -Kind 'MWP.StartupItemChange' } else { $null }
    $failure = $null
    $actual = $null
    if (-not $change.Success) {
        $failure = $change.Message
    }
    elseif ($null -eq $raw) {
        $failure = 'komputer nie zwrócił wyniku zmiany'
    }
    else {
        if ($raw.After -match '^[0-9A-Fa-f]{2}') {
            $actual = ([Convert]::ToByte($raw.After.Substring(0, 2), 16) -band 1) -eq 0
        }
        if ($raw.Error) {
            $failure = $raw.Error
        }
        elseif ($actual -ne $Enabled) {
            $failure = 'po zmianie wartość StartupApproved nie potwierdza stanu ({0})' -f $raw.After
        }
    }

    $undoId = $null
    if ($null -ne $actual -and $actual -ne $item.Enabled) {
        $actualText = if ($actual) { 'Włączony' } else { 'Wyłączony' }
        $undo = Save-MwpUndoEntry -Module 'MWP.Startup' -Operation $operation -Target $item.Id -ComputerName $computerName `
            -Description ("Autostart '{0}' ({1}): {2} → {3}" -f $item.Name, $item.LocationText, $item.StateText, $actualText) -Before $item.StateText -After $actualText `
            -UndoCommand 'Set-MwpStartupItemState' -UndoParameters @{ Id = $item.Id; Enabled = [bool]$item.Enabled }
        $undoId = $undo.Id
    }
    $data = @{ Id = $item.Id; Before = $(if ($null -ne $raw) { $raw.Before } else { $null }); After = $(if ($null -ne $raw) { $raw.After } else { $null }) }
    if ($null -ne $failure) {
        $message = "Nie udało się zmienić stanu pozycji autostartu '{0}' na komputerze '{1}': {2}" -f $item.Name, $computerName, $failure
        Write-MwpLog -Level Error -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data $data
        return New-MwpResult @common -Success $false -Changed ($null -ne $undoId) -Before $item.StateText -UndoId $undoId -Message $message `
            -ErrorMessage $(if ($null -ne $raw) { [string]$raw.Error } else { $change.ErrorMessage })
    }
    $message = "Pozycja autostartu '{0}' ({1}) na komputerze '{2}': {3} → {4}." -f $item.Name, $item.LocationText, $computerName, $item.StateText, $wantedText
    Write-MwpLog -Level Info -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data $data
    New-MwpResult @common -Success $true -Changed $true -Before $item.StateText -After $wantedText -UndoId $undoId -Message $message
}
