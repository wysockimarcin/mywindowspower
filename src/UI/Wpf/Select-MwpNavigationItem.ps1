function Select-MwpNavigationItem {
    <#
    .SYNOPSIS
        Zaznacza w nawigacji pozycję widoku (bez ponownej nawigacji) i odznacza drugą listę.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Key
    )

    $ui = $script:MwpUi
    $c = $ui.Controls
    $previous = $ui.Navigating
    $ui.Navigating = $true
    try {
        foreach ($list in @($c['NavList'], $c['NavBottomList'])) {
            $match = @($list.Items | Where-Object { [string]$_.Tag -eq $Key }) | Select-Object -First 1
            $list.SelectedItem = $match
        }
    }
    finally {
        $ui.Navigating = $previous
    }
}
