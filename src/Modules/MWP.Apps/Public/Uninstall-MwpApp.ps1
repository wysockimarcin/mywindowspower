function Uninstall-MwpApp {
    <#
    .SYNOPSIS
        Odinstalowuje aplikację z komputera docelowego: program z rejestru przez winget, pakiet Appx przez Remove-AppxPackage.

    .DESCRIPTION
        Operacja klasy Destrukcyjna (D-027, D-050): ConfirmImpact High — bez -Confirm:$false funkcja
        zawsze pyta; potwierdzenie i podgląd zawierają nazwę, wersję, wydawcę, komputer i kontekst.
        Przed podglądem (odmowa = wynik z błędem):
        - lista ochronna i składniki systemu (Get-MwpAppProtection: Appx systemowe, struktury, zasobów,
          nieusuwalne; SystemComponent, NoRemove, aktualizacje; kategorie App i AppxPackage) — także
          z CLI i na komputerze zdalnym;
        - komputer zdalny: administrator na komputerze docelowym; localhost z programem profilu innego
          użytkownika: aplikacja uruchomiona jako administrator;
        - program profilu użytkownika (D-051): właściciel profilu musi być zalogowany (winget działa
          w jego sesji przez zadanie harmonogramu; bez zapisywania haseł, D-034).
        Kontekst winget (D-051): program komputera — localhost: konto aplikacji, komputer zdalny:
        zadanie jako SYSTEM; program profilu — sesja właściciela profilu (lokalnie dla konta aplikacji
        bezpośrednio). Sposób: program z rejestru — winget uninstall --id <ARP\…> --exact --silent
        (identyfikator lokalny z klucza Uninstall); pakiet z -WingetId — winget uninstall --id <Id>.
        Program rozpoznany w repozytorium winget: z --source winget (bez umów innych źródeł); program
        spoza repozytorium: bez źródła i z --accept-source-agreements — potwierdzenie oznacza zgodę na
        warunki źródeł winget (w tym msstore) dla konta, które uruchamia winget (decyzja użytkownika,
        D-051). Appx — Remove-AppxPackage (konto sesji). Lokalnie bez administratora instalator może
        pokazać monit UAC. Log na hoście: nazwa, wersja, wydawca, identyfikatory i kontekst (przed i
        po). Sprawdzenie: ponowny odczyt inwentarza. Cofnięcie (wpis tylko, gdy pakiet ma identyfikator
        w repozytorium winget): Install-MwpWingetPackage -Id [-UserSid] — ponowna instalacja.

    .PARAMETER AppId
        Identyfikator aplikacji z Get-MwpInstalledApp (Registry:… albo Appx:…).

    .PARAMETER WingetId
        Identyfikator pakietu winget (źródła albo lokalny ARP\…, MSIX\…).

    .PARAMETER UserSid
        Z -WingetId: profil zalogowanego użytkownika, w którym zainstalowany jest pakiet.

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

        [Parameter(ParameterSetName = 'Winget')]
        [ValidatePattern('^S-1-5-21-[0-9-]+$')]
        [string] $UserSid,

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
    $lookup = @{ Context = $Context; AppId = $(if ($AppId) { $AppId } else { '' }); WingetId = $(if ($WingetId) { $WingetId } else { '' }); UserSid = $(if ($UserSid) { $UserSid } else { '' }) }
    $found = Get-MwpAppTarget @lookup
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
    $method = [string]$app.UninstallMethod
    $remote = $Context.Mode -eq 'Remote'
    # Kontekst winget: program profilu — sesja właściciela (lokalnie konto aplikacji bezpośrednio).
    $ownerSid = if ($method -eq 'Winget' -and $app.Scope -eq 'User' -and $app.UserSid) { [string]$app.UserSid } else { '' }
    $userRun = @{}
    if ($ownerSid -and ($remote -or $ownerSid -ne (Get-MwpAppsHostSid))) {
        $userRun = @{ UserSid = @($ownerSid); UserOnly = $true }
    }
    $access = Test-MwpWingetRunAccess -Context $Context -UserSid $(if ($userRun.Count -gt 0) { $ownerSid } else { '' }) -What 'Odinstalowanie'
    if (-not $access.Success) {
        return New-MwpResult @common -Success $false -Message $access.Message -ErrorMessage $(if ($null -ne $access.Result) { $access.Result.ErrorMessage } else { $null })
    }
    $uninstallId = if ($PSCmdlet.ParameterSetName -eq 'Winget') { $WingetId } elseif ($app.Source -eq 'Registry') { [string]$app.WingetLocalId } else { '' }
    $runAs = if ($userRun.Count -gt 0) { 'User' } elseif ($remote) { 'System' } else { 'Direct' }
    $runUserName = if ($null -ne $found.UserRun -and $found.UserRun.UserName) { [string]$found.UserRun.UserName } else { [string]$app.UserName }
    if ($method -eq 'Winget') {
        if ($runAs -eq 'User') {
            if ($null -ne $found.UserRun -and -not $found.UserRun.Success) {
                return New-MwpResult @common -Success $false -Message ("Nie można odinstalować {0}: {1}" -f $describe, $found.UserRun.Message)
            }
        }
        elseif (-not $found.WingetOk) {
            return New-MwpResult @common -Success $false -Message ("Nie można odinstalować {0}: {1}" -f $describe, $found.Message)
        }
        if (-not (Test-MwpWingetId -Id $uninstallId -AllowLocal)) {
            return New-MwpResult @common -Success $false -Message ("Nie można odinstalować {0}: klucz rejestru '{1}' nie daje poprawnego identyfikatora winget." -f $describe, $app.KeyName)
        }
    }
    $sourceId = if ($app.WingetId -and (Test-MwpWingetId -Id ([string]$app.WingetId))) { [string]$app.WingetId } else { '' }
    $arguments = @('uninstall', '--id', $uninstallId, '--exact', '--silent')
    $notes = @()
    if ($method -eq 'Appx') {
        $notes += 'Sposób: Remove-AppxPackage (pakiet konta {0}).' -f $found.Inventory.CurrentUser
    }
    else {
        if ($sourceId) {
            # Program rozpoznany w repozytorium winget: tylko źródło winget (bez umów msstore).
            $arguments += @('--source', (Get-MwpAppsTargetConfig).Source)
        }
        else {
            $arguments += '--accept-source-agreements'
        }
        $notes += 'Sposób: winget {0}.' -f ($arguments -join ' ')
        $notes += Get-MwpWingetRunText -RunAs $runAs -UserName $runUserName -UserSid $ownerSid
        if (-not $sourceId) {
            $notes += 'Programu nie ma w repozytorium winget — zatwierdzenie oznacza zgodę na warunki źródeł winget (w tym msstore) dla konta, które uruchamia winget.'
        }
        if ($runAs -eq 'Direct' -and $app.Scope -eq 'Machine' -and -not $found.Inventory.IsAdministrator) {
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

    $logData = @{ Name = $app.Name; Version = $app.Version; Publisher = $app.Publisher; Source = $app.Source; AppId = $app.Id; WingetId = $sourceId; LocalId = $uninstallId; Scope = $app.Scope; RunAs = $(if ($method -eq 'Appx') { 'Session' } else { $runAs }); UserSid = $ownerSid }
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message ('Odinstalowanie {0} — start.' -f $describe) -Data $logData
    $failure = $null
    $exitNote = ''
    if ($method -eq 'Appx') {
        $result = Invoke-MwpOnTarget -Context $Context -Operation $operation -ScriptBlock (Get-MwpAppsScript -Name RemoveAppx) -ArgumentList @([string]$app.PackageFullName) -TimeoutSeconds (Get-MwpAppsTargetConfig).ChangeTimeoutSeconds
        $raw = if ($result.Success) { ConvertFrom-MwpAppsJson -Data $result -Kind 'MWP.AppxRemoveRaw' } else { $null }
        $failure = if ($null -eq $raw) { $result.Message } elseif ($raw.Error) { [string]$raw.Error } elseif ($raw.Remaining) { 'pakiet nadal jest zainstalowany' } else { $null }
    }
    else {
        $call = Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -TimeoutSeconds (Get-MwpAppsTargetConfig).ChangeTimeoutSeconds @userRun
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
    $check = Get-MwpAppTarget @lookup
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
        $undoParameters = @{ Id = $sourceId }
        if ($runAs -eq 'User') {
            $undoParameters['UserSid'] = $ownerSid
        }
        $undo = Save-MwpUndoEntry -Module 'MWP.Apps' -Operation $operation -Target $app.Name -ComputerName $computerName -Before $app.Version -After $null `
            -Description ('Odinstalowano {0} — cofnięcie: ponowna instalacja {1} z winget' -f $describe, $sourceId) -UndoCommand 'Install-MwpWingetPackage' -UndoParameters $undoParameters
        $undoId = $undo.Id
    }
    $message = "Odinstalowano {0} z komputera '{1}'.{2}" -f $describe, $computerName, $(if ($exitNote) { ' Uwaga winget: ' + $exitNote } else { '' })
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
    New-MwpResult @common -Success $true -Changed $true -Before $app.Version -After $null -UndoId $undoId -Message $message
}
