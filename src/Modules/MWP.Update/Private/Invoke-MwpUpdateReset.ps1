function Invoke-MwpUpdateReset {
    <#
    .SYNOPSIS
        Wykonuje blok Reset (Mode Reset albo Restore) na komputerze docelowym i zwraca surowy wynik.

    .DESCRIPTION
        Usługi, foldery i katalog Windows z Get-MwpUpdateTargetConfig (stałe, D-015). Wynik: Success
        (blok się wykonał i zwrócił wynik — nie oznacza powodzenia resetu), Result (MWP.Result błędu
        połączenia) i Raw (MWP.UpdateResetRaw: kroki, zmienione nazwy, błąd).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Funkcja wewnętrzna; podgląd i potwierdzenie zapewnia funkcja publiczna (Reset-, Restore-MwpUpdateComponent).')]
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
        [ValidateSet('Reset', 'Restore')]
        [string] $Mode,

        [Parameter(Mandatory)]
        [string] $Suffix,

        [string] $ReplacedSuffix = ''
    )

    $config = Get-MwpUpdateTargetConfig
    $request = ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{
            Mode             = $Mode
            Suffix           = $Suffix
            ReplacedSuffix   = $ReplacedSuffix
            WindowsRoot      = $config.WindowsRoot
            Services         = @($config.ResetServices)
            OptionalServices = @($config.OptionalServices)
            Folders          = @($config.ResetFolders)
            TimeoutSeconds   = 60
        })
    $common = @{ Operation = $Operation; Target = 'Windows Update'; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -Operation $Operation -ScriptBlock (Get-MwpUpdateScript -Name Reset) -ArgumentList @($request) -TimeoutSeconds 900
    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Result = $result; Raw = $null }
    }
    $raw = ConvertFrom-MwpUpdateJson -Data $result -Kind 'MWP.UpdateResetRaw'
    if ($null -eq $raw) {
        $failed = New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił wyniku resetu składników Windows Update." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
        return [pscustomobject]@{ Success = $false; Result = $failed; Raw = $null }
    }
    [pscustomobject]@{ Success = $true; Result = $result; Raw = $raw }
}
