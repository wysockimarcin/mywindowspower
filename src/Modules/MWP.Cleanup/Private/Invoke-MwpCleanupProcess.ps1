function Invoke-MwpCleanupProcess {
    <#
    .SYNOPSIS
        Skanuje albo usuwa pliki w podanych katalogach głównych na komputerze docelowym (blok Process).

    .DESCRIPTION
        Jedno wywołanie Invoke-MwpOnTarget dla listy katalogów (tylko te z Available). Lokalnie przekazuje
        tabelę postępu (-Progress), żeby blok mógł przerwać pracę po bieżącym pliku (CancelRequested);
        zdalnie anulowanie działa między wywołaniami. Wynik: Success, Result (MWP.Result błędu) i Raw
        (MWP.CleanupProcess: Roots z liczbami, pominięciami i przykładami, IsAdministrator, Cancelled).

    .PARAMETER Root
        MWP.CleanupRoot z Resolve-MwpCleanupRoot.

    .PARAMETER Mode
        Scan (tylko odczyt) albo Delete.

    .PARAMETER Protected
        Lokalizacje chronione użytkownika (z Get-MwpCleanupEnvironment).
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
        [AllowEmptyCollection()]
        [object[]] $Root,

        [Parameter(Mandatory)]
        [ValidateSet('Scan', 'Delete')]
        [string] $Mode,

        [AllowEmptyCollection()]
        [string[]] $Protected = @(),

        [AllowNull()]
        [hashtable] $Progress
    )

    $common = @{ Operation = $Operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $request = ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{
            Mode       = $Mode
            MaxSamples = 20
            Protected  = @($Protected)
            Roots      = @($Root | ForEach-Object {
                    [pscustomobject]@{
                        Key                    = $_.Key
                        Path                   = $_.Path
                        Recurse                = [bool]$_.Recurse
                        Patterns               = @($_.Patterns)
                        Exclude                = @($_.Exclude)
                        MinAgeDays             = [int]$_.MinAgeDays
                        RemoveEmptyDirectories = [bool]$_.RemoveEmptyDirectories
                    }
                })
        })
    $cancel = if ($Context.Mode -eq 'Local') { $Progress } else { $null }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock (Get-MwpCleanupScript -Name Process) -ArgumentList @($request, $cancel) -Operation $Operation -TimeoutSeconds 3600
    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Result = $result; Raw = $null }
    }
    $raw = ConvertFrom-MwpCleanupJson -Data $result -Kind 'MWP.CleanupProcess'
    if ($null -eq $raw) {
        $failed = New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił wyniku skanu ani czyszczenia." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $failed; Raw = $null }
    }
    [pscustomobject]@{ Success = $true; Result = $result; Raw = $raw }
}
