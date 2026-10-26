function Install-MwpModulePackage {
    <#
    .SYNOPSIS
        Instaluje moduł z paczki .mwpmod w <katalog danych>\modules (D-031, D-038).

    .DESCRIPTION
        Operacja klasy Zmiana (-WhatIf, -Confirm, log). Kolejność:
        1. rozpakowanie do katalogu roboczego w katalogu modułów z paczek (ten sam wolumin co cel)
           i walidacja jak w Test-MwpModulePackage;
        2. potwierdzenie z nazwą, Id, wersją, RequiredPermissions i sumą SHA-256 paczki;
        3. atomowe przeniesienie folderu modułu do <katalog danych>\modules\MWP.<Nazwa>;
        4. wpis w rejestrze (installedModules w settings.local.json).
        Błąd na dowolnym etapie usuwa katalog roboczy i wycofuje przeniesiony folder, więc nic
        nie zostaje w połowie. Paczka z Id już istniejącego modułu jest odrzucana (aktualizacji
        przez host nie ma: nową wersję instaluje się po odinstalowaniu starej). Instalacja dotyczy
        tylko komputera, na którym działa host; na komputerach zdalnych nic się nie instaluje.
        Odinstalowanie: Uninstall-MwpModulePackage (rejestr cofnięć nie obejmuje instalacji).
        Moduł staje się dostępny po ponownym uruchomieniu launchera (albo Import-Module).

    .PARAMETER Path
        Ścieżka do pliku .mwpmod.

    .EXAMPLE
        Install-MwpModulePackage -Path .\MWP.Przyklad.mwpmod -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $operation = 'Modules.Install'
    $computerName = 'localhost'
    $common = @{ Operation = $operation; Target = [IO.Path]::GetFileName($Path); ComputerName = $computerName }

    $installedRoot = (Get-MwpModuleRoot).Installed
    $staging = [IO.Path]::Combine($installedRoot, ('.mwp-install-{0}' -f [guid]::NewGuid().ToString('N')))
    $destination = $null
    $moved = $false
    try {
        $package = Read-MwpModulePackage -Path $Path -StagingRoot $staging
        $data = [ordered]@{ Id = $package.Id; ModuleName = $package.ModuleName; Version = [string]$package.Version; Sha256 = $package.Sha256 }
        if (-not $package.IsValid) {
            $message = "Paczka '{0}' została odrzucona: {1}" -f $common.Target, ($package.Errors -join ' ')
            Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message -Data $data
            return New-MwpResult @common -Success $false -Message $message -ErrorMessage ($package.Errors -join ' ') -Data $package
        }

        $destination = [IO.Path]::Combine($installedRoot, $package.ModuleName)
        if ([IO.Directory]::Exists($destination)) {
            $message = "Folder '{0}' już istnieje w katalogu modułów zainstalowanych." -f $destination
            Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message -Data $data
            return New-MwpResult @common -Success $false -Message $message -Data $package
        }

        $permissions = $package.RequiredPermissions -join ', '
        $description = "moduł '{0}' (Id {1}, wersja {2}, uprawnienia: {3}, SHA-256 paczki: {4})" -f $package.Name, $package.Id, $package.Version, $permissions, $package.Sha256
        $target = Format-MwpOperationTarget -Target $description -ComputerName $computerName
        if (-not $PSCmdlet.ShouldProcess($target, 'Instalacja modułu z paczki')) {
            return New-MwpResult @common -Success $true -IsPreview -After $data -Data $package `
                -Message ("Podgląd: zostanie zainstalowany {0}." -f $description)
        }

        $settingsData = Read-MwpSettingsData
        Move-MwpDirectory -Path $package.ExtractedPath -Destination $destination
        $moved = $true

        $entry = [ordered]@{
            id          = $package.Id
            moduleName  = $package.ModuleName
            version     = [string]$package.Version
            installedAt = (Get-Date).ToString('o')
            sha256      = $package.Sha256
        }
        $registry = @(@(Get-MwpInstalledModuleEntry -Settings $settingsData.Settings) | Where-Object { [string]$_['id'] -ne $package.Id }) + $entry
        Write-MwpLocalSetting -Values @{ installedModules = $registry } -Data $settingsData
        $moved = $false

        $message = "Zainstalowano moduł '{0}' (Id {1}, wersja {2})." -f $package.Name, $package.Id, $package.Version
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message -Data $data
        $package.ExtractedPath = $destination
        New-MwpResult @common -Success $true -Changed $true -After $data -Data $package -Message $message
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($moved -and $null -ne $destination -and [IO.Directory]::Exists($destination)) {
            try {
                [IO.Directory]::Delete($destination, $true)
            }
            catch {
                $errorMessage = "{0} Nie udało się usunąć folderu '{1}': {2}" -f $errorMessage, $destination, $_.Exception.Message
            }
        }
        $message = "Nie udało się zainstalować modułu z paczki '{0}': {1}" -f $common.Target, $errorMessage
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message
        New-MwpResult @common -Success $false -Message $message -ErrorMessage $errorMessage
    }
    finally {
        if ([IO.Directory]::Exists($staging)) {
            [IO.Directory]::Delete($staging, $true)
        }
        # Pusty katalog modułów z paczek po nieudanej instalacji nie jest potrzebny.
        if ([IO.Directory]::Exists($installedRoot) -and @([IO.Directory]::GetFileSystemEntries($installedRoot)).Count -eq 0) {
            [IO.Directory]::Delete($installedRoot)
        }
    }
}
