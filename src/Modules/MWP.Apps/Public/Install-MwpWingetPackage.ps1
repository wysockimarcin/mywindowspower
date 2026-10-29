function Install-MwpWingetPackage {
    <#
    .SYNOPSIS
        Instaluje pakiet z repozytorium winget (źródło 'winget') na komputerze docelowym.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027, D-050). Przed podglądem: identyfikator i wersja sprawdzone
        (D-015), pakiet wyszukany dokładnie (winget search --id --exact --source winget), sprawdzenie,
        czy nie jest już zainstalowany (wtedy „bez zmian”), na komputerze zdalnym — administrator.
        Potwierdzenie (z nazwą komputera) oznacza zgodę na umowy pakietu i źródła: instalacja z
        --accept-package-agreements --accept-source-agreements (decyzja użytkownika, D-050), --silent.
        Kontekst (D-051): localhost — konto aplikacji (bez administratora instalator może pokazać monit
        UAC); komputer zdalny — zadanie harmonogramu jako SYSTEM z --scope machine (dla wszystkich
        użytkowników); z -UserSid — w sesji tego zalogowanego użytkownika z --scope user (instalacja dla niego; lokalnie
        dla innego profilu wymaga administratora). Podgląd mówi, w czyim kontekście nastąpi zmiana.
        Po instalacji ponowny odczyt (winget list --id) w tym samym kontekście. Wpis cofnięcia:
        Uninstall-MwpApp -WingetId (z -UserSid). Log z nazwą, wersją i kontekstem. Funkcja jest też
        poleceniem cofającym odinstalowanie (Uninstall-MwpApp).

    .PARAMETER Id
        Identyfikator pakietu w repozytorium winget (np. 7zip.7zip).

    .PARAMETER Version
        Konkretna wersja (domyślnie najnowsza).

    .PARAMETER UserSid
        Profil zalogowanego użytkownika, dla którego zainstalować pakiet (zamiast konta aplikacji albo SYSTEM).

    .EXAMPLE
        Install-MwpWingetPackage -Id '7zip.7zip' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$')]
        [string] $Version,

        [ValidatePattern('^S-1-5-21-[0-9-]+$')]
        [string] $UserSid,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Apps.Install'
    $computerName = $Context.ComputerName
    $common = @{ Operation = $operation; Target = $Id; ComputerName = $computerName }
    if (-not (Test-MwpWingetId -Id $Id)) {
        throw ("Niepoprawny identyfikator pakietu winget: '{0}'." -f $Id)
    }
    $config = Get-MwpAppsTargetConfig
    $access = Test-MwpWingetRunAccess -Context $Context -UserSid $(if ($UserSid) { $UserSid } else { '' }) -What 'Instalacja'
    if (-not $access.Success) {
        return New-MwpResult @common -Success $false -Message $access.Message -ErrorMessage $(if ($null -ne $access.Result) { $access.Result.ErrorMessage } else { $null })
    }
    $userRun = if ($UserSid) { @{ UserSid = @($UserSid); UserOnly = $true } } else { @{} }
    $search = Invoke-MwpWinget -Context $Context -Operation 'Apps.WingetSearch' -Argument @('search', '--id', $Id, '--exact', '--source', $config.Source) -AllowedExitCode 0x8A150014L
    if (-not $search.Success) {
        return New-MwpResult @common -Success $false -Message $search.Message -ErrorMessage $search.ErrorMessage
    }
    $package = @(ConvertFrom-MwpWingetOutput -Line $search.Lines -Column 'Name', 'Id', 'Version', 'Match' | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if ($null -eq $package) {
        return New-MwpResult @common -Success $false -Message ("Pakietu '{0}' nie ma w repozytorium winget." -f $Id)
    }
    $common.Target = $package.Name
    $installed = Get-MwpWingetPackage -Context $Context -Id $Id @userRun
    if (-not $installed.Success) {
        return New-MwpResult @common -Success $false -Message $installed.Message -ErrorMessage $installed.ErrorMessage
    }
    $runInfo = @($installed.Data.Runs) | Select-Object -First 1
    $runAs = if ($null -ne $runInfo -and $runInfo.RunAs) { [string]$runInfo.RunAs } elseif ($Context.Mode -eq 'Local') { 'Direct' } else { 'System' }
    $userName = if ($null -ne $runInfo) { [string]$runInfo.UserName } else { '' }
    $current = @($installed.Data.Packages | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    $wanted = if ($Version) { $Version } else { [string]$package.Version }
    if ($null -ne $current -and (-not $Version -or $current.Version -eq $Version)) {
        return New-MwpResult @common -Success $true -Before $current.Version -After $current.Version -Message ("Bez zmian: pakiet '{0}' ({1}) jest już zainstalowany w wersji {2}." -f $package.Name, $Id, $current.Version)
    }
    $notes = @('Zatwierdzenie oznacza akceptację umów licencyjnych pakietu i warunków źródła winget.', (Get-MwpWingetRunText -RunAs $runAs -UserName $userName -UserSid $(if ($UserSid) { $UserSid } else { '' })))
    if ($runAs -eq 'System') {
        $notes += 'Instalacja dla całego komputera (--scope machine).'
    }
    elseif ($runAs -eq 'User') {
        $notes += 'Instalacja tylko dla tego użytkownika (--scope user; zadanie bez podwyższenia uprawnień).'
    }
    if ($null -ne $current) {
        $notes += 'Zainstalowana jest wersja {0}.' -f $current.Version
    }
    if ($runAs -eq 'Direct' -and -not (Test-MwpAdmin)) {
        $notes += 'Instalator może pokazać monit UAC.'
    }
    $action = 'Instalacja pakietu {0} ({1}) w wersji {2} z repozytorium winget. {3}' -f $package.Name, $Id, $wanted, ($notes -join ' ')
    $target = Format-MwpOperationTarget -Target ("pakiet '{0}' ({1})" -f $package.Name, $Id) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $(if ($null -ne $current) { $current.Version } else { $null }) -After $wanted -Message ('Podgląd: {0}' -f $action)
    }
    $arguments = @('install', '--id', $Id, '--exact', '--source', $config.Source, '--silent', '--accept-package-agreements', '--accept-source-agreements')
    if ($runAs -eq 'System') {
        $arguments += @('--scope', 'machine')
    }
    elseif ($runAs -eq 'User') {
        $arguments += @('--scope', 'user')
    }
    if ($Version) {
        $arguments += @('--version', $Version)
    }
    $logData = @{ Name = $package.Name; Id = $Id; Version = $wanted; RunAs = $runAs; UserSid = $(if ($UserSid) { $UserSid } else { '' }) }
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message ("Instalacja {0} ({1}) {2} — start ({3})." -f $package.Name, $Id, $wanted, $runAs) -Data $logData
    $call = Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -TimeoutSeconds $config.ChangeTimeoutSeconds @userRun
    if ($null -ne $call.Result) {
        $message = "Instalacja {0} ({1}) na komputerze '{2}' przerwana — błąd połączenia: {3} Sprawdź stan po ponownym połączeniu." -f $package.Name, $Id, $computerName, $call.Message
        Write-MwpLog -Level Error -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $call.ErrorMessage
    }
    $after = Get-MwpWingetPackage -Context $Context -Id $Id @userRun
    $now = if ($after.Success) { @($after.Data.Packages | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1 } else { $null }
    if ($null -eq $now) {
        $detail = if (-not $call.Success) { $call.Message } else { 'po instalacji pakietu nie ma na liście winget' }
        if ($runAs -eq 'System') {
            $detail += ' Jeśli pakiet nie ma instalatora dla całego komputera, zainstaluj go w profilu zalogowanego użytkownika.'
        }
        $message = "Nie udało się zainstalować {0} ({1}) na komputerze '{2}': {3}" -f $package.Name, $Id, $computerName, $detail
        Write-MwpLog -Level Error -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $detail
    }
    $undoParameters = @{ WingetId = $Id }
    if ($UserSid) {
        $undoParameters['UserSid'] = $UserSid
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Apps' -Operation $operation -Target $package.Name -ComputerName $computerName -Before $null -After $now.Version `
        -Description ('Zainstalowano {0} ({1}) {2} — cofnięcie: odinstalowanie' -f $package.Name, $Id, $now.Version) -UndoCommand 'Uninstall-MwpApp' -UndoParameters $undoParameters
    $message = "Zainstalowano {0} ({1}) w wersji {2} na komputerze '{3}'.{4}" -f $package.Name, $Id, $now.Version, $computerName, $(if (-not $call.Success) { ' Uwaga winget: ' + $call.Message } else { '' })
    $logData['Version'] = $now.Version
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
    New-MwpResult @common -Success $true -Changed $true -Before $(if ($null -ne $current) { $current.Version } else { $null }) -After $now.Version -UndoId $undo.Id -Message $message -Data ([pscustomobject]@{ RunAs = $runAs; UserSid = $(if ($UserSid) { $UserSid } else { '' }) })
}
