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
        Lokalnie bez administratora instalator może pokazać monit UAC. Po instalacji ponowny odczyt
        (winget list --id). Wpis cofnięcia: Uninstall-MwpApp -WingetId. Log z nazwą i wersją.
        Funkcja jest też poleceniem cofającym odinstalowanie (Uninstall-MwpApp).

    .PARAMETER Id
        Identyfikator pakietu w repozytorium winget (np. 7zip.7zip).

    .PARAMETER Version
        Konkretna wersja (domyślnie najnowsza).

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
    if ($Context.Mode -eq 'Remote') {
        $admin = Test-MwpAppsAdmin -Context $Context
        if (-not $admin.Success) {
            return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
        }
        if (-not $admin.IsAdministrator) {
            return New-MwpResult @common -Success $false -Message ("Instalacja na komputerze zdalnym '{0}' wymaga konta administratora w połączeniu." -f $computerName)
        }
    }
    $search = Invoke-MwpWinget -Context $Context -Operation 'Apps.WingetSearch' -Argument @('search', '--id', $Id, '--exact', '--source', $config.Source) -AllowedExitCode 0x8A150014L
    if (-not $search.Success) {
        return New-MwpResult @common -Success $false -Message $search.Message -ErrorMessage $search.ErrorMessage
    }
    $package = @(ConvertFrom-MwpWingetOutput -Line $search.Lines -Column 'Name', 'Id', 'Version', 'Match' | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if ($null -eq $package) {
        return New-MwpResult @common -Success $false -Message ("Pakietu '{0}' nie ma w repozytorium winget." -f $Id)
    }
    $common.Target = $package.Name
    $installed = Get-MwpWingetPackage -Context $Context -Id $Id
    if (-not $installed.Success) {
        return New-MwpResult @common -Success $false -Message $installed.Message -ErrorMessage $installed.ErrorMessage
    }
    $current = @($installed.Data.Packages | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    $wanted = if ($Version) { $Version } else { [string]$package.Version }
    if ($null -ne $current -and (-not $Version -or $current.Version -eq $Version)) {
        return New-MwpResult @common -Success $true -Before $current.Version -After $current.Version -Message ("Bez zmian: pakiet '{0}' ({1}) jest już zainstalowany w wersji {2}." -f $package.Name, $Id, $current.Version)
    }
    $notes = @('Zatwierdzenie oznacza akceptację umów licencyjnych pakietu i warunków źródła winget.')
    if ($null -ne $current) {
        $notes += 'Zainstalowana jest wersja {0}.' -f $current.Version
    }
    if ($Context.Mode -eq 'Local' -and -not (Test-MwpAdmin)) {
        $notes += 'Instalator może pokazać monit UAC.'
    }
    $action = 'Instalacja pakietu {0} ({1}) w wersji {2} z repozytorium winget. {3}' -f $package.Name, $Id, $wanted, ($notes -join ' ')
    $target = Format-MwpOperationTarget -Target ("pakiet '{0}' ({1})" -f $package.Name, $Id) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $(if ($null -ne $current) { $current.Version } else { $null }) -After $wanted -Message ('Podgląd: {0}' -f $action)
    }
    $arguments = @('install', '--id', $Id, '--exact', '--source', $config.Source, '--silent', '--accept-package-agreements', '--accept-source-agreements')
    if ($Version) {
        $arguments += @('--version', $Version)
    }
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message ("Instalacja {0} ({1}) {2} — start." -f $package.Name, $Id, $wanted)
    $call = Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -TimeoutSeconds $config.ChangeTimeoutSeconds
    if ($null -ne $call.Result) {
        $message = "Instalacja {0} ({1}) na komputerze '{2}' przerwana — błąd połączenia: {3} Sprawdź stan po ponownym połączeniu." -f $package.Name, $Id, $computerName, $call.Message
        Write-MwpLog -Level Error -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $call.ErrorMessage
    }
    $after = Get-MwpWingetPackage -Context $Context -Id $Id
    $now = if ($after.Success) { @($after.Data.Packages | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1 } else { $null }
    if ($null -eq $now) {
        $detail = if (-not $call.Success) { $call.Message } else { 'po instalacji pakietu nie ma na liście winget' }
        $message = "Nie udało się zainstalować {0} ({1}) na komputerze '{2}': {3}" -f $package.Name, $Id, $computerName, $detail
        Write-MwpLog -Level Error -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $detail
    }
    $undo = Save-MwpUndoEntry -Module 'MWP.Apps' -Operation $operation -Target $package.Name -ComputerName $computerName -Before $null -After $now.Version `
        -Description ('Zainstalowano {0} ({1}) {2} — cofnięcie: odinstalowanie' -f $package.Name, $Id, $now.Version) -UndoCommand 'Uninstall-MwpApp' -UndoParameters @{ WingetId = $Id }
    $message = "Zainstalowano {0} ({1}) w wersji {2} na komputerze '{3}'.{4}" -f $package.Name, $Id, $now.Version, $computerName, $(if (-not $call.Success) { ' Uwaga winget: ' + $call.Message } else { '' })
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Name = $package.Name; Id = $Id; Version = $now.Version }
    New-MwpResult @common -Success $true -Changed $true -Before $(if ($null -ne $current) { $current.Version } else { $null }) -After $now.Version -UndoId $undo.Id -Message $message
}
