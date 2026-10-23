function Set-MwpSetting {
    <#
    .SYNOPSIS
        Zmienia ustawienie aplikacji w config\settings.local.json (zapis atomowy, z cofnięciem).

    .DESCRIPTION
        Przykład wzorca funkcji zmieniającej stan (ARCHITEKTURA.md, „Wzorzec funkcji zmieniającej
        system"): walidacja, -WhatIf/-Confirm, zapis atomowy, wpis w rejestrze cofnięć, log
        i obiekt MWP.Result. Dozwolone są tylko ustawienia z szablonu, z wartością tego samego
        typu; schemaVersion zmienia wyłącznie migracja. Ustawienia aplikacji należą do hosta,
        więc komputer docelowy to zawsze 'localhost'.

    .EXAMPLE
        Set-MwpSetting -Name logLevel -Value 'Debug' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, Position = 1)]
        [AllowNull()]
        [AllowEmptyString()]
        [object] $Value
    )

    $computerName = 'localhost'
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
        $local = [ordered]@{ schemaVersion = $data.Defaults['schemaVersion'] }
        foreach ($key in $data.Local.Keys) {
            if ($key -ne 'schemaVersion') {
                $local[$key] = $data.Local[$key]
            }
        }
        $local[$Name] = $Value
        Write-MwpJsonFile -Path $data.Paths.Local -InputObject $local

        $undo = Save-MwpUndoEntry -Module 'MWP.Core' -Operation $common.Operation -Target $Name -ComputerName $computerName `
            -Description ("Przywrócenie ustawienia '{0}' do wartości '{1}'" -f $Name, $before) `
            -Before $before -After $Value -UndoCommand 'Set-MwpSetting' -UndoParameters @{ Name = $Name; Value = $before }

        $message = "Ustawienie '{0}' zmienione z '{1}' na '{2}'." -f $Name, $before, $Value
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $common.Operation -ComputerName $computerName -Message $message `
            -Data @{ Name = $Name; Before = $before; After = $Value; UndoId = $undo.Id }
        New-MwpResult @common -Success $true -Changed ([string]$before -ne [string]$Value) -Before $before -After $Value `
            -UndoId $undo.Id -Message $message
    }
    catch {
        $message = "Nie udało się zapisać ustawienia '{0}': {1}" -f $Name, $_.Exception.Message
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $common.Operation -ComputerName $computerName -Message $message
        New-MwpResult @common -Success $false -Before $before -Message $message -ErrorMessage $_.Exception.Message
    }
}
