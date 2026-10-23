function Invoke-MwpUndo {
    <#
    .SYNOPSIS
        Cofa zmianę zapisaną w rejestrze cofnięć.

    .DESCRIPTION
        Wywołuje polecenie przywracające zapisane we wpisie (UndoCommand z UndoParameters).
        Komputer docelowy (D-019): gdy podano -Context (kontekst wykonania z MWP.Remote), musi on
        dotyczyć komputera z wpisu i jest przekazywany poleceniu, które ma parametr Context.
        Bez kontekstu: polecenie z parametrem ComputerName dostaje komputer z wpisu; wpisu
        z komputera zdalnego dla polecenia, które wymaga kontekstu, nie da się cofnąć bez -Context. Obsługuje -WhatIf i -Confirm; potwierdzenie zawiera nazwę komputera.
        Po udanym cofnięciu wpis dostaje status Undone; po nieudanym zostaje Pending z opisem
        błędu (można ponowić). Samo cofnięcie jest zwykłą zmianą, więc polecenie przywracające
        zapisuje własny wpis cofnięcia.

    .PARAMETER Context
        Kontekst wykonania (MWP.ExecutionContext) komputera, na którym wykonano zmianę.

    .EXAMPLE
        Get-MwpUndoEntry -Status Pending | Select-Object -First 1 | Invoke-MwpUndo -WhatIf

    .EXAMPLE
        Invoke-MwpUndo -Id $result.UndoId -Context $context
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ById')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByEntry')]
        [PSTypeName('MWP.UndoEntry')]
        [object] $InputObject,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context
    )

    process {
        $operation = 'Undo.Invoke'
        $entryId = if ($PSCmdlet.ParameterSetName -eq 'ByEntry') { $InputObject.Id } else { $Id }

        $entry = Get-MwpUndoEntry -Id $entryId
        if ($null -eq $entry) {
            return New-MwpResult -Success $false -Operation $operation -Target $entryId -Message ("Nie znaleziono wpisu cofnięcia '{0}'." -f $entryId)
        }

        $common = @{ Operation = $operation; Target = $entry.Target; ComputerName = $entry.ComputerName; UndoId = $entry.Id }
        if ($entry.Status -ne 'Pending') {
            return New-MwpResult @common -Success $false -Message ("Wpis {0} został już cofnięty ({1})." -f $entry.Id, $entry.UndoneAt)
        }

        $command = Get-Command -Name $entry.UndoCommand -CommandType Function, Cmdlet -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $command) {
            return New-MwpResult @common -Success $false `
                -Message ("Polecenie cofające '{0}' nie jest dostępne; zaimportuj moduł {1}." -f $entry.UndoCommand, $entry.Module)
        }

        $parameters = @{}
        foreach ($key in $entry.UndoParameters.Keys) {
            $parameters[$key] = $entry.UndoParameters[$key]
        }
        $entryIsLocal = Test-MwpLocalComputer -ComputerName $entry.ComputerName
        if ($null -ne $Context) {
            $sameComputer = if ($entryIsLocal) { $Context.Mode -eq 'Local' } else { $Context.ComputerName -eq $entry.ComputerName }
            if (-not $sameComputer) {
                return New-MwpResult @common -Success $false `
                    -Message ("Kontekst dotyczy komputera '{0}', a wpis {1} — komputera '{2}'." -f $Context.ComputerName, $entry.Id, $entry.ComputerName)
            }
        }
        if ($command.Parameters.ContainsKey('Context')) {
            $parameters.Remove('ComputerName')
            if ($null -ne $Context) {
                $parameters['Context'] = $Context
            }
            elseif (-not $entryIsLocal) {
                return New-MwpResult @common -Success $false `
                    -Message ("Cofnięcie zmiany na komputerze zdalnym '{0}' wymaga kontekstu wykonania (-Context)." -f $entry.ComputerName)
            }
        }
        elseif ($command.Parameters.ContainsKey('ComputerName') -and -not $parameters.ContainsKey('ComputerName')) {
            $parameters['ComputerName'] = $entry.ComputerName
        }

        $target = Format-MwpOperationTarget -Target $entry.Target -ComputerName $entry.ComputerName
        $action = "Cofnięcie operacji {0}: {1}" -f $entry.Operation, $entry.Description
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            return New-MwpResult @common -Success $true -IsPreview -Before $entry.After -After $entry.Before `
                -Message ("Podgląd: {0} ({1} {2})." -f $action, $entry.UndoCommand, $target)
        }
        if ($command.Parameters.ContainsKey('Confirm')) {
            $parameters['Confirm'] = $false
        }

        try {
            $output = @(& $command @parameters)
            $inner = @($output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
            if ($null -ne $inner -and -not $inner.Success) {
                throw $inner.Message
            }

            Write-MwpUndoStatus -Path $entry.Path -Status Undone
            $message = "Cofnięto operację {0} ({1})." -f $entry.Operation, $entry.Target
            Write-MwpLog -Level Info -Source $entry.Module -Operation $operation -ComputerName $entry.ComputerName -Message $message -Data @{ UndoId = $entry.Id }
            New-MwpResult @common -Success $true -Changed $true -Before $entry.After -After $entry.Before -Message $message
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-MwpUndoStatus -Path $entry.Path -Status Pending -ErrorMessage $errorMessage
            $message = "Nie udało się cofnąć operacji {0} ({1}): {2}" -f $entry.Operation, $entry.Target, $errorMessage
            Write-MwpLog -Level Error -Source $entry.Module -Operation $operation -ComputerName $entry.ComputerName -Message $message -Data @{ UndoId = $entry.Id }
            New-MwpResult @common -Success $false -Message $message -ErrorMessage $errorMessage
        }
    }
}
