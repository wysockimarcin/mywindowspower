function Disconnect-MwpUiInstance {
    <#
    .SYNOPSIS
        Rozłącza instancję od komputera zdalnego w tle (Disconnect-MwpTarget: sesje i poświadczenia z pamięci).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $ui = $script:MwpUi
    $context = $Entry.Instance.Context
    # Ręczne rozłączenie: instancja nie łączy się sama, gdy inna instancja tego komputera się połączy (D-052).
    $Entry['ManualDisconnect'] = $true
    $Entry.Busy++
    Update-MwpInstanceView -Entry $Entry -StateOnly
    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Rozłączanie: {0}' -f (Format-MwpTargetLabel -Context $context)) -State $Entry.Id -ArgumentList @(, $context) -ScriptBlock {
        param($Progress, $Context)
        $Progress.Message = 'zamykanie sesji'
        Disconnect-MwpTarget -Context $Context
    } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State]
        if ($null -eq $entry) {
            return
        }
        $entry.Busy = [Math]::Max(0, $entry.Busy - 1)
        $entry.Message = $(if ($Task.Status -ne 'Completed') { 'Rozłączanie: {0}' -f $Task.Error } else { $null })
        Update-MwpInstanceView -Entry $entry
    }
}
