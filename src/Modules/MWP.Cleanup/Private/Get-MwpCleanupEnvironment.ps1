function Get-MwpCleanupEnvironment {
    <#
    .SYNOPSIS
        Odczytuje na komputerze docelowym dane do rozwinięcia tokenów kategorii i lokalizacje chronione (blok Environment).

    .DESCRIPTION
        Jedno wywołanie Invoke-MwpOnTarget, tylko odczyt. Wynik: Success, Result (MWP.Result błędu,
        gotowy do zwrócenia) i Environment (MWP.CleanupEnvironment: SystemRoot, ProgramData,
        ProfilesDirectory, CurrentSid, CurrentProfile, IsAdministrator, FixedDrives, Profiles, Protected).
        W testach podmieniane mockiem, żeby kategorie wskazywały katalogi testowe.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation
    )

    $common = @{ Operation = $Operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock (Get-MwpCleanupScript -Name Environment) -Operation $Operation
    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Result = $result; Environment = $null }
    }
    $environment = ConvertFrom-MwpCleanupJson -Data $result -Kind 'MWP.CleanupEnvironment'
    if ($null -eq $environment -or -not $environment.SystemRoot) {
        $failed = New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił danych o lokalizacjach systemu." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $failed; Environment = $null }
    }
    [pscustomobject]@{ Success = $true; Result = $result; Environment = $environment }
}
