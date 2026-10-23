function Get-MwpTargetEntry {
    <#
    .SYNOPSIS
        Zwraca surowe wpisy rejestru komputerów (bez wpisu przykładowego z szablonu) do zapisu.
    #>
    [CmdletBinding()]
    [OutputType([Collections.IDictionary])]
    param()

    foreach ($entry in @(Get-MwpSetting -Name 'targets')) {
        if ($entry -is [Collections.IDictionary] -and -not ($entry.Contains('isExample') -and [bool]$entry['isExample'])) {
            $entry
        }
    }
}
