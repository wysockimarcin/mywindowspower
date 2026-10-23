function New-MwpRestorePoint {
    <#
    .SYNOPSIS
        Tworzy punkt przywracania systemu przed grupą ryzykownych zmian.

    .DESCRIPTION
        Używa CIM (root/default:SystemRestore.CreateRestorePoint), bo Checkpoint-Computer nie
        istnieje w PowerShell 7. Wymaga uprawnień administratora i włączonej ochrony systemu.
        Obsługiwane sytuacje (bez wyjątku, zawsze obiekt MWP.Result):
        - brak uprawnień administratora — Success = $false,
        - ochrona systemu wyłączona (kod 1058) albo inny kod błędu — Success = $false,
        - limit częstotliwości Windows (domyślnie jeden punkt na 24 godziny): Windows nie tworzy
          nowego punktu — Success = $true, Changed = $false, z wyjaśnieniem.
        Na komputerze zdalnym na razie niedostępne (kontekst wykonania i transport: FAZA 3).
        Funkcja nie zmienia ustawień ochrony systemu ani limitu częstotliwości.

    .PARAMETER ComputerName
        Komputer docelowy; domyślnie 'localhost' (D-019).

    .EXAMPLE
        New-MwpRestorePoint -Description 'MyWindowsPower: przed zmianą tweaków' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 256)]
        [string] $Description,

        [ValidateSet('ModifySettings', 'ApplicationInstall', 'ApplicationUninstall')]
        [string] $Type = 'ModifySettings',

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost'
    )

    $operation = 'Core.RestorePoint'
    $common = @{ Operation = $operation; Target = $Description; ComputerName = $ComputerName }
    $typeCodes = @{ ApplicationInstall = 0; ApplicationUninstall = 1; ModifySettings = 12 }

    $fail = {
        param($Message, $ErrorMessage)
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -ComputerName $ComputerName -Message $Message
        New-MwpResult @common -Success $false -Message $Message -ErrorMessage $ErrorMessage
    }

    if (-not (Test-MwpLocalComputer -ComputerName $ComputerName)) {
        return & $fail ("Punkt przywracania na komputerze zdalnym '{0}' nie jest jeszcze obsługiwany (FAZA 3)." -f $ComputerName) $null
    }
    if (-not (Test-MwpAdmin)) {
        return & $fail 'Utworzenie punktu przywracania wymaga uprawnień administratora.' $null
    }

    $target = Format-MwpOperationTarget -Target ("punkt przywracania '{0}'" -f $Description) -ComputerName $ComputerName
    if (-not $PSCmdlet.ShouldProcess($target, 'Utworzenie punktu przywracania systemu')) {
        return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd: zostanie utworzony punkt przywracania '{0}'." -f $Description)
    }

    try {
        $before = Get-MwpLatestRestorePoint
        $arguments = @{
            Description      = $Description
            RestorePointType = [uint32]$typeCodes[$Type]
            EventType        = [uint32]100
        }
        $response = Invoke-CimMethod -Namespace 'root/default' -ClassName 'SystemRestore' -MethodName 'CreateRestorePoint' -Arguments $arguments -ErrorAction Stop
        $code = [int]$response.ReturnValue
        if ($code -eq 1058) {
            return & $fail 'Ochrona systemu jest wyłączona (kod 1058). Włącz ją dla dysku systemowego, aby tworzyć punkty przywracania.' "Kod $code"
        }
        if ($code -ne 0) {
            return & $fail ("Nie udało się utworzyć punktu przywracania (kod {0})." -f $code) "Kod $code"
        }

        $after = Get-MwpLatestRestorePoint
        if ($null -ne $after -and ($null -eq $before -or $after.SequenceNumber -ne $before.SequenceNumber)) {
            $message = "Utworzono punkt przywracania '{0}' (numer {1})." -f $Description, $after.SequenceNumber
            Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $operation -ComputerName $ComputerName -Message $message
            return New-MwpResult @common -Success $true -Changed $true -Before $before -After $after -Message $message
        }

        $message = 'Windows nie utworzył nowego punktu przywracania: najpewniej od ostatniego minęło mniej niż 24 godziny (limit częstotliwości). Ostatni punkt pozostaje aktualny.'
        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation $operation -ComputerName $ComputerName -Message $message
        New-MwpResult @common -Success $true -Changed $false -Before $before -After $after -Message $message
    }
    catch {
        & $fail ("Nie udało się utworzyć punktu przywracania (sprawdź, czy ochrona systemu jest włączona): {0}" -f $_.Exception.Message) $_.Exception.Message
    }
}
