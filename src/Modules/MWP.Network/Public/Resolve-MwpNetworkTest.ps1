function Resolve-MwpNetworkTest {
    <#
    .SYNOPSIS
        Zamienia surowy wynik testów łączności (Test-MwpNetworkConnection -AsOperation, blok Test) na obiekt MWP.NetworkTest.

    .DESCRIPTION
        Czysta funkcja: przyjmuje tekst JSON, MWP.Result albo obiekt surowy; gotowy MWP.NetworkTest
        jest zwracany bez zmian. Każdy test (MWP.NetworkTestItem) ma polską nazwę, cel, wynik
        (Success, ResultText), szczegóły i czas. Summary: „N z M testów zaliczonych”. Zwraca $null,
        gdy danych nie ma.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.NetworkTest') {
        return $Data
    }
    $raw = ConvertFrom-MwpNetworkJson -Data $Data -Kind 'MWP.NetworkTestRaw'
    if ($null -eq $raw) {
        return $null
    }
    $tests = @(foreach ($item in @($raw.Tests | Where-Object { $null -ne $_ })) {
            $label = switch ([string]$item.Name) {
                'Gateway' { 'Ping do bramy domyślnej' }
                'External' { 'Ping do hosta zewnętrznego' }
                'Dns' { 'Rozwiązanie nazwy DNS' }
                'Port' { 'Port TCP' }
                default { [string]$item.Name }
            }
            [pscustomobject]@{
                PSTypeName = 'MWP.NetworkTestItem'
                Name       = [string]$item.Name
                Label      = $label
                Target     = [string]$item.Target
                Success    = [bool]$item.Success
                ResultText = $(if ($item.Success) { 'OK' } else { 'Błąd' })
                Detail     = [string]$item.Detail
                DurationMs = [int]$item.DurationMs
            }
        })
    $passed = @($tests | Where-Object { $_.Success }).Count
    [pscustomobject]@{
        PSTypeName   = 'MWP.NetworkTest'
        ComputerName = [string]$raw.ComputerName
        CollectedAt  = ConvertFrom-MwpNetworkDate -Value $raw.CollectedAt
        Tests        = $tests
        Passed       = $passed
        Success      = $tests.Count -gt 0 -and $passed -eq $tests.Count
        Summary      = '{0} z {1} testów zaliczonych.' -f $passed, $tests.Count
    }
}
