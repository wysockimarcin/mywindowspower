function Get-MwpServiceDependent {
    <#
    .SYNOPSIS
        Zwraca usługi zależne od podanej (bezpośrednio i pośrednio) w kolejności bezpiecznego zatrzymania.

    .DESCRIPTION
        Graf z odczytu (MWP.ServiceList.Dependencies: Service zależy od DependsOn). Kolejność: najpierw
        usługi najdalej w łańcuchu zależności (A zależy od B, B od usługi → A, potem B), więc każda
        usługa jest zatrzymywana dopiero po zatrzymaniu wszystkich, które od niej zależą. Odwrotna
        kolejność to kolejność ponownego uruchamiania. Cykle w grafie nie zapętlają funkcji.

    .PARAMETER Name
        Nazwa usługi.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Dependencies,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $map = @{}
    foreach ($link in $Dependencies) {
        if ($null -eq $link) {
            continue
        }
        $key = ([string]$link.DependsOn).ToLowerInvariant()
        if (-not $map.ContainsKey($key)) {
            $map[$key] = New-Object -TypeName System.Collections.Generic.List[string]
        }
        $map[$key].Add([string]$link.Service)
    }
    $visited = @{ $Name.ToLowerInvariant() = $true }
    $order = New-Object -TypeName System.Collections.Generic.List[string]
    $visit = {
        param([string] $Current)
        $key = $Current.ToLowerInvariant()
        if (-not $map.ContainsKey($key)) {
            return
        }
        foreach ($dependent in $map[$key]) {
            $dependentKey = $dependent.ToLowerInvariant()
            if ($visited.ContainsKey($dependentKey)) {
                continue
            }
            $visited[$dependentKey] = $true
            & $visit $dependent
            $order.Add($dependent)
        }
    }
    & $visit $Name
    $order.ToArray()
}
