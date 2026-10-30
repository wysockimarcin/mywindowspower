function Set-MwpSetting {
    <#
    .SYNOPSIS
        Zmienia ustawienie aplikacji w config\settings.local.json (zapis atomowy, z cofnięciem).
        Gdy folder config jest niezapisywalny: %LOCALAPPDATA%\MyWindowsPower\settings.local.json (D-032).

    .DESCRIPTION
        Przykład wzorca funkcji zmieniającej stan (ARCHITEKTURA.md, „Wzorzec funkcji zmieniającej
        system"): walidacja, -WhatIf/-Confirm, zapis atomowy, wpis w rejestrze cofnięć, log
        i obiekt MWP.Result. Dozwolone są tylko ustawienia z szablonu, z wartością tego samego
        typu; schemaVersion zmienia wyłącznie migracja. Ustawienia aplikacji należą do hosta,
        więc komputer docelowy to zawsze 'localhost'.
        -Values (D-054) zapisuje kilka ustawień jednym zapisem atomowym (np. rejestr komputerów
        i konfigurację Pulpitu przy zmianie nazwy komputera). -NoUndo pomija wpis w rejestrze cofnięć,
        gdy cofnięcie samych ustawień rozspójniłoby stan poza plikiem (np. hasło w Menedżerze poświadczeń).

    .EXAMPLE
        Set-MwpSetting -Name logLevel -Value 'Debug' -WhatIf

    .EXAMPLE
        Set-MwpSetting -Values @{ targets = $targets; dashboardWidgets = $widgets } -NoUndo
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Single')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Single')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Single')]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [object] $Value,

        [Parameter(Mandatory, ParameterSetName = 'Values')]
        [ValidateNotNull()]
        [Collections.IDictionary] $Values,

        [switch] $NoUndo
    )

    $computerName = 'localhost'
    if ($PSCmdlet.ParameterSetName -eq 'Values') {
        $names = @($Values.Keys | ForEach-Object { [string]$_ } | Sort-Object)
        $common = @{ Operation = 'Settings.Set'; Target = ($names -join ', '); ComputerName = $computerName }
        $data = Read-MwpSettingsData
        foreach ($warning in $data.Warnings) {
            Write-Warning $warning
        }
        if ($names.Count -eq 0) {
            return New-MwpResult @common -Success $false -Message 'Brak ustawień do zapisania.'
        }
        foreach ($key in $names) {
            if ($key -eq 'schemaVersion') {
                return New-MwpResult @common -Success $false -Message 'Ustawienia schemaVersion nie zmienia się ręcznie; zmienia ją migracja.'
            }
            if (-not $data.Defaults.Contains($key)) {
                return New-MwpResult @common -Success $false -Message ("Nieznane ustawienie '{0}'." -f $key)
            }
            if (-not (Test-MwpSettingValueType -Default $data.Defaults[$key] -Value $Values[$key])) {
                $expected = if ($null -eq $data.Defaults[$key]) { 'dowolny' } else { $data.Defaults[$key].GetType().Name }
                return New-MwpResult @common -Success $false -Message ("Niepoprawny typ wartości ustawienia '{0}' (oczekiwany: {1})." -f $key, $expected)
            }
        }
        $beforeValues = [ordered]@{}
        foreach ($key in $names) {
            $beforeValues[$key] = $data.Settings[$key]
        }
        $target = Format-MwpOperationTarget -Target ("ustawienia {0}" -f ($names -join ', ')) -ComputerName $computerName
        if (-not $PSCmdlet.ShouldProcess($target, 'Zmiana wartości ustawień (jeden zapis)')) {
            return New-MwpResult @common -Success $true -IsPreview -Before $beforeValues -After $Values `
                -Message ("Podgląd: ustawienia {0} zostaną zapisane jednym zapisem." -f ($names -join ', '))
        }
        try {
            Write-MwpLocalSetting -Values $Values -Data $data
            $undoId = $null
            if (-not $NoUndo) {
                $undo = Save-MwpUndoEntry -Module 'MWP.Core' -Operation $common.Operation -Target $common.Target -ComputerName $computerName `
                    -Description ("Przywrócenie ustawień {0}" -f ($names -join ', ')) `
                    -Before $beforeValues -After $Values -UndoCommand 'Set-MwpSetting' -UndoParameters @{ Values = $beforeValues }
                $undoId = $undo.Id
            }
            $message = "Zapisano ustawienia {0}." -f ($names -join ', ')
            Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $common.Operation -ComputerName $computerName -Message $message `
                -Data @{ Names = $names; UndoId = $undoId }
            return New-MwpResult @common -Success $true -Changed $true -Before $beforeValues -After $Values -UndoId $undoId -Message $message
        }
        catch {
            $message = "Nie udało się zapisać ustawień {0}: {1}" -f ($names -join ', '), $_.Exception.Message
            Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $common.Operation -ComputerName $computerName -Message $message
            return New-MwpResult @common -Success $false -Before $beforeValues -Message $message -ErrorMessage $_.Exception.Message
        }
    }
    $common = @{ Operation = 'Settings.Set'; Target = $Name; ComputerName = $computerName }

    $data = Read-MwpSettingsData
    foreach ($warning in $data.Warnings) {
        Write-Warning $warning
    }

    if ($Name -eq 'schemaVersion') {
        return New-MwpResult @common -Success $false -Message 'Ustawienia schemaVersion nie zmienia się ręcznie; zmienia ją migracja.'
    }
    if (-not $data.Defaults.Contains($Name)) {
        return New-MwpResult @common -Success $false -Message ("Nieznane ustawienie '{0}'." -f $Name)
    }
    if (-not (Test-MwpSettingValueType -Default $data.Defaults[$Name] -Value $Value)) {
        $expected = if ($null -eq $data.Defaults[$Name]) { 'dowolny' } else { $data.Defaults[$Name].GetType().Name }
        return New-MwpResult @common -Success $false -Message ("Niepoprawny typ wartości ustawienia '{0}' (oczekiwany: {1})." -f $Name, $expected)
    }

    $before = $data.Settings[$Name]
    $target = Format-MwpOperationTarget -Target ("ustawienie '{0}'" -f $Name) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Zmiana wartości z '{0}' na '{1}'" -f $before, $Value))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $Value `
            -Message ("Podgląd: ustawienie '{0}' zmieni wartość z '{1}' na '{2}'." -f $Name, $before, $Value)
    }

    try {
        # Pierwszy zapis: gdy folder config jest niezapisywalny, plik trafia do katalogu zapasowego (D-032).
        Write-MwpLocalSetting -Values @{ $Name = $Value } -Data $data

        $undoId = $null
        if (-not $NoUndo) {
            $undo = Save-MwpUndoEntry -Module 'MWP.Core' -Operation $common.Operation -Target $Name -ComputerName $computerName `
                -Description ("Przywrócenie ustawienia '{0}' do wartości '{1}'" -f $Name, $before) `
                -Before $before -After $Value -UndoCommand 'Set-MwpSetting' -UndoParameters @{ Name = $Name; Value = $before }
            $undoId = $undo.Id
        }

        $message = "Ustawienie '{0}' zmienione z '{1}' na '{2}'." -f $Name, $before, $Value
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $common.Operation -ComputerName $computerName -Message $message `
            -Data @{ Name = $Name; Before = $before; After = $Value; UndoId = $undoId }
        New-MwpResult @common -Success $true -Changed ([string]$before -ne [string]$Value) -Before $before -After $Value `
            -UndoId $undoId -Message $message
    }
    catch {
        $message = "Nie udało się zapisać ustawienia '{0}': {1}" -f $Name, $_.Exception.Message
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $common.Operation -ComputerName $computerName -Message $message
        New-MwpResult @common -Success $false -Before $before -Message $message -ErrorMessage $_.Exception.Message
    }
}
