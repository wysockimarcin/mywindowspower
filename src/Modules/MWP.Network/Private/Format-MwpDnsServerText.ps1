function Format-MwpDnsServerText {
    <#
    .SYNOPSIS
        Opisuje ustawienie DNS adaptera: lista statycznych serwerów albo „automatycznie (DHCP)”.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]] $Server = @()
    )

    $list = @($Server | Where-Object { $_ })
    if ($list.Count -eq 0) {
        return 'automatycznie (DHCP)'
    }
    $list -join ', '
}
