function Resolve-MwpWingetPackage {
    <#
    .SYNOPSIS
        Zamienia surowy wynik winget (Get-MwpWingetPackage / Find-MwpWingetPackage z -AsOperation) na obiekt MWP.WingetList.

    .DESCRIPTION
        Czysta funkcja: przyjmuje tekst JSON, MWP.Result albo obiekt surowy (MWP.WingetRaw albo zestaw
        przebiegów MWP.WingetRawSet z zadań harmonogramu, D-051); gotowy MWP.WingetList jest zwracany
        bez zmian. Tabela jest czytana przez ConvertFrom-MwpWingetOutput (kolumny wg rodzaju: List —
        Name, Id, Version, Available; Search — Name, Id, Version, Match). Kod „nie znaleziono pakietu”
        daje pustą listę z sukcesem. Pakiet (MWP.WingetPackage): nazwa, identyfikator, wersja
        zainstalowana (List) albo dostępna (Search), dostępna aktualizacja, dopasowanie oraz kontekst
        przebiegu (RunAs: Direct, System, User; UserSid, UserName). Zestaw przebiegów: o wyniku decyduje
        pierwszy (podstawowy); pakiety kolejnych (profile użytkowników) są dodawane, gdy nie ma ich
        w poprzednich (ten sam identyfikator i wersja), a błędy kolejnych trafiają do Warnings.
        Zwraca $null, gdy danych nie ma.

    .PARAMETER Kind
        List (winget list / upgrade) albo Search (winget search).

    .PARAMETER ComputerName
        Nazwa komputera do komunikatów (domyślnie nazwa zwrócona przez komputer docelowy).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data,

        [ValidateSet('List', 'Search')]
        [string] $Kind = 'List',

        [string] $ComputerName = ''
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.WingetList') {
        return $Data
    }
    $source = ConvertFrom-MwpAppsJson -Data $Data -Kind 'MWP.WingetRaw', 'MWP.WingetRawSet'
    if ($null -eq $source) {
        return $null
    }
    $computerName = if ($ComputerName) { $ComputerName } elseif ($source.ComputerName) { [string]$source.ComputerName } else { 'localhost' }
    $items = if ($source.Kind -eq 'MWP.WingetRawSet') { @($source.Runs) } else { @($source) }
    $notFound = 0x8A150014L
    $columns = if ($Kind -eq 'Search') { 'Name', 'Id', 'Version', 'Match' } else { 'Name', 'Id', 'Version', 'Available' }
    $packages = @()
    $runs = @()
    $warnings = @(if ($source.Kind -eq 'MWP.WingetRawSet') { @($source.Warnings | Where-Object { $_ }) })
    $first = $null
    $index = -1
    foreach ($item in $items) {
        $index++
        $call = ConvertTo-MwpWingetCall -Data $item -AllowedExitCode $notFound -ComputerName $computerName
        if ($source.Kind -eq 'MWP.WingetRaw') {
            $call.RunAs = 'Direct'
        }
        if ($index -eq 0) {
            $first = $call
        }
        elseif (-not $call.Success) {
            $warnings += $call.Message
        }
        $runs += [pscustomobject]@{ RunAs = $call.RunAs; UserSid = $call.UserSid; UserName = $call.UserName; Success = [bool]$call.Success; Reason = $call.Reason; Message = $call.Message }
        if (-not $call.Success -or (([long]$call.ExitCode) -band 0xFFFFFFFFL) -eq $notFound) {
            continue
        }
        foreach ($row in @(ConvertFrom-MwpWingetOutput -Line $call.Lines -Column $columns)) {
            $id = [string]$row.Id
            $version = [string]$row.Version
            if ($index -gt 0 -and @($packages | Where-Object { $_.Id -eq $id -and $_.Version -eq $version }).Count -gt 0) {
                continue
            }
            $available = if ($Kind -eq 'List') { [string]$row.Available } else { '' }
            $packages += [pscustomobject]@{
                PSTypeName = 'MWP.WingetPackage'
                Name       = [string]$row.Name
                Id         = $id
                Version    = $version
                Available  = $available
                HasUpgrade = [bool]$available
                Match      = $(if ($Kind -eq 'Search') { [string]$row.Match } else { '' })
                Source     = 'winget'
                IsLocalId  = [bool]$row.IsLocalId
                Truncated  = [bool]$row.Truncated
                Table      = [int]$row.Table
                RunAs      = $call.RunAs
                UserSid    = $call.UserSid
                UserName   = $call.UserName
            }
        }
    }
    [pscustomobject]@{
        PSTypeName      = 'MWP.WingetList'
        Kind            = $Kind
        Success         = [bool]$first.Success
        WingetAvailable = [bool]$first.Found
        WingetPath      = [string]$first.WingetPath
        ExitCode        = $first.ExitCode
        Message         = $(if ($first.Success) { '' } else { [string]$first.Message })
        Packages        = $packages
        DurationMs      = $(if ($source.Kind -eq 'MWP.WingetRawSet') { [int]$source.DurationMs } else { [int]$first.DurationMs })
        RunAs           = $first.RunAs
        Runs            = $runs
        Warnings        = @($warnings)
    }
}
