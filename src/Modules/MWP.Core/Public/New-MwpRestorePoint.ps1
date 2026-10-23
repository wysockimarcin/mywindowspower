function New-MwpRestorePoint {
    <#
    .SYNOPSIS
        Tworzy punkt przywracania systemu przed grupą ryzykownych zmian, lokalnie albo zdalnie.

    .DESCRIPTION
        Używa CIM (root/default:SystemRestore.CreateRestorePoint), bo Checkpoint-Computer nie
        istnieje w PowerShell 7. Wymaga uprawnień administratora (na komputerze docelowym)
        i włączonej ochrony systemu. Obsługiwane sytuacje (bez wyjątku, zawsze obiekt MWP.Result):
        - brak uprawnień administratora — Success = $false,
        - ochrona systemu wyłączona (kod 1058) albo inny kod błędu — Success = $false,
        - limit częstotliwości Windows (domyślnie jeden punkt na 24 godziny): Windows nie tworzy
          nowego punktu — Success = $true, Changed = $false, z wyjaśnieniem,
        - brak połączenia z komputerem zdalnym — Success = $false (stan połączenia w kontekście).
        Komputer zdalny wymaga kontekstu wykonania (-Context z New-MwpExecutionContext, MWP.Remote):
        punkt powstaje na komputerze docelowym przez Invoke-MwpOnTarget (D-019, FAZA 3), a log
        zostaje na komputerze lokalnym. Sama nazwa komputera (-ComputerName) obsługuje tylko
        komputer lokalny. Funkcja nie zmienia ustawień ochrony systemu ani limitu częstotliwości.

    .PARAMETER ComputerName
        Komputer docelowy bez kontekstu; domyślnie 'localhost'. Rozwiązanie przejściowe (D-019),
        dla komputera zdalnego użyj -Context.

    .PARAMETER Context
        Kontekst wykonania (MWP.ExecutionContext) z komputerem docelowym.

    .EXAMPLE
        New-MwpRestorePoint -Description 'MyWindowsPower: przed zmianą tweaków' -WhatIf

    .EXAMPLE
        New-MwpRestorePoint -Description 'MyWindowsPower: przed zmianą usług' -Context $context -Confirm
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByName')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 256)]
        [string] $Description,

        [ValidateSet('ModifySettings', 'ApplicationInstall', 'ApplicationUninstall')]
        [string] $Type = 'ModifySettings',

        [Parameter(ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [Parameter(Mandatory, ParameterSetName = 'ByContext')]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context
    )

    $isLocal = $true
    if ($PSCmdlet.ParameterSetName -eq 'ByContext') {
        $ComputerName = $Context.ComputerName
        $isLocal = $Context.Mode -eq 'Local'
    }
    else {
        $isLocal = Test-MwpLocalComputer -ComputerName $ComputerName
    }

    $operation = 'Core.RestorePoint'
    $common = @{ Operation = $operation; Target = $Description; ComputerName = $ComputerName }
    $typeCodes = @{ ApplicationInstall = 0; ApplicationUninstall = 1; ModifySettings = 12 }

    $fail = {
        param($Message, $ErrorMessage)
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -ComputerName $ComputerName -Message $Message
        New-MwpResult @common -Success $false -Message $Message -ErrorMessage $ErrorMessage
    }

    # Zdalnie: blok wykonywany na komputerze docelowym (Windows PowerShell 5.1, bez modułów MWP).
    $remoteAdminScript = {
        $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
        $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    $remoteCreateScript = {
        param($PointDescription, $TypeCode)
        $latest = {
            $point = @(Get-CimInstance -Namespace 'root/default' -ClassName 'SystemRestore' -ErrorAction Stop) |
                Sort-Object -Property SequenceNumber -Descending | Select-Object -First 1
            if ($null -ne $point) {
                @{ SequenceNumber = [long]$point.SequenceNumber; Description = [string]$point.Description; CreationTime = [string]$point.CreationTime }
            }
        }
        $pointBefore = & $latest
        $arguments = @{ Description = $PointDescription; RestorePointType = [uint32]$TypeCode; EventType = [uint32]100 }
        $response = Invoke-CimMethod -Namespace 'root/default' -ClassName 'SystemRestore' -MethodName 'CreateRestorePoint' -Arguments $arguments -ErrorAction Stop
        @{ Code = [int]$response.ReturnValue; Before = $pointBefore; After = (& $latest) }
    }
    $toPoint = {
        param($Point)
        if ($null -ne $Point) {
            [pscustomobject]@{
                SequenceNumber = [long]$Point['SequenceNumber']
                Description    = [string]$Point['Description']
                CreationTime   = [string]$Point['CreationTime']
            }
        }
    }

    $invokeOnTarget = $null
    if ($isLocal) {
        if (-not (Test-MwpAdmin)) {
            return & $fail 'Utworzenie punktu przywracania wymaga uprawnień administratora.' $null
        }
    }
    else {
        if ($PSCmdlet.ParameterSetName -ne 'ByContext') {
            return & $fail ("Punkt przywracania na komputerze zdalnym '{0}' wymaga kontekstu wykonania (-Context, New-MwpExecutionContext z modułu MWP.Remote)." -f $ComputerName) $null
        }
        $invokeOnTarget = Get-Command -Name 'Invoke-MwpOnTarget' -CommandType Function -ErrorAction SilentlyContinue
        if ($null -eq $invokeOnTarget) {
            return & $fail ("Punkt przywracania na komputerze zdalnym '{0}' wymaga modułu MWP.Remote (nie jest załadowany)." -f $ComputerName) $null
        }
        $check = & $invokeOnTarget -Context $Context -Operation 'Core.RestorePoint.CheckAdmin' -ScriptBlock $remoteAdminScript
        if (-not $check.Success) {
            return & $fail ("Nie udało się sprawdzić uprawnień na komputerze '{0}': {1}" -f $ComputerName, $check.Message) $check.ErrorMessage
        }
        if (-not (@($check.Data) -contains $true)) {
            return & $fail ("Utworzenie punktu przywracania wymaga uprawnień administratora na komputerze '{0}'." -f $ComputerName) $null
        }
    }

    $target = Format-MwpOperationTarget -Target ("punkt przywracania '{0}'" -f $Description) -ComputerName $ComputerName
    if (-not $PSCmdlet.ShouldProcess($target, 'Utworzenie punktu przywracania systemu')) {
        return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd: zostanie utworzony punkt przywracania '{0}' na komputerze '{1}'." -f $Description, $ComputerName)
    }

    try {
        if ($isLocal) {
            $before = Get-MwpLatestRestorePoint
            $arguments = @{
                Description      = $Description
                RestorePointType = [uint32]$typeCodes[$Type]
                EventType        = [uint32]100
            }
            $response = Invoke-CimMethod -Namespace 'root/default' -ClassName 'SystemRestore' -MethodName 'CreateRestorePoint' -Arguments $arguments -ErrorAction Stop
            $code = [int]$response.ReturnValue
            $after = $null
            if ($code -eq 0) {
                $after = Get-MwpLatestRestorePoint
            }
        }
        else {
            $run = & $invokeOnTarget -Context $Context -Operation $operation -ScriptBlock $remoteCreateScript -ArgumentList $Description, $typeCodes[$Type]
            if (-not $run.Success) {
                return & $fail ("Nie udało się utworzyć punktu przywracania na komputerze '{0}': {1}" -f $ComputerName, $run.Message) $run.ErrorMessage
            }
            $remote = @($run.Data | Where-Object { $_ -is [Collections.IDictionary] }) | Select-Object -Last 1
            if ($null -eq $remote) {
                return & $fail ("Komputer '{0}' nie zwrócił wyniku utworzenia punktu przywracania." -f $ComputerName) $null
            }
            $code = [int]$remote['Code']
            $before = & $toPoint $remote['Before']
            $after = & $toPoint $remote['After']
        }

        if ($code -eq 1058) {
            return & $fail 'Ochrona systemu jest wyłączona (kod 1058). Włącz ją dla dysku systemowego, aby tworzyć punkty przywracania.' "Kod $code"
        }
        if ($code -ne 0) {
            return & $fail ("Nie udało się utworzyć punktu przywracania (kod {0})." -f $code) "Kod $code"
        }

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
