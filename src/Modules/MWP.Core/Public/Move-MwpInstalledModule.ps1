function Move-MwpInstalledModule {
    <#
    .SYNOPSIS
        Przenosi moduły z paczek z dawnego katalogu src\Modules\Installed do katalogu danych (<katalog danych>\modules).

    .DESCRIPTION
        Migracja instalacji z FAZY 3 (D-038). Operacja klasy Zmiana (-WhatIf, -Confirm, log). Każdy
        moduł jest kopiowany do katalogu roboczego w katalogu modułów (.mwp-install-<GUID>), potem
        przenoszony na miejsce, a dopiero na końcu usuwany ze starego miejsca, więc błąd nie zostawia
        modułu w połowie. Moduł, którego folder już istnieje w katalogu danych, jest pomijany
        z komunikatem. Rejestr installedModules się nie zmienia (zawiera nazwę folderu, nie ścieżkę).
        Wpisu cofnięcia nie ma: oba miejsca są odkrywane (Get-MwpModuleDefinition), więc powrót
        nie jest potrzebny. Moduły już załadowane działają dalej; nowe położenie obowiązuje od
        następnego uruchomienia. Dotyczy tylko komputera, na którym działa host.

    .EXAMPLE
        Move-MwpInstalledModule -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param()

    $operation = 'Modules.MoveToDataPath'
    $computerName = 'localhost'
    $moduleRoot = Get-MwpModuleRoot
    $destinationRoot = $moduleRoot.Installed
    $legacy = $null
    if ($null -ne $moduleRoot.PSObject.Properties['Legacy']) {
        $legacy = $moduleRoot.Legacy
    }
    $common = @{ Operation = $operation; Target = 'modules'; ComputerName = $computerName }

    $folders = @()
    if (-not [string]::IsNullOrEmpty($legacy) -and [IO.Directory]::Exists($legacy)) {
        $folders = @([IO.Directory]::GetDirectories($legacy, 'MWP.*') | Sort-Object)
    }
    if ($folders.Count -eq 0) {
        return New-MwpResult @common -Success $true -Message 'Brak modułów z paczek w dawnym katalogu src\Modules\Installed.'
    }

    $names = @($folders | ForEach-Object { [IO.Path]::GetFileName($_) })
    $description = "moduły z paczek {0}: '{1}' -> '{2}'" -f ($names -join ', '), $legacy, $destinationRoot
    $operationTarget = Format-MwpOperationTarget -Target $description -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($operationTarget, 'Przeniesienie modułów z paczek do katalogu danych')) {
        return New-MwpResult @common -Success $true -IsPreview -Before $legacy -After $destinationRoot -Data $names `
            -Message ("Podgląd: zostaną przeniesione {0}." -f $description)
    }

    $movedNames = New-Object -TypeName System.Collections.Generic.List[string]
    $problems = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($folder in $folders) {
        $name = [IO.Path]::GetFileName($folder)
        $final = [IO.Path]::Combine($destinationRoot, $name)
        if ([IO.Directory]::Exists($final)) {
            $problems.Add(("{0}: folder już istnieje w '{1}'" -f $name, $destinationRoot))
            continue
        }
        $staging = [IO.Path]::Combine($destinationRoot, ('.mwp-install-{0}' -f [guid]::NewGuid().ToString('N')))
        try {
            $null = [IO.Directory]::CreateDirectory($destinationRoot)
            $null = Copy-MwpDirectory -Path $folder -Destination $staging
            Move-MwpDirectory -Path $staging -Destination $final
        }
        catch {
            $problems.Add(("{0}: {1}" -f $name, $_.Exception.Message))
            if ([IO.Directory]::Exists($staging)) {
                [IO.Directory]::Delete($staging, $true)
            }
            continue
        }
        $movedNames.Add($name)
        try {
            [IO.Directory]::Delete($folder, $true)
        }
        catch {
            $problems.Add(("{0}: skopiowano, ale nie udało się usunąć starego folderu ({1}); usuń go ręcznie" -f $name, $_.Exception.Message))
        }
    }
    if ([IO.Directory]::Exists($legacy) -and @([IO.Directory]::GetFileSystemEntries($legacy)).Count -eq 0) {
        [IO.Directory]::Delete($legacy)
    }

    $message = "Przeniesiono moduły z paczek do '{0}': {1}." -f $destinationRoot, $(if ($movedNames.Count -gt 0) { $movedNames -join ', ' } else { 'żaden' })
    if ($problems.Count -gt 0) {
        $message = "{0} Problemy: {1}." -f $message, ($problems -join '; ')
    }
    $level = if ($problems.Count -gt 0) { 'Warning' } else { 'Info' }
    Write-MwpLog -Level $level -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message `
        -Data @{ Moved = @($movedNames); From = $legacy; To = $destinationRoot }
    New-MwpResult @common -Success ($problems.Count -eq 0) -Changed ($movedNames.Count -gt 0) -Before $legacy -After $destinationRoot `
        -Data @($movedNames) -Message $message -ErrorMessage ($problems -join '; ')
}
