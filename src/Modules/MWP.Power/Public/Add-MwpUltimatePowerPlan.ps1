function Add-MwpUltimatePowerPlan {
    <#
    .SYNOPSIS
        Dodaje plan „Najwyższa wydajność” (Ultimate Performance) jako kopię ukrytego szablonu Windows.

    .DESCRIPTION
        Operacja klasy Zmiana: Copy-MwpPowerPlan z GUID-em szablonu e9a42b02-d5df-448d-aa00-03f14749eb61
        (powercfg -duplicatescheme; GUID zweryfikowany w FAZIE 6 w domyślnych schematach Windows 11
        i w odpowiedzi Microsoft Q&A, D-044). Podgląd, log i cofnięcie (usunięcie kopii) jak
        w Copy-MwpPowerPlan. Nowy plan nie jest aktywowany (Set-MwpActivePowerPlan). Na komputerach
        z nowoczesnym trybem wstrzymania szablon bywa niedostępny — wynik z błędem i wyjaśnieniem.

    .PARAMETER Name
        Nazwa nowego planu; domyślnie nazwa nadana przez Windows („Najwyższa wydajność”).

    .EXAMPLE
        Add-MwpUltimatePowerPlan -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [ValidatePattern('^[^"\p{Cc}]{1,128}$')]
        [string] $Name,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $parameters = @{ Guid = (Get-MwpPowerCatalog).UltimateTemplateGuid; Context = $Context }
    if ($PSBoundParameters.ContainsKey('Name')) {
        $parameters['Name'] = $Name
    }
    $target = Format-MwpOperationTarget -Target 'plan zasilania „Najwyższa wydajność”' -ComputerName $Context.ComputerName
    if (-not $PSCmdlet.ShouldProcess($target, 'Dodanie planu (kopia szablonu Windows)')) {
        return Copy-MwpPowerPlan @parameters -WhatIf
    }
    Copy-MwpPowerPlan @parameters -Confirm:$false
}
