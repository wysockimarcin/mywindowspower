function Read-MwpServiceState {
    <#
    .SYNOPSIS
        Odczyt stanu przed zmianą (wzorzec funkcji zmieniającej system, krok 3): usługi i lista ochronna.

    .DESCRIPTION
        Wynik: Success, Result (MWP.Result błędu, gotowy do zwrócenia), List (MWP.ServiceList)
        i Service (usługa o nazwie -Target albo $null). Nieczytelna lista ochronna jest błędem —
        bez niej żadna zmiana nie jest dozwolona.

    .PARAMETER Target
        Nazwa usługi, której dotyczy zmiana.

    .PARAMETER Name
        Nazwy usług do odczytu (domyślnie wszystkie).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [AllowEmptyCollection()]
        [string[]] $Name = @(),

        [switch] $IncludeGraph
    )

    $common = @{ Operation = $Operation; Target = $Target; ComputerName = $Context.ComputerName }
    try {
        $protected = @(Get-MwpProtectedItem -Category Service)
    }
    catch {
        $result = New-MwpResult @common -Success $false -Message ('Nie można odczytać listy ochronnej usług, więc zmiana jest zablokowana: {0}' -f $_.Exception.Message) -ErrorMessage $_.Exception.Message
        return [pscustomobject]@{ Success = $false; Result = $result; List = $null; Service = $null }
    }
    $read = Invoke-MwpServiceRead -Context $Context -Operation $Operation -Name $Name -IncludeGraph:$IncludeGraph
    if (-not $read.Success) {
        $result = New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $result; List = $null; Service = $null }
    }
    $list = Resolve-MwpServiceList -Data $read.Raw -ProtectedItem $protected
    $service = @($list.Services | Where-Object { $_.Name -eq $Target }) | Select-Object -First 1
    if ($null -eq $service) {
        $result = New-MwpResult @common -Success $false -Message ("Na komputerze '{0}' nie ma usługi '{1}'." -f $Context.ComputerName, $Target)
        return [pscustomobject]@{ Success = $false; Result = $result; List = $list; Service = $null }
    }
    [pscustomobject]@{ Success = $true; Result = $null; List = $list; Service = $service }
}
