function Uninstall-MwpModulePackage {
    <#
    .SYNOPSIS
        Odinstalowuje moduł zainstalowany z paczki .mwpmod (D-031).

    .DESCRIPTION
        Operacja klasy Destrukcyjna (ConfirmImpact High: przy domyślnych ustawieniach zawsze pyta,
        potwierdzenie zawiera nazwę modułu i komputer). Kolejność:
        1. zamknięcie instancji modułu (Close-MwpModuleInstance z MWP.Remote, gdy jest załadowany)
           i usunięcie modułu z sesji;
        2. przeniesienie folderu do katalogu roboczego (krok odwracalny);
        3. usunięcie wpisu z rejestru (installedModules) i sekcji konfiguracji modułu (modules.<Id>);
           błąd tego kroku przywraca folder;
        4. usunięcie folderu z dysku.
        Zostają logi operacji i rejestr cofnięć (audyt zmian w systemie). Odinstalowania nie cofa
        rejestr cofnięć (ponowna instalacja z paczki). Moduły bazowe (Core, Remote) i wbudowane
        (src\Modules) są nieusuwalne, tak samo moduł wymagany przez inny moduł.
        Usuwanie widgetów modułu z Dashboardu — FAZA 5.

    .PARAMETER Id
        Id modułu albo nazwa jego folderu (MWP.<Nazwa>).

    .EXAMPLE
        Uninstall-MwpModulePackage -Id 'Przyklad' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $operation = 'Modules.Uninstall'
    $computerName = 'localhost'
    $common = @{ Operation = $operation; Target = $Id; ComputerName = $computerName }
    $fail = {
        param($Message)
        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $Message
        New-MwpResult @common -Success $false -Message $Message
    }

    $definitions = @(Get-MwpModuleDefinition)
    $definition = @($definitions | Where-Object { $_.Id -eq $Id -or $_.ModuleName -eq $Id }) | Select-Object -First 1
    if ($null -eq $definition) {
        return & $fail ("Nie znaleziono modułu '{0}'." -f $Id)
    }
    if ($definition.IsBase) {
        return & $fail ("Moduł bazowy '{0}' ({1}) nie może zostać odinstalowany." -f $definition.Name, $definition.ModuleName)
    }
    if ($definition.Source -ne 'Installed') {
        return & $fail ("Moduł wbudowany '{0}' ({1}) nie może zostać odinstalowany; odinstalować można tylko moduły zainstalowane z paczki." -f
            $definition.Name, $definition.ModuleName)
    }
    $dependents = @($definitions | Where-Object { @($_.Dependencies | ForEach-Object { $_.Id }) -contains $definition.Id })
    if ($dependents.Count -gt 0) {
        return & $fail ("Moduł '{0}' jest wymagany przez: {1}. Najpierw odinstaluj te moduły." -f
            $definition.Id, (@($dependents | ForEach-Object { $_.ModuleName }) -join ', '))
    }

    $common.Target = $definition.Id
    $before = [ordered]@{ Id = $definition.Id; ModuleName = $definition.ModuleName; Version = [string]$definition.Version }
    $description = "moduł '{0}' (Id {1}, wersja {2})" -f $definition.Name, $definition.Id, $definition.Version
    $target = Format-MwpOperationTarget -Target $description -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, 'Odinstalowanie modułu: zamknięcie instancji, usunięcie folderu, konfiguracji i wpisu w rejestrze')) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -Message ("Podgląd: zostanie odinstalowany {0}." -f $description)
    }

    $installedRoot = Split-Path -Parent $definition.ModuleBase
    $trash = [IO.Path]::Combine($installedRoot, ('.mwp-remove-{0}' -f [guid]::NewGuid().ToString('N')))
    try {
        # Instancje należą do MWP.Remote; rdzeń wywołuje je tylko, gdy moduł jest załadowany (bez zależności cyklicznej).
        $closed = 0
        $getInstance = Get-Command -Name 'Get-MwpModuleInstance' -CommandType Function -ErrorAction SilentlyContinue
        $closeInstance = Get-Command -Name 'Close-MwpModuleInstance' -CommandType Function -ErrorAction SilentlyContinue
        if ($null -ne $getInstance -and $null -ne $closeInstance) {
            foreach ($instance in @(& $getInstance -ModuleId $definition.Id)) {
                $null = & $closeInstance -Instance $instance
                $closed++
            }
        }
        Get-Module -Name $definition.ModuleName | Remove-Module -Force

        $settingsData = Read-MwpSettingsData
        Move-MwpDirectory -Path $definition.ModuleBase -Destination $trash
        try {
            $registry = @(@(Get-MwpInstalledModuleEntry -Settings $settingsData.Settings) | Where-Object { [string]$_['id'] -ne $definition.Id })
            $moduleSettings = [ordered]@{}
            if ($settingsData.Settings['modules'] -is [Collections.IDictionary]) {
                foreach ($key in $settingsData.Settings['modules'].Keys) {
                    if ($key -ne $definition.Id) {
                        $moduleSettings[$key] = $settingsData.Settings['modules'][$key]
                    }
                }
            }
            Write-MwpLocalSetting -Values @{ installedModules = $registry; modules = $moduleSettings } -Data $settingsData
        }
        catch {
            Move-MwpDirectory -Path $trash -Destination $definition.ModuleBase
            throw
        }

        $message = "Odinstalowano {0}; zamknięte instancje: {1}." -f $description, $closed
        try {
            [IO.Directory]::Delete($trash, $true)
        }
        catch {
            $message = "{0} Nie udało się usunąć folderu roboczego '{1}' ({2}); usuń go ręcznie." -f $message, $trash, $_.Exception.Message
        }
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message -Data $before
        New-MwpResult @common -Success $true -Changed $true -Before $before -Message $message -Data ([ordered]@{ ClosedInstances = $closed })
    }
    catch {
        $message = "Nie udało się odinstalować modułu '{0}': {1}" -f $definition.Id, $_.Exception.Message
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message
        New-MwpResult @common -Success $false -Before $before -Message $message -ErrorMessage $_.Exception.Message
    }
}
