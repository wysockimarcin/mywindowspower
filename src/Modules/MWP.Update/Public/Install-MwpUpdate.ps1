function Install-MwpUpdate {
    <#
    .SYNOPSIS
        Pobiera i instaluje wybrane oczekujące aktualizacje na komputerze lokalnym przez Windows Update Agent (COM), bez automatycznego restartu.

    .DESCRIPTION
        Operacja klasy Destrukcyjna (D-027, D-048): ConfirmImpact High — bez -Confirm:$false funkcja
        zawsze pyta; podgląd (-WhatIf) wymienia aktualizacje. Tylko komputer lokalny: Windows Update
        Agent nie pozwala tworzyć IUpdateDownloader/IUpdateInstaller w sesji zdalnej (WinRM), a obejścia
        nie dodajemy (D-048) — dla komputera zdalnego wynik z błędem i odesłaniem do Ustawień na tamtym
        komputerze. Wymaga administratora. Przebieg: ponowne wyszukanie (aktualizacje są wybierane po
        UpdateID z bieżących wyników, nie z tekstu), potem po jednej aktualizacji: pobranie (gdy nie jest
        pobrana) i instalacja. Aktualizacje wymagające interakcji użytkownika albo akceptacji licencji
        są pomijane z odesłaniem do Ustawień Windows Update. Postęp i anulowanie (między aktualizacjami)
        przez tabelę -Progress (Percent, Message, CancelRequested). Restart nie jest wykonywany —
        RestartRequired w wyniku. Bez wpisu cofnięcia (odinstalowanie aktualizacji: Ustawienia →
        Historia aktualizacji). Log początku i wyniku.

    .PARAMETER UpdateId
        Identyfikatory aktualizacji (GUID, pole UpdateId z Find-MwpUpdate).

    .PARAMETER Update
        Aktualizacje z Find-MwpUpdate (MWP.UpdateItem) — tytuły trafiają do podglądu.

    .PARAMETER Progress
        Tabela postępu (Percent, Message, CancelRequested).

    .EXAMPLE
        $found = (Find-MwpUpdate -Type Software).Data.Updates
        Install-MwpUpdate -Update $found -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'ById')]
        [ValidateScript({ $guid = [guid]::Empty; [guid]::TryParse($_, [ref]$guid) })]
        [string[]] $UpdateId,

        [Parameter(Mandatory, ParameterSetName = 'ByObject')]
        [PSTypeName('MWP.UpdateItem')]
        [object[]] $Update,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [AllowNull()]
        [hashtable] $Progress
    )

    $operation = 'Update.Install'
    $computerName = $Context.ComputerName
    $common = @{ Operation = $operation; Target = 'Windows Update'; ComputerName = $computerName }
    if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
        foreach ($item in $Update) {
            $guid = [guid]::Empty
            if (-not [guid]::TryParse([string]$item.UpdateId, [ref]$guid)) {
                return New-MwpResult @common -Success $false -Message ("Niepoprawny identyfikator aktualizacji '{0}'." -f $item.UpdateId)
            }
        }
        $ids = @($Update | ForEach-Object { ([string]$_.UpdateId).ToLowerInvariant() })
        $titles = @($Update | ForEach-Object { [string]$_.Title })
    }
    else {
        $ids = @($UpdateId | ForEach-Object { ([guid]$_).ToString() })
        $titles = $ids
    }
    $ids = @($ids | Select-Object -Unique)
    if ($Context.Mode -ne 'Local') {
        return New-MwpResult @common -Success $false `
            -Message ("Instalacja aktualizacji na komputerze zdalnym '{0}' jest niedostępna: Windows Update Agent nie pozwala pobierać ani instalować aktualizacji w sesji zdalnej (WinRM). Zainstaluj je w Ustawieniach Windows Update na tym komputerze (D-048)." -f $computerName)
    }
    if (-not (Test-MwpAdmin)) {
        return New-MwpResult @common -Success $false -Message 'Instalacja aktualizacji wymaga uprawnień administratora (uruchom aplikację jako administrator).'
    }
    $list = @($titles | ForEach-Object { '- ' + $_ }) -join [Environment]::NewLine
    $target = Format-MwpOperationTarget -Target ('{0} aktualizacji Windows Update' -f $ids.Count) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Pobranie i instalacja (bez automatycznego restartu):{0}{1}' -f [Environment]::NewLine, $list))) {
        return New-MwpResult @common -Success $true -IsPreview -After $titles `
            -Message ("Podgląd: pobranie i instalacja {0} aktualizacji na komputerze '{1}' (restart nie jest wykonywany automatycznie):{2}{3}" -f $ids.Count, $computerName, [Environment]::NewLine, $list)
    }

    Write-MwpLog -Level Info -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message ('Instalacja aktualizacji: start ({0}).' -f $ids.Count) -Data @{ UpdateIds = $ids; Titles = $titles }
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            UpdateIds           = $ids
            Criteria            = Get-MwpUpdateSearchFilter -Type All
            ClientApplicationId = 'MyWindowsPower'
        })
    $result = Invoke-MwpOnTarget -Context $Context -Operation $operation -ScriptBlock (Get-MwpUpdateScript -Name Install) -ArgumentList @($request, $Progress) -TimeoutSeconds 14400
    $raw = if ($result.Success) { ConvertFrom-MwpUpdateJson -Data $result -Kind 'MWP.UpdateInstallRaw' } else { $null }
    if ($null -eq $raw) {
        $message = "Instalacja aktualizacji na komputerze '{0}' nie powiodła się: {1}" -f $computerName, $(if ($result.Success) { 'brak wyniku Windows Update Agent' } else { $result.Message })
        Write-MwpLog -Level Error -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $result.ErrorMessage
    }

    $statusText = @{ Installed = 'zainstalowano'; Failed = 'niepowodzenie'; Skipped = 'pominięto'; Cancelled = 'anulowano'; NotFound = 'nie znaleziono' }
    $items = @(foreach ($item in @($raw.Items | Where-Object { $null -ne $_ })) {
            $hint = Get-MwpUpdateText -Kind HResult -Value $item.HResult
            [pscustomobject]@{
                PSTypeName     = 'MWP.UpdateInstallItem'
                UpdateId       = [string]$item.UpdateId
                Title          = $(if ($item.Title) { [string]$item.Title } else { [string]$item.UpdateId })
                Status         = [string]$item.Status
                StatusText     = $statusText[[string]$item.Status]
                ResultText     = $(if ($null -ne $item.ResultCode) { Get-MwpUpdateText -Kind ResultCode -Value $item.ResultCode } else { '' })
                HResult        = $(if ($item.HResult -and $item.HResult -ne '0x00000000') { [string]$item.HResult } else { '' })
                Reason         = (@([string]$item.Reason, $hint) | Where-Object { $_ }) -join ' — '
                RebootRequired = [bool]$item.RebootRequired
            }
        })
    $installed = @($items | Where-Object { $_.Status -eq 'Installed' })
    $failed = @($items | Where-Object { $_.Status -eq 'Failed' })
    $other = @($items | Where-Object { $_.Status -notin 'Installed', 'Failed' })
    $summary = 'zainstalowano {0}, niepowodzenia {1}, pominięto {2}' -f $installed.Count, $failed.Count, $other.Count
    $details = @($items | ForEach-Object { '{0}: {1}{2}' -f $_.Title, $_.StatusText, $(if ($_.Reason) { ' (' + $_.Reason + ')' } else { '' }) }) -join [Environment]::NewLine
    $reboot = [bool]$raw.RebootRequired
    $data = [pscustomobject]@{ PSTypeName = 'MWP.UpdateInstall'; Items = $items; RebootRequired = $reboot; Cancelled = [bool]$raw.Cancelled; Summary = $summary }
    if ($raw.Error) {
        $hint = Get-MwpUpdateText -Kind HResult -Value $raw.HResult
        $message = "Instalacja aktualizacji na komputerze '{0}' nie powiodła się: {1} ({2}{3}); {4}." -f $computerName, $raw.Error, $raw.HResult, $(if ($hint) { ': ' + $hint } else { '' }), $summary
        Write-MwpLog -Level Error -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Details = $details }
        return New-MwpResult @common -Success $false -Changed ($installed.Count -gt 0) -RestartRequired:$reboot -Message $message -ErrorMessage $details -Data $data
    }
    $message = "Instalacja aktualizacji na komputerze '{0}': {1}.{2}{3}" -f $computerName, $summary, $(if ($raw.Cancelled) { ' Anulowano przed końcem.' } else { '' }), $(if ($reboot) { ' Wymagany restart — uruchom komputer ponownie w dogodnym momencie.' } else { '' })
    Write-MwpLog -Level $(if ($failed.Count -gt 0) { 'Warning' } else { 'Info' }) -Source 'MWP.Update' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Details = $details }
    New-MwpResult @common -Success ($failed.Count -eq 0) -Changed ($installed.Count -gt 0) -RestartRequired:$reboot -After $summary -Message $message -ErrorMessage $(if ($failed.Count -gt 0) { $details } else { $null }) -Data $data
}
