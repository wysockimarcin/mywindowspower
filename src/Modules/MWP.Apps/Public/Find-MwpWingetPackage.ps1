function Find-MwpWingetPackage {
    <#
    .SYNOPSIS
        Wyszukuje pakiety w repozytorium winget (winget search --source winget) z komputera docelowego.

    .DESCRIPTION
        Operacja klasy Odczyt (D-050). Zapytanie jest sprawdzane przed wysłaniem (litery, cyfry, spacja,
        . _ + - #, do 100 znaków; bez cudzysłowów, D-015). Wynik: MWP.Result z MWP.WingetList (Kind
        Search: nazwa, identyfikator, najnowsza wersja, dopasowanie) w Data; brak wyników = pusta lista.
        Z -AsOperation zwraca uchwyt operacji w tle; wynik zamienia Resolve-MwpWingetPackage -Kind Search.

    .PARAMETER Query
        Szukany tekst (nazwa, identyfikator, moniker lub znacznik pakietu).

    .PARAMETER Count
        Najwięcej wyników (1–200, domyślnie 50).

    .EXAMPLE
        (Find-MwpWingetPackage -Query '7zip').Data.Packages | Format-Table Name, Id, Version
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[\p{L}\p{N}][\p{L}\p{N} ._+#-]{0,99}$')]
        [string] $Query,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidateRange(1, 200)]
        [int] $Count = 0,

        [switch] $AsOperation
    )

    $config = Get-MwpAppsTargetConfig
    if ($Count -le 0) {
        $Count = [int]$config.SearchCount
    }
    $operation = 'Apps.WingetSearch'
    $arguments = @('search', $Query.Trim(), '--source', $config.Source, '--count', [string]$Count)
    if ($AsOperation) {
        return Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -AsOperation
    }
    $common = @{ Operation = $operation; Target = $Query; ComputerName = $Context.ComputerName }
    $call = Invoke-MwpWinget -Context $Context -Argument $arguments -Operation $operation -AllowedExitCode 0x8A150014L
    if ($null -ne $call.Result) {
        return New-MwpResult @common -Success $false -Message $call.Message -ErrorMessage $call.ErrorMessage
    }
    $list = Resolve-MwpWingetPackage -Kind Search -Data ([pscustomobject]@{
            Kind = 'MWP.WingetRaw'; Found = $call.Found; WingetPath = $call.WingetPath; ExitCode = $call.ExitCode; TimedOut = $false
            Lines = $call.Lines; Error = $null; DurationMs = $call.DurationMs
        })
    if (-not $call.Success) {
        return New-MwpResult @common -Success $false -Message $call.Message -ErrorMessage $call.ErrorMessage -Data $list
    }
    New-MwpResult @common -Success $true -Message ("Znaleziono {0} pakietów dla '{1}'." -f @($list.Packages).Count, $Query) -Data $list
}
