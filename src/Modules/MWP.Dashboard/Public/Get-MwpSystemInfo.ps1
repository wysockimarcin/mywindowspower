function Get-MwpSystemInfo {
    <#
    .SYNOPSIS
        Odczytuje informacje o systemie i sprzęcie komputera docelowego (localhost albo zdalnego).

    .DESCRIPTION
        Operacja klasy Odczyt (nic nie zmienia). Dane przez CIM (Get-CimInstance) i rejestr, odczytane
        na komputerze kontekstu blokiem zgodnym z Windows PowerShell 5.1 (D-036): system (wersja,
        kompilacja, data instalacji), uptime, CPU, RAM (użycie), GPU, dyski (pojemność, wolne miejsce,
        typ), płyta główna i BIOS, bateria (jeśli jest), podstawowy stan sieci. Odporna na braki:
        błąd jednej sekcji trafia do Data.Warnings, brak danych to $null albo pusta lista.
        Bez -AsOperation wykonuje się synchronicznie (Invoke-MwpOnTarget) i zwraca MWP.Result
        z obiektem w Data (Kind = 'MWP.SystemInfo'). Z -AsOperation startuje w puli runspace'ów
        (Start-MwpOperation) i zwraca uchwyt MWP.Operation; Data wyniku zawiera wtedy tekst JSON
        (widok widgetu i eksport przyjmują obie postacie). Tak korzysta z niej widget Dashboardu
        (kontrakt widgetu, D-043): -Context i -AsOperation, parametry widgetu w -WidgetParameters.

    .PARAMETER Section
        Sekcje do odczytu; domyślnie wszystkie.

    .PARAMETER WidgetParameters
        Parametry widgetu (klucz Sections — lista sekcji); używane, gdy nie podano -Section.

    .EXAMPLE
        (Get-MwpSystemInfo -Context (New-MwpExecutionContext)).Data.Memory
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [ValidateSet('System', 'Cpu', 'Memory', 'Gpu', 'Disks', 'Board', 'Battery', 'Network')]
        [string[]] $Section,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Dashboard.SystemInfo'
    $sections = @()
    if ($PSBoundParameters.ContainsKey('Section')) {
        $sections = @($Section)
    }
    elseif ($null -ne $WidgetParameters -and $WidgetParameters.Contains('Sections')) {
        $allowed = @('System', 'Cpu', 'Memory', 'Gpu', 'Disks', 'Board', 'Battery', 'Network')
        $sections = @(@($WidgetParameters['Sections']) | Where-Object { $allowed -contains $_ })
    }
    $block = Get-MwpSystemInfoScript
    $arguments = @(, [string[]]$sections)

    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList $arguments -Operation $operation
    }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList $arguments -Operation $operation
    if (-not $result.Success) {
        return $result
    }
    $data = Resolve-MwpSystemInfoData -Data $result.Data
    if ($null -eq $data) {
        return New-MwpResult -Success $false -Operation $operation -Target $Context.ComputerName -ComputerName $Context.ComputerName `
            -Message ("Komputer '{0}' nie zwrócił informacji o systemie." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
    }
    New-MwpResult -Success $true -Operation $operation -Target $Context.ComputerName -ComputerName $Context.ComputerName `
        -Message $result.Message -ErrorMessage $result.ErrorMessage -Data $data
}
