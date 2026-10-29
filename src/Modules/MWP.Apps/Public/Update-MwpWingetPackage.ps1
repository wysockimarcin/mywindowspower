function Update-MwpWingetPackage {
    <#
    .SYNOPSIS
        Aktualizuje pojedynczy pakiet do najnowszej wersji z repozytorium winget (winget upgrade --id) na komputerze docelowym.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027, D-050). Przed podglądem: identyfikator sprawdzony (D-015), pakiet
        zainstalowany z dostępną aktualizacją (winget list --id --exact --source winget; bez
        aktualizacji — „bez zmian”), na komputerze zdalnym — administrator. Potwierdzenie oznacza zgodę
        na umowy pakietu i źródła (--accept-package-agreements --accept-source-agreements, --silent).
        Po aktualizacji ponowny odczyt wersji; log z wersją przed i po. Bez wpisu cofnięcia (poprzedniej
        wersji zwykle nie ma już w repozytorium; wersja sprzed zmiany jest w logu i w wyniku — ręcznie:
        Install-MwpWingetPackage -Id … -Version …).

    .PARAMETER Id
        Identyfikator pakietu w repozytorium winget.

    .EXAMPLE
        Update-MwpWingetPackage -Id 'Git.Git' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Apps.Upgrade'
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
            return New-MwpResult @common -Success $false -Message ("Aktualizacja na komputerze zdalnym '{0}' wymaga konta administratora w połączeniu." -f $computerName)
        }
    }
    $installed = Get-MwpWingetPackage -Context $Context -Id $Id
    if (-not $installed.Success) {
        return New-MwpResult @common -Success $false -Message $installed.Message -ErrorMessage $installed.ErrorMessage
    }
    $current = @($installed.Data.Packages | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if ($null -eq $current) {
        return New-MwpResult @common -Success $false -Message ("Pakiet '{0}' nie jest zainstalowany na komputerze '{1}' (albo winget go nie rozpoznaje)." -f $Id, $computerName)
    }
    $common.Target = $current.Name
    if (-not $current.Available) {
        return New-MwpResult @common -Success $true -Before $current.Version -After $current.Version -Message ("Bez zmian: {0} ({1}) {2} — brak nowszej wersji w winget." -f $current.Name, $Id, $current.Version)
    }
    $notes = @('Zatwierdzenie oznacza akceptację umów licencyjnych pakietu i warunków źródła winget.', 'Bez wpisu cofnięcia (wersja sprzed zmiany zostaje w logu).')
    if ($Context.Mode -eq 'Local' -and -not (Test-MwpAdmin)) {
        $notes += 'Instalator może pokazać monit UAC.'
    }
    $action = 'Aktualizacja {0} ({1}) z wersji {2} do {3}. {4}' -f $current.Name, $Id, $current.Version, $current.Available, ($notes -join ' ')
    $target = Format-MwpOperationTarget -Target ("pakiet '{0}' ({1})" -f $current.Name, $Id) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $current.Version -After $current.Available -Message ('Podgląd: {0}' -f $action)
    }
    $arguments = @('upgrade', '--id', $Id, '--exact', '--source', $config.Source, '--silent', '--accept-package-agreements', '--accept-source-agreements')
    $logData = @{ Name = $current.Name; Id = $Id; Before = $current.Version; Target = $current.Available }
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message ("Aktualizacja {0} ({1}) {2} → {3} — start." -f $current.Name, $Id, $current.Version, $current.Available) -Data $logData
    $call = Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -TimeoutSeconds $config.ChangeTimeoutSeconds
    if ($null -ne $call.Result) {
        $message = "Aktualizacja {0} ({1}) na komputerze '{2}' przerwana — błąd połączenia: {3} Sprawdź wersję po ponownym połączeniu." -f $current.Name, $Id, $computerName, $call.Message
        Write-MwpLog -Level Error -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
        return New-MwpResult @common -Success $false -Before $current.Version -Message $message -ErrorMessage $call.ErrorMessage
    }
    $after = Get-MwpWingetPackage -Context $Context -Id $Id
    $now = if ($after.Success) { @($after.Data.Packages | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1 } else { $null }
    $newVersion = if ($null -ne $now) { [string]$now.Version } else { '' }
    if (-not $newVersion -or $newVersion -eq $current.Version) {
        $detail = if (-not $call.Success) { $call.Message } elseif (-not $after.Success) { $after.Message } else { 'wersja się nie zmieniła' }
        $message = "Nie udało się zaktualizować {0} ({1}) na komputerze '{2}': {3}" -f $current.Name, $Id, $computerName, $detail
        Write-MwpLog -Level Error -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
        return New-MwpResult @common -Success $false -Before $current.Version -Message $message -ErrorMessage $detail
    }
    $logData['After'] = $newVersion
    $message = "Zaktualizowano {0} ({1}) z wersji {2} do {3} na komputerze '{4}'." -f $current.Name, $Id, $current.Version, $newVersion, $computerName
    Write-MwpLog -Level Info -Source 'MWP.Apps' -Operation $operation -ComputerName $computerName -Message $message -Data $logData
    New-MwpResult @common -Success $true -Changed $true -Before $current.Version -After $newVersion -Message $message
}
