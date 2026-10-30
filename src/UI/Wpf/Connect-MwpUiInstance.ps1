function Connect-MwpUiInstance {
    <#
    .SYNOPSIS
        Łączy instancję z komputerem zdalnym w tle; w razie potrzeby najpierw pyta o poświadczenia.

    .DESCRIPTION
        Okno poświadczeń wyświetla warstwa UI (D-034). Skąd wziąć hasło, decyduje
        Get-MwpUiCredentialPlan (D-052): sprawdzone hasło komputera z pamięci procesu albo wpis
        z Menedżera poświadczeń — bez okna; w pozostałych przypadkach okno z polem „Zapamiętaj”
        (domyślnie wyłączonym). Samo połączenie (Connect-MwpTarget, także odczyt i zapis magazynu)
        działa w zadaniu w tle, więc okno nie czeka na limit czasu niedostępnego komputera. Stan
        połączenia zmienia się w kontekście tej instancji; inne instancje i widoki działają dalej
        (D-019). Po udanym połączeniu widgety tego komputera czekające na poświadczenia są wznawiane,
        a pozostałe instancje tego komputera łączą się same (Connect-MwpUiTargetInstance).
        Wynik trafia do widoku instancji.

    .PARAMETER Automatic
        Połączenie bez akcji użytkownika: tylko gdy nie trzeba pytać o hasło (sprawdzone hasło
        w pamięci procesu albo poświadczenie w kontekście); nigdy okno ani Menedżer poświadczeń.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [AllowNull()]
        [object] $Owner,

        [switch] $Automatic
    )

    $ui = $script:MwpUi
    $context = $Entry.Instance.Context
    if ($context.Mode -eq 'Local') {
        return
    }
    if (-not $Automatic) {
        # Jawne „Połącz” znosi ręczne rozłączenie: instancja znów łączy się sama z resztą komputera.
        $Entry['ManualDisconnect'] = $false
    }
    elseif ([int]$Entry.Busy -gt 0 -or [string]$context.Connection.State -in @('Connected', 'Connecting')) {
        return
    }
    $state = Get-MwpConnectionStateInfo -Context $context
    $info = $null
    if ($context.Identity.Authentication -eq 'Credential' -and ($state.NeedsCredential -or $state.State -eq 'Unauthorized')) {
        # Automatycznie tylko pamięć procesu: bez odczytu Menedżera poświadczeń (to wymaga „Połącz”).
        $info = @(Get-MwpTargetCredentialInfo -Name $context.ComputerName -SkipStore:$Automatic) | Select-Object -First 1
    }
    $plan = Get-MwpUiCredentialPlan -State $state -Info $info -UserName $context.Identity.UserName
    if ($Automatic -and $plan.Action -notin @('None', 'Cache')) {
        return
    }
    $credential = $null
    $save = $false
    if ($plan.Action -eq 'Dialog') {
        $answer = Show-MwpCredentialDialog -ComputerName $context.ComputerName -UserName $plan.UserName -Owner $Owner -OfferSave:$plan.OfferSave -Notice $plan.Notice
        if ($null -eq $answer) {
            return
        }
        $credential = $answer.Credential
        $save = $answer.Save
    }

    $Entry.Busy++
    $Entry.Message = $null
    Update-MwpInstanceView -Entry $Entry -StateOnly
    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Łączenie: {0}' -f (Format-MwpTargetLabel -Context $context)) -State $Entry.Id -ArgumentList $context, $credential, ($plan.Action -eq 'Store'), $save -ScriptBlock {
        param($Progress, $Context, [System.Management.Automation.PSCredential] $Credential, [bool] $UseStored, [bool] $Save)
        $Progress.Message = $(if ($UseStored) { 'hasło z Menedżera poświadczeń, nawiązywanie sesji WinRM' } else { 'nawiązywanie sesji WinRM' })
        Connect-MwpTarget -Context $Context -Credential $Credential -UseStoredCredential:$UseStored -SaveCredential:$Save
    } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State]
        if ($null -eq $entry) {
            return
        }
        $entry.Busy = [Math]::Max(0, $entry.Busy - 1)
        $result = @($Task.Output | Where-Object { $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
        if ($Task.Status -ne 'Completed' -or $null -eq $result) {
            $entry.Message = 'Nie udało się połączyć: {0}' -f $(if ($Task.Error) { $Task.Error } else { $Task.Status })
        }
        elseif (-not $result.Success) {
            $entry.Message = $result.Message
        }
        else {
            $entry.Message = $null
            if ($null -ne $script:MwpUi.Dashboard) {
                $null = Resume-MwpUiTargetWidget -Widget @($script:MwpUi.Dashboard.Widgets) -ComputerName $entry.Instance.Context.ComputerName
            }
        }
        Update-MwpInstanceView -Entry $entry
        if ($null -ne $result -and $result.Success) {
            Connect-MwpUiTargetInstance -ComputerName $entry.Instance.Context.ComputerName
        }
    }
}
