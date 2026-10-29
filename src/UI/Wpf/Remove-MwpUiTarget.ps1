function Remove-MwpUiTarget {
    <#
    .SYNOPSIS
        Usuwa komputer z rejestru komputerów docelowych po podglądzie i potwierdzeniu z jego nazwą.

    .DESCRIPTION
        Otwarte instancje dla tego komputera działają dalej (mają własne, niezmienne konteksty);
        nowej instancji dla usuniętego komputera nie da się już otworzyć.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [object] $Target,

        [AllowNull()]
        [object] $Owner
    )

    $preview = Remove-MwpTarget -Name $Target.Name -WhatIf
    if (-not $preview.IsPreview) {
        Show-MwpMessage -Text $preview.Message -Kind Warning -Owner $Owner
        return
    }
    $open = @($script:MwpUi.Instances.Values | Where-Object { $_.Instance.Context.ComputerName -eq $Target.Name }).Count
    $warning = 'Zapisane hasło tego komputera (jeśli jest) zostanie usunięte z Menedżera poświadczeń Windows; cofnięcie przywróci tylko wpis rejestru.'
    if ($open -gt 0) {
        $warning = '{0} Otwarte instancje dla tego komputera ({1}) działają dalej do zamknięcia.' -f $warning, $open
    }
    $confirmed = Show-MwpConfirmDialog -Header 'Usunięcie komputera docelowego' -Target ("Komputer '{0}' ({1})" -f $Target.Name, $Target.DisplayName) `
        -PreviewLine @(ConvertTo-MwpPreviewLine -Result $preview) -Class Change -Warning $warning -ConfirmText 'Usuń' -Owner $Owner
    if (-not $confirmed -or -not $PSCmdlet.ShouldProcess($Target.Name, 'Usunięcie komputera docelowego')) {
        return
    }
    $result = Remove-MwpTarget -Name $Target.Name -Confirm:$false
    if (-not $result.Success) {
        Show-MwpMessage -Text $result.Message -Kind Warning -Owner $Owner
    }
    Update-MwpCurrentView
}
