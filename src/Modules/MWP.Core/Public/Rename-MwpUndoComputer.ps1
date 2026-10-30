function Rename-MwpUndoComputer {
    <#
    .SYNOPSIS
        Przepisuje komputer we wpisach cofnięcia (status Pending) ze starej nazwy na nową — przy zmianie nazwy komputera (D-054).

    .DESCRIPTION
        Wpis cofnięcia jest powiązany z komputerem przez pole computerName, a Invoke-MwpUndo wymaga
        kontekstu tego samego komputera. Gdy komputer zapisany pod adresem IP dostaje nazwę
        (Set-MwpTarget -NewName), wpisy oczekujące na cofnięcie przechodzą na nową nazwę, inaczej zmian
        sprzed zmiany nazwy nie dałoby się cofnąć. Zmienia tylko pole computerName wpisów Pending; każdy
        plik zapisywany atomowo (Write-MwpJsonFile). Wpisy uszkodzone i nieudane zapisy są zgłaszane
        w Data.Failed, bez przerywania pozostałych. Operacja na danych aplikacji (komputer lokalny):
        -WhatIf, log, bez własnego wpisu cofnięcia.

    .EXAMPLE
        Rename-MwpUndoComputer -OldName '192.0.2.10' -NewName 'PC-BIURO' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $OldName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $NewName
    )

    $operation = 'Undo.RenameComputer'
    $common = @{ Operation = $operation; Target = ("wpisy cofnięcia komputera '{0}'" -f $OldName); ComputerName = 'localhost' }
    $renamed = New-Object -TypeName System.Collections.Generic.List[string]
    $failed = New-Object -TypeName System.Collections.Generic.List[string]
    $matching = New-Object -TypeName System.Collections.Generic.List[object]

    $directory = Get-MwpDataPath -Kind Undo
    if (Test-Path -LiteralPath $directory) {
        foreach ($file in @(Get-ChildItem -LiteralPath $directory -Filter '*.json' -File)) {
            try {
                $data = ConvertTo-MwpHashtable -InputObject (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
            }
            catch {
                $failed.Add(('{0}: {1}' -f $file.Name, $_.Exception.Message))
                continue
            }
            if ([string]$data['computerName'] -eq $OldName -and [string]$data['status'] -eq 'Pending') {
                $matching.Add([pscustomobject]@{ Path = $file.FullName; Name = $file.Name; Data = $data })
            }
        }
    }

    if ($matching.Count -eq 0) {
        return New-MwpResult @common -Success ($failed.Count -eq 0) -Message ("Brak wpisów cofnięcia komputera '{0}' do przepisania." -f $OldName) `
            -Data ([ordered]@{ Renamed = @(); Failed = $failed.ToArray() })
    }
    $target = Format-MwpOperationTarget -Target ("{0} wpisów cofnięcia: '{1}' -> '{2}'" -f $matching.Count, $OldName, $NewName) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Przepisanie komputera we wpisach cofnięcia')) {
        return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd: {0} wpisów cofnięcia przejdzie z '{1}' na '{2}'." -f $matching.Count, $OldName, $NewName) `
            -Data ([ordered]@{ Renamed = @($matching | ForEach-Object { $_.Name }); Failed = $failed.ToArray() })
    }

    foreach ($item in $matching) {
        try {
            $item.Data['computerName'] = $NewName
            Write-MwpJsonFile -Path $item.Path -InputObject $item.Data
            $renamed.Add($item.Name)
        }
        catch {
            $failed.Add(('{0}: {1}' -f $item.Name, $_.Exception.Message))
        }
    }

    $message = "Przepisano {0} wpisów cofnięcia z komputera '{1}' na '{2}'." -f $renamed.Count, $OldName, $NewName
    if ($failed.Count -gt 0) {
        $message = '{0} Nie udało się: {1}.' -f $message, ($failed -join '; ')
    }
    $level = if ($failed.Count -gt 0) { 'Warning' } else { 'Info' }
    Write-MwpLog -Level $level -Source 'MWP.Core' -Operation $operation -ComputerName 'localhost' -Message $message
    New-MwpResult @common -Success ($failed.Count -eq 0) -Changed ($renamed.Count -gt 0) -Message $message `
        -Data ([ordered]@{ Renamed = $renamed.ToArray(); Failed = $failed.ToArray() })
}
