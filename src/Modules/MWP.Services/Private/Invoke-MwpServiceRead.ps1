function Invoke-MwpServiceRead {
    <#
    .SYNOPSIS
        Odczytuje usługi na komputerze docelowym kontekstu (blok List) i zwraca surowy wynik.

    .DESCRIPTION
        Jedno wywołanie Invoke-MwpOnTarget (jedna podróż do komputera zdalnego). Wynik: Success,
        Result (MWP.Result błędu, gotowy do zwrócenia) i Raw (MWP.ServiceRaw). Z -AsOperation
        zwraca uchwyt MWP.Operation (Start-MwpOperation); surowy JSON zamienia Resolve-MwpServiceList.

    .PARAMETER Name
        Nazwy usług do odczytu (domyślnie wszystkie). Graf zależności zawsze dotyczy wszystkich.

    .PARAMETER IncludeGraph
        Dołącza zależności usług (Win32_DependentService).
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

        [AllowEmptyCollection()]
        [string[]] $Name = @(),

        [switch] $IncludeGraph,

        [switch] $AsOperation
    )

    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            Names        = @($Name)
            IncludeGraph = [bool]$IncludeGraph
        })
    $block = Get-MwpServiceScript -Name List
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation
    }

    $common = @{ Operation = $Operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation
    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Result = $result; Raw = $null }
    }
    $raw = ConvertFrom-MwpServiceJson -Data $result -Kind 'MWP.ServiceRaw'
    if ($null -eq $raw) {
        $failed = New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił listy usług." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $failed; Raw = $null }
    }
    if ($raw.Error) {
        $failed = New-MwpResult @common -Success $false -Message ("Nie udało się odczytać usług na komputerze '{0}': {1}" -f $Context.ComputerName, $raw.Error) -ErrorMessage $raw.Error
        return [pscustomobject]@{ Success = $false; Result = $failed; Raw = $raw }
    }
    [pscustomobject]@{ Success = $true; Result = $result; Raw = $raw }
}
