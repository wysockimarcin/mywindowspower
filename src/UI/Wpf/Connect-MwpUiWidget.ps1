function Connect-MwpUiWidget {
    <#
    .SYNOPSIS
        Łączy widget z komputerem zdalnym: poświadczenie (pamięć, magazyn albo okno), połączenie w tle, potem odświeżenie widgetu.

    .DESCRIPTION
        Jak dla instancji (Connect-MwpUiInstance, D-034, D-052): Get-MwpUiCredentialPlan wybiera
        sprawdzone hasło komputera z pamięci procesu, wpis z Menedżera poświadczeń albo okno
        poświadczeń (pole „Zapamiętaj” domyślnie wyłączone). Connect-MwpTarget działa w zadaniu w tle
        na kontekście instancji widgetu, więc okno nie czeka na limit czasu niedostępnego komputera.
        Sprawdzone hasło jest wspólne dla instancji i widgetów tego komputera do zamknięcia aplikacji;
        po udanym połączeniu pozostałe widgety tego komputera czekające na poświadczenia są wznawiane.
        Po odmowie dostępu widget zostaje w stanie „Wymaga poświadczeń” bez ponowień w tle.

    .PARAMETER Id
        Identyfikator widgetu.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    $widget = @($ui.Dashboard.Widgets | Where-Object { $_.Id -eq $Id -and -not $_.Removed }) | Select-Object -First 1
    if ($null -eq $widget -or $null -eq $widget.Instance) {
        return
    }
    $context = $widget.Instance.Context
    if ($context.Mode -eq 'Local') {
        $widget.Pending = $true
        return
    }
    $state = Get-MwpConnectionStateInfo -Context $context
    $info = $null
    if ($context.Identity.Authentication -eq 'Credential' -and ($state.NeedsCredential -or $state.State -eq 'Unauthorized')) {
        $info = @(Get-MwpTargetCredentialInfo -Name $context.ComputerName) | Select-Object -First 1
    }
    $plan = Get-MwpUiCredentialPlan -State $state -Info $info -UserName $context.Identity.UserName
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
    $widget.Status = 'Loading'
    $widget.Message = 'Łączenie z komputerem {0}…' -f $context.ComputerName
    $widget.Version++
    Update-MwpDashboardWidgets
    # Zadanie łączenia zajmuje widget (Task), więc harmonogram nie odświeża go w tym czasie.
    $widget.Task = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Łączenie: {0}' -f $context.ComputerName) -State $widget -ArgumentList $context, $credential, ($plan.Action -eq 'Store'), $save -ScriptBlock {
        param($Progress, $Context, [System.Management.Automation.PSCredential] $Credential, [bool] $UseStored, [bool] $Save)
        $Progress.Message = $(if ($UseStored) { 'hasło z Menedżera poświadczeń, nawiązywanie sesji WinRM' } else { 'nawiązywanie sesji WinRM' })
        Connect-MwpTarget -Context $Context -Credential $Credential -UseStoredCredential:$UseStored -SaveCredential:$Save
    } -OnCompleted {
        param($Task)
        $target = $Task.State
        $target.Task = $null
        if ($target.Removed) {
            return
        }
        $result = @($Task.Output | Where-Object { $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
        if ($Task.Status -eq 'Completed' -and $null -ne $result -and $result.Success) {
            $target.Message = $null
            $target.Status = 'Idle'
            $target.Pending = $true
            $null = Resume-MwpUiTargetWidget -Widget @($script:MwpUi.Dashboard.Widgets) -ComputerName $target.Instance.Context.ComputerName
        }
        else {
            $target.Status = 'NeedsCredential'
            $target.Message = 'Nie udało się połączyć: {0}' -f $(if ($null -ne $result) { $result.Message } elseif ($Task.Error) { $Task.Error } else { $Task.Status })
        }
        $target.Version++
    }
}
