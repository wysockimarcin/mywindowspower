function Connect-MwpUiInstance {
    <#
    .SYNOPSIS
        Łączy instancję z komputerem zdalnym w tle; w razie potrzeby najpierw pyta o poświadczenia.

    .DESCRIPTION
        Okno poświadczeń wyświetla warstwa UI (D-034): przy uwierzytelnieniu Credential, gdy
        połączenie nie ma poświadczeń albo stan to Unauthorized/CredentialRequired. Samo połączenie
        (Connect-MwpTarget) działa w zadaniu w tle, więc okno nie czeka na limit czasu niedostępnego
        komputera. Stan połączenia zmienia się w kontekście tej instancji; inne instancje i widoki
        działają dalej (D-019). Wynik trafia do widoku instancji.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    $context = $Entry.Instance.Context
    if ($context.Mode -eq 'Local') {
        return
    }
    $state = Get-MwpConnectionStateInfo -Context $context
    $credential = $null
    if ($state.NeedsCredential -or ($context.Identity.Authentication -eq 'Credential' -and $state.State -eq 'Unauthorized')) {
        $credential = Show-MwpCredentialDialog -ComputerName $context.ComputerName -UserName $context.Identity.UserName -Owner $Owner
        if ($null -eq $credential) {
            return
        }
    }

    $Entry.Busy++
    $Entry.Message = $null
    Update-MwpInstanceView -Entry $Entry -StateOnly
    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Łączenie: {0}' -f $context.ComputerName) -State $Entry.Id -ArgumentList $context, $credential -ScriptBlock {
        param($Progress, $Context, [System.Management.Automation.PSCredential] $Credential)
        $Progress.Message = 'nawiązywanie sesji WinRM'
        Connect-MwpTarget -Context $Context -Credential $Credential
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
        }
        Update-MwpInstanceView -Entry $entry
    }
}
