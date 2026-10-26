function Get-MwpUiInstanceRow {
    <#
    .SYNOPSIS
        Wiersze listy otwartych instancji (Pulpit, widok obszaru): nazwa, stan połączenia, miejsce prezentacji.

    .PARAMETER ModuleId
        Tylko instancje tego modułu.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string] $ModuleId
    )

    foreach ($entry in @($script:MwpUi.Instances.Values | Sort-Object -Property { $_.Instance.CreatedAt })) {
        if ($ModuleId -and $entry.Instance.ModuleId -ne $ModuleId) {
            continue
        }
        [pscustomobject]@{
            Id        = $entry.Id
            Name      = $entry.Instance.Name
            State     = Get-MwpConnectionStateInfo -Context $entry.Instance.Context
            Placement = $(if ($entry.Placement -eq 'SeparateWindow') { 'w osobnym oknie' } else { 'w oknie głównym' })
        }
    }
}
