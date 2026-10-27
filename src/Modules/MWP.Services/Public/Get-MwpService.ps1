function Get-MwpService {
    <#
    .SYNOPSIS
        Odczytuje usługi Windows na komputerze docelowym: stan, typ uruchomienia (z opóźnionym startem), konto, ścieżkę, opis, zależności i oznaczenie listy ochronnej.

    .DESCRIPTION
        Operacja klasy Odczyt (nic nie zmienia). Jedno wywołanie na komputerze kontekstu (localhost
        albo zdalnym, D-019): Win32_Service, opcjonalnie Win32_DependentService. Filtry jak
        w Select-MwpService.
        Bez -AsOperation zwraca MWP.Result z obiektem MWP.ServiceList w Data (usługi w polu Services).
        Z -AsOperation startuje w puli runspace'ów (Start-MwpOperation) i zwraca uchwyt MWP.Operation;
        Data wyniku zawiera wtedy surowy tekst JSON, który zamienia Resolve-MwpServiceList (filtry
        nie są wtedy stosowane). Tak korzysta z niej widget „Status usług” (kontrakt widgetu, D-043)
        i widok Usługi.

    .PARAMETER Name
        Nazwy usług (dokładne, bez symboli wieloznacznych); domyślnie wszystkie.

    .PARAMETER IncludeDependencies
        Dołącza zależności (DependsOn, Dependents) — dodatkowe zapytanie CIM.

    .PARAMETER WidgetParameters
        Parametry widgetu (kontrakt D-043); widget odczytuje wszystkie usługi, a obserwowane wybiera widok.

    .EXAMPLE
        (Get-MwpService -Status Stopped -StartupType AnyAutomatic).Data.Services | Format-Table Name, DisplayName, StartupTypeText

    .EXAMPLE
        (Get-MwpService -Name Spooler -IncludeDependencies -Context $remote).Data.Services
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043); obserwowane usługi wybiera funkcja widoku.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidateScript({ Test-MwpServiceName -Name $_ })]
        [string[]] $Name = @(),

        [ValidateSet('All', 'Running', 'Stopped', 'Other')]
        [string] $Status = 'All',

        [ValidateSet('All', 'AnyAutomatic', 'Automatic', 'AutomaticDelayedStart', 'Manual', 'Disabled', 'Unknown')]
        [string] $StartupType = 'All',

        [AllowEmptyString()]
        [string] $Search = '',

        [switch] $ProtectedOnly,

        [switch] $IncludeDependencies,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Services.List'
    if ($AsOperation) {
        return Invoke-MwpServiceRead -Context $Context -Operation $operation -Name $Name -IncludeGraph:$IncludeDependencies -AsOperation
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $read = Invoke-MwpServiceRead -Context $Context -Operation $operation -Name $Name -IncludeGraph:$IncludeDependencies
    if (-not $read.Success) {
        return New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
    }
    $list = Resolve-MwpServiceList -Data $read.Raw
    $all = @($list.Services).Count
    $list.Services = @(Select-MwpService -Service $list.Services -Status $Status -StartupType $StartupType -Search $Search -ProtectedOnly:$ProtectedOnly)
    $shown = @($list.Services).Count
    $message = if ($shown -eq $all) {
        "Odczytano {0} usług komputera '{1}'." -f $all, $Context.ComputerName
    }
    else {
        "Odczytano {0} usług komputera '{1}' (po filtrach: {2})." -f $all, $Context.ComputerName, $shown
    }
    New-MwpResult @common -Success $true -Message $message -Data $list
}
