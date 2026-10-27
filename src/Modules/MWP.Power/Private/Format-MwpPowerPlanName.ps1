function Format-MwpPowerPlanName {
    <#
    .SYNOPSIS
        Opis planu do komunikatów, podglądu i rejestru cofnięć: „'Nazwa' (GUID)”.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Plan,

        [AllowEmptyString()]
        [string] $Guid = ''
    )

    if ($null -eq $Plan) {
        return $(if ($Guid) { "plan $Guid" } else { '(brak)' })
    }
    "'{0}' ({1})" -f $Plan.Name, $Plan.Guid
}
