function Uninstall-MwpApp {
    <#
    .SYNOPSIS
        Odinstalowuje aplikację z komputera docelowego: program z rejestru przez winget, pakiet Appx przez Remove-AppxPackage.

    .DESCRIPTION
        Operacja klasy Destrukcyjna (D-027, D-050): ConfirmImpact High — bez -Confirm:$false funkcja
        zawsze pyta; potwierdzenie i podgląd zawierają nazwę, wersję, wydawcę i komputer.
        Przed podglądem (odmowa = wynik z błędem):
        - lista ochronna i składniki systemu (Get-MwpAppProtection: Appx systemowe, struktury, zasobów,
          nieusuwalne; SystemComponent, NoRemove, aktualizacje; kategorie App i AppxPackage) — także
          z CLI i na komputerze zdalnym;
        - komputer zdalny: administrator na komputerze docelowym; programy profilu innego użytkownika
          nie są odinstalowywane (winget i Appx działają w profilu konta połączenia).
        Sposób: program z rejestru — winget uninstall --id <ARP\…> --exact --silent (identyfikator lokalny
        z klucza Uninstall); pakiet z -WingetId — winget uninstall --id <Id> --exact --silent; Appx —
        Remove-AppxPackage (konto sesji). Lokalnie bez administratora instalator może pokazać monit UAC.
        Log na hoście: nazwa, wersja, wydawca, identyfikatory (przed i po). Sprawdzenie: ponowny odczyt
        inwentarza. Cofnięcie (wpis tylko, gdy pakiet ma identyfikator w repozytorium winget):
        Install-MwpWingetPackage -Id — ponowna instalacja najnowszej wersji.

    .PARAMETER AppId
        Identyfikator aplikacji z Get-MwpInstalledApp (Registry:… albo Appx:…).

    .PARAMETER WingetId
        Identyfikator pakietu winget (źródła albo lokalny ARP\…, MSIX\…).

    .EXAMPLE
        Uninstall-MwpApp -WingetId '7zip.7zip' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'App')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'App')]
        [ValidatePattern('^(Registry|Appx):')]
        [string] $AppId,

        [Parameter(Mandatory, ParameterSetName = 'Winget')]
        [ValidateNotNullOrEmpty()]
        [string] $WingetId,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Apps.Uninstall'
    $computerName = $Context.ComputerName
    $label = if ($PSCmdlet.ParameterSetName -eq 'App') { $AppId } else { $WingetId }
    $common = @{ Operation = $operation; Target = $label; ComputerName = $computerName }
    if ($PSCmdlet.ParameterSetName -eq 'Winget' -and -not (Test-MwpWingetId -Id $WingetId -AllowLocal)) {
        throw ("Niepoprawny identyfikator pakietu winget: '{0}'." -f $WingetId)
    }
    $found = Get-MwpAppTarget -Context $Context -AppId $(if ($AppId) { $AppId } else { '' }) -WingetId $(if ($WingetId) { $WingetId } else { '' })
    if (-not $found.Success) {
        $errorMessage = if ($null -ne $found.Result) { $found.Result.ErrorMessage } else { $null }
        return New-MwpResult @common -Success $false -Message $found.Message -ErrorMessage $errorMessage
    }
    $app = $found.App
    $describe = "'{0}' {1}{2}" -f $app.Name, $(if ($app.Version) { 'w wersji ' + $app.Version } else { '' }), $(if ($app.Publisher) { " ($($app.Publisher))" } else { '' })
    $common.Target = $app.Name
    if ($app.IsProtected) {
        return New-MwpResult @common -Success $false -Message ("Aplikacja {0} jest chroniona i nie można jej odinstalować z aplikacji: {1}" -f $describe, $app.ProtectedReason)
    }
    $remote = $Context.Mode -eq 'Remote'
    if ($remote) {
        $admin = Test-MwpAppsAdmin -Context $Context
        if (-not $admin.Success) {
            return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
        }
        if (-not $admin.IsAdministrator) {
            return New-MwpResult @common -Success $false -Message ("Odinstalowanie na komputerze zdalnym '{0}' wymaga konta administratora w połączeniu." -f $computerName)
        }
    }
    if ($app.Scope -eq 'User' -and $app.UserSid -and $app.UserSid -ne $found.Inventory.CurrentUserSid) {
        return New-MwpResult @common -Success $false -Message ("Aplikacja {0} należy do profilu {1}; aplikacja odinstalowuje tylko programy komputera i konta połączenia ({2})." -f $describe, $app.UserName, $found.Inventory.CurrentUser)
    }
    $method = [string]$app.UninstallMethod
    $uninstallId = if ($PSCmdlet.ParameterSetName -eq 'Winget') { $WingetId } elseif ($app.Source -eq 'Registry') { [string]$app.WingetLocalId } else { '' }
    if ($method -eq 'Winget') {
        if (-not $found.WingetOk) {
            return New-MwpResult @common -Success $false -Message ("Nie można odinstalować {0}: {1}" -f $describe, $found.Message)
        }
        if (-not (Test-MwpWingetId -Id $uninstallId -AllowLocal)) {
            return New-MwpResult @common -Success $false -Message ("Nie można odinstalować {0}: klucz rejestru '{1}' nie daje poprawnego identyfikatora winget." -f $describe, $app.KeyName)
        }
    }
    $sourceId = if ($app.WingetId -and (Test-MwpWingetId -Id ([string]$app.WingetId))) { [string]$app.WingetId } else { '' }
    $notes = @()
    if ($method -eq 'Appx') {
        $notes += 'Sposób: Remove-AppxPackage (pakiet konta {0}).' -f $found.Inventory.CurrentUser
    }
    else {
        $notes += 'Sposób: winget uninstall --id {0} --exact --silent.' -f $uninstallId
        if (-not $remote -and $app.Scope -eq 'Machine' -and -not $found.Inventory.IsAdministrator) {
            $notes += 'Program jest zainstalowany dla całego komputera — instalator może pokazać monit UAC.'
        }
    }
    if ($app.Warning) {
        $notes += 'Uwaga: ' + $app.Warning
    }
    $notes += if ($sourceId) { 'Cofnięcie: ponowna instalacja z repozytorium winget ({0}).' -f $sourceId } else { 'Nie będzie można cofnąć (pakietu nie ma w repozytorium winget).' }
    $action = 'Odinstalowanie aplikacji {0}. {1}' -f $describe, ($notes -join ' ')
    $target = Format-MwpOperationTarget -Target ('aplikacja {0}' -f $describe) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $app.Version -Message ('Podgląd: {0}' -f $action)
    }

    $logData = @{ Name = $app.Name; Version = $app.Version; Publisher = $app.Publisher; Source = $app.Source; AppId = $app.Id; WingetId = $sourceId; LocalId = $uninstallId; Scope = $app.Scope }
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message ('Odinstalowanie {0} — start.' -f $describe) -Data $logData
    $failure = $null
    $exitNote = ''
    if ($method -eq 'Appx') {
        $result = Invoke-MwpOnTarget -Context $Context -Operation $operation -ScriptBlock (Get-MwpAppsScript -Name RemoveAppx) -ArgumentList @([string]$app.PackageFullName) -TimeoutSeconds (Get-MwpAppsTargetConfig).ChangeTimeoutSeconds
        $raw = if ($result.Success) { ConvertFrom-MwpAppsJson -Data $result -Kind 'MWP.AppxRemoveRaw' } else { $null }
        $failure = if ($null -eq $raw) { $result.Message } elseif ($raw.Error) { [string]$raw.Error } elseif ($raw.Remaining) { 'pakiet nadal jest zainstalowany' } else { $null }
    }
    else {
        $arguments = @('uninstall', '--id', $uninstallId, '--exact', '--silent')
        if ($uninstallId -eq $sourceId) {
            $arguments += @('--source', (Get-MwpAppsTargetConfig).Source)
        }
        $call = Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -TimeoutSeconds (Get-MwpAppsTargetConfig).ChangeTimeoutSeconds
        if (-not $call.Success) {
            $failure = $call.Message
            $exitNote = $call.Message
        }
    }
    $lost = if ($method -eq 'Appx') { -not $result.Success } else { $null -ne $call.Result }
    if ($lost) {
        # Błąd połączenia: bez ponownego łączenia — stan sprawdzi użytkownik po „Połącz” i odświeżeniu.
        $message = "Odinstalowanie {0} na komputerze '{1}' przerwane — błąd połączenia: {2} Sprawdź listę programów po ponownym połączeniu." -f $describe, $computerName, $failure
        Write-MwpLog -Level Error -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
        return New-MwpResult @common -Success $false -Before $app.Version -Message $message -ErrorMessage $failure
    }
    # Sprawdzenie: ponowny odczyt (program mógł zniknąć mimo kodu błędu, np. wymaganego restartu).
    $check = Get-MwpAppTarget -Context $Context -AppId $(if ($AppId) { $AppId } else { '' }) -WingetId $(if ($WingetId) { $WingetId } else { '' })
    $gone = [bool]$check.NotFound
    if ($gone -and $failure -and $method -ne 'Appx') {
        $failure = $null
    }
    elseif (-not $gone -and -not $failure) {
        $failure = 'po zakończeniu aplikacja nadal jest na liście programów'
    }
    if ($failure) {
        $message = "Nie udało się odinstalować {0} na komputerze '{1}': {2}" -f $describe, $computerName, $failure
        Write-MwpLog -Level Error -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
        return New-MwpResult @common -Success $false -Before $app.Version -Message $message -ErrorMessage $failure
    }
    $undoId = $null
    if ($sourceId) {
        $undo = Save-MwpUndoEntry -Module 'MWP.Apps' -Operation $operation -Target $app.Name -ComputerName $computerName -Before $app.Version -After $null `
            -Description ('Odinstalowano {0} — cofnięcie: ponowna instalacja {1} z winget' -f $describe, $sourceId) -UndoCommand 'Install-MwpWingetPackage' -UndoParameters @{ Id = $sourceId }
        $undoId = $undo.Id
    }
    $message = "Odinstalowano {0} z komputera '{1}'.{2}" -f $describe, $computerName, $(if ($exitNote) { ' Uwaga winget: ' + $exitNote } else { '' })
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
    New-MwpResult @common -Success $true -Changed $true -Before $app.Version -After $null -UndoId $undoId -Message $message
}
