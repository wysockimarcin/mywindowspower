function Invoke-MwpUiTargetTest {
    <#
    .SYNOPSIS
        Diagnostyka połączenia (Test-MwpTarget) w tle: dostępność, uwierzytelnienie, autoryzacja, administrator.

    .DESCRIPTION
        Dla instancji (-Entry) używa jej kontekstu; dla komputera z Ustawień (-Target) tworzy
        tymczasowy kontekst (z poświadczeniami z okna, jeśli są wymagane), testuje i rozłącza go
        w tym samym zadaniu. Wynik: blok -OnResult w wątku okna (domyślnie komunikat w widoku
        instancji albo okno komunikatu). Operacja klasy Odczyt.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Instance')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Instance')]
        [hashtable] $Entry,

        [Parameter(Mandatory, ParameterSetName = 'Target')]
        [object] $Target,

        [AllowNull()]
        [object] $Owner,

        [scriptblock] $OnResult
    )

    $ui = $script:MwpUi
    if ($PSCmdlet.ParameterSetName -eq 'Instance') {
        $context = $Entry.Instance.Context
        $state = Get-MwpConnectionStateInfo -Context $context
        if ($state.NeedsCredential) {
            Show-MwpMessage -Text ('Najpierw połącz instancję z komputerem {0} (przycisk „Połącz”), żeby podać poświadczenia.' -f (Format-MwpTargetLabel -Context $context)) -Owner $Owner
            return
        }
        $Entry.Busy++
        Update-MwpInstanceView -Entry $Entry -StateOnly
        $arguments = @($context, $null, $false)
        $taskState = @{ InstanceId = $Entry.Id; OnResult = $OnResult }
        $computerName = $context.ComputerName
    }
    else {
        $credential = $null
        if (-not $Target.IsLocal -and $Target.Authentication -eq 'Credential') {
            # Sprawdzone hasło komputera z pamięci procesu wystarcza (D-052); inaczej okno (bez zapisu).
            $info = @(Get-MwpTargetCredentialInfo -Name $Target.Name -SkipStore) | Select-Object -First 1
            if ($null -eq $info -or -not $info.Cached) {
                $answer = Show-MwpCredentialDialog -ComputerName $Target.Name -UserName $Target.UserName -Owner $Owner
                if ($null -eq $answer) {
                    return
                }
                $credential = $answer.Credential
            }
        }
        $arguments = @($Target.Name, $credential, $true)
        $taskState = @{ InstanceId = $null; OnResult = $OnResult }
        $computerName = $Target.Name
    }

    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Diagnostyka: {0}' -f $computerName) -State $taskState -ArgumentList $arguments -ScriptBlock {
        param($Progress, $ContextOrName, [System.Management.Automation.PSCredential] $Credential, [bool] $Temporary)
        $Progress.Message = 'sieć, uwierzytelnienie, autoryzacja'
        if ($Temporary) {
            $contextArguments = @{ ComputerName = [string]$ContextOrName }
            if ($null -ne $Credential) {
                $contextArguments['Credential'] = $Credential
            }
            $context = New-MwpExecutionContext @contextArguments
            try {
                Test-MwpTarget -Context $context
            }
            finally {
                $null = Disconnect-MwpTarget -Context $context
            }
        }
        else {
            Test-MwpTarget -Context $ContextOrName
        }
    } -OnCompleted {
        param($Task)
        $ui = $script:MwpUi
        $result = @($Task.Output | Where-Object { $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
        $text = if ($null -eq $result) {
            'Diagnostyka nie powiodła się: {0}' -f $(if ($Task.Error) { $Task.Error } else { $Task.Status })
        }
        else {
            $data = $result.Data
            $lines = @($result.Message)
            if ($null -ne $data) {
                $yesNo = { param($Value) if ($Value) { 'tak' } else { 'nie' } }
                $lines += 'Dostępny (WinRM): {0}; uwierzytelniony: {1}; autoryzowany: {2}; administrator: {3}; PowerShell na komputerze: {4}' -f
                (& $yesNo $data.Reachable), (& $yesNo $data.Authenticated), (& $yesNo $data.Authorized), (& $yesNo $data.IsAdministrator),
                $(if ($data.RemotePSVersion) { $data.RemotePSVersion } else { '?' })
                # D-054: adres połączenia, nazwa zgłoszona przez komputer i wartość do TrustedHosts (grupa robocza).
                if ($null -ne $data.PSObject.Properties['Address'] -and -not [string]::IsNullOrEmpty([string]$data.Address)) {
                    $nameState = switch ($data.NameMatches) { $true { 'zgodna' } $false { 'NIEZGODNA — operacje zablokowane' } default { 'bez porównania' } }
                    $lines += "Adres połączenia: {0}; nazwa zgłoszona przez komputer: {1} ({2}); adresy wykryte: {3}; TrustedHosts klienta (grupa robocza): '{4}'{5}" -f
                    $data.Address, $(if ($data.RemoteComputerName) { $data.RemoteComputerName } else { '?' }), $nameState,
                    $(if (@($data.DetectedAddresses).Count -gt 0) { @($data.DetectedAddresses) -join ', ' } else { '?' }), $data.TrustedHostsValue,
                    $(if ([string]$data.TrustedHostsValue -match '^\d{1,3}(\.\d{1,3}){3}$') { ' — przy adresie IP tylko NTLM' } else { '' })
                }
            }
            $lines -join [Environment]::NewLine
        }
        $entry = $null
        if ($Task.State.InstanceId) {
            $entry = $ui.Instances[[string]$Task.State.InstanceId]
            if ($null -ne $entry) {
                $entry.Busy = [Math]::Max(0, $entry.Busy - 1)
                $entry.View.Controls['ProbeText'].Text = $text
                Update-MwpInstanceView -Entry $entry
            }
        }
        if ($null -ne $Task.State.OnResult) {
            & $Task.State.OnResult $text
        }
        elseif ($null -eq $entry) {
            Show-MwpMessage -Text $text
        }
    }
}
