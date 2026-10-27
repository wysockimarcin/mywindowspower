function Get-MwpServiceStartupTypeList {
    <#
    .SYNOPSIS
        Zwraca typy uruchomienia usług obsługiwane przez Set-MwpServiceStartupType: identyfikator, nazwę po polsku, argument sc.exe.

    .DESCRIPTION
        Odczyt (bez wywołań systemowych). Kolejność jak w przystawce Usługi. AllowedWhenProtected
        mówi, czy typ wolno ustawić usłudze z listy ochronnej (D-045: tylko typy automatyczne).

    .EXAMPLE
        Get-MwpServiceStartupTypeList | Format-Table Id, Label
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    foreach ($item in @(
            @{ Id = 'Automatic'; Label = 'Automatyczny'; ScMode = 'auto'; AllowedWhenProtected = $true }
            @{ Id = 'AutomaticDelayedStart'; Label = 'Automatyczny (opóźniony start)'; ScMode = 'delayed-auto'; AllowedWhenProtected = $true }
            @{ Id = 'Manual'; Label = 'Ręczny'; ScMode = 'demand'; AllowedWhenProtected = $false }
            @{ Id = 'Disabled'; Label = 'Wyłączony'; ScMode = 'disabled'; AllowedWhenProtected = $false }
        )) {
        [pscustomobject]@{
            PSTypeName           = 'MWP.ServiceStartupType'
            Id                   = $item.Id
            Label                = $item.Label
            ScMode               = $item.ScMode
            AllowedWhenProtected = $item.AllowedWhenProtected
        }
    }
}
