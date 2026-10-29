function Resolve-MwpWingetPackage {
    <#
    .SYNOPSIS
        Zamienia surowy wynik winget (Get-MwpWingetPackage / Find-MwpWingetPackage z -AsOperation) na obiekt MWP.WingetList.

    .DESCRIPTION
        Czysta funkcja: przyjmuje tekst JSON, MWP.Result albo obiekt surowy (MWP.WingetRaw); gotowy
        MWP.WingetList jest zwracany bez zmian. Tabela jest czytana przez ConvertFrom-MwpWingetOutput
        (kolumny wg rodzaju: List — Name, Id, Version, Available; Search — Name, Id, Version, Match).
        Kod „nie znaleziono pakietu” daje pustą listę z sukcesem. Pakiet (MWP.WingetPackage): nazwa,
        identyfikator, wersja zainstalowana (List) albo dostępna (Search), dostępna aktualizacja,
        dopasowanie. Zwraca $null, gdy danych nie ma.

    .PARAMETER Kind
        List (winget list / upgrade) albo Search (winget search).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data,

        [ValidateSet('List', 'Search')]
        [string] $Kind = 'List'
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.WingetList') {
        return $Data
    }
    if ($null -eq (ConvertFrom-MwpAppsJson -Data $Data -Kind 'MWP.WingetRaw')) {
        return $null
    }
    $notFound = 0x8A150014L
    $call = ConvertTo-MwpWingetCall -Data $Data -AllowedExitCode $notFound
    $columns = if ($Kind -eq 'Search') { 'Name', 'Id', 'Version', 'Match' } else { 'Name', 'Id', 'Version', 'Available' }
    $packages = @()
    if ($call.Success -and (([long]$call.ExitCode) -band 0xFFFFFFFFL) -ne $notFound) {
        $packages = @(ConvertFrom-MwpWingetOutput -Line $call.Lines -Column $columns | ForEach-Object {
                $available = if ($Kind -eq 'List') { [string]$_.Available } else { '' }
                [pscustomobject]@{
                    PSTypeName = 'MWP.WingetPackage'
                    Name       = [string]$_.Name
                    Id         = [string]$_.Id
                    Version    = [string]$_.Version
                    Available  = $available
                    HasUpgrade = [bool]$available
                    Match      = $(if ($Kind -eq 'Search') { [string]$_.Match } else { '' })
                    Source     = 'winget'
                    IsLocalId  = [bool]$_.IsLocalId
                    Truncated  = [bool]$_.Truncated
                    Table      = [int]$_.Table
                }
            })
    }
    [pscustomobject]@{
        PSTypeName      = 'MWP.WingetList'
        Kind            = $Kind
        Success         = [bool]$call.Success
        WingetAvailable = [bool]$call.Found
        WingetPath      = [string]$call.WingetPath
        ExitCode        = $call.ExitCode
        Message         = $(if ($call.Success) { '' } else { [string]$call.Message })
        Packages        = $packages
        DurationMs      = [int]$call.DurationMs
    }
}
