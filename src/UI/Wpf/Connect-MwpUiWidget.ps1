function Connect-MwpUiWidget {
    <#
    .SYNOPSIS
        Łączy widget z komputerem zdalnym: okno poświadczeń, połączenie w tle, potem odświeżenie widgetu.

    .DESCRIPTION
        Jak dla instancji (Connect-MwpUiInstance, D-034): okno poświadczeń pokazuje warstwa UI,
        a Connect-MwpTarget działa w zadaniu w tle na kontekście instancji widgetu, więc okno nie czeka
        na limit czasu niedostępnego komputera. Poświadczenie zostaje tylko w pamięci połączenia tego
        widgetu; inne widgety tego samego komputera mają własne konteksty.

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
    $credential = $null
    if ($context.Identity.Authentication -eq 'Credential') {
        $credential = Show-MwpCredentialDialog -ComputerName $context.ComputerName -UserName $context.Identity.UserName -Owner $Owner
        if ($null -eq $credential) {
            return
        }
    }
    $widget.Status = 'Loading'
    $widget.Message = 'Łączenie z komputerem {0}…' -f $context.ComputerName
    $widget.Version++
    Update-MwpDashboardWidgets
    # Zadanie łączenia zajmuje widget (Task), więc harmonogram nie odświeża go w tym czasie.
    $widget.Task = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Łączenie: {0}' -f $context.ComputerName) -State $widget -ArgumentList $context, $credential -ScriptBlock {
        param($Progress, $Context, [System.Management.Automation.PSCredential] $Credential)
        $Progress.Message = 'nawiązywanie sesji WinRM'
        Connect-MwpTarget -Context $Context -Credential $Credential
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
        }
        else {
            $target.Status = 'NeedsCredential'
            $target.Message = 'Nie udało się połączyć: {0}' -f $(if ($null -ne $result) { $result.Message } elseif ($Task.Error) { $Task.Error } else { $Task.Status })
        }
        $target.Version++
    }
}
