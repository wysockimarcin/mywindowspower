function ConvertTo-MwpSystemReport {
    <#
    .SYNOPSIS
        Tworzy raport informacji o systemie jako tekst JSON albo czytelny tekst.

    .DESCRIPTION
        Funkcja czysta (bez zapisu na dysk). JSON: obiekt z polami Report (aplikacja, data
        utworzenia, komputer) i SystemInfo (wszystkie odczytane dane, bez formatowania). Tekst:
        nagłówek oraz sekcje z widoku widgetu (ConvertTo-MwpSystemInfoView), ze wszystkimi odczytanymi
        sekcjami i ostrzeżeniami odczytu. Brak danych — wyjątek (błąd wywołującego).

    .PARAMETER Data
        Dane z Get-MwpSystemInfo (obiekt, tekst JSON albo MWP.Result).

    .PARAMETER Format
        Json albo Text.

    .EXAMPLE
        ConvertTo-MwpSystemReport -Data (Get-MwpSystemInfo -Context (New-MwpExecutionContext)) -Format Text
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Data,

        [ValidateSet('Json', 'Text')]
        [string] $Format = 'Text'
    )

    $info = Resolve-MwpSystemInfoData -Data $Data
    if ($null -eq $info) {
        throw 'Brak informacji o systemie do raportu.'
    }
    $generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $version = [string]$MyInvocation.MyCommand.Module.Version

    if ($Format -eq 'Json') {
        $report = [ordered]@{
            Report     = [ordered]@{
                Application  = 'MyWindowsPower'
                Module       = 'MWP.Dashboard'
                Version      = $version
                GeneratedAt  = $generatedAt
                ComputerName = $info.ComputerName
            }
            SystemInfo = $info
        }
        return ConvertTo-Json -InputObject $report -Depth 10
    }

    $view = ConvertTo-MwpSystemInfoView -Data $info
    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    $lines.Add('Raport systemu — MyWindowsPower')
    $lines.Add(('Komputer: {0}' -f $info.ComputerName))
    $lines.Add(('Dane odczytane: {0}' -f $info.CollectedAt))
    $lines.Add(('Raport utworzony: {0}' -f $generatedAt))
    foreach ($section in $view.Sections) {
        $lines.Add('')
        $lines.Add(('== {0} ==' -f $section.Title))
        foreach ($item in $section.Items) {
            $lines.Add(('{0}: {1}' -f $item.Label, $item.Value))
        }
    }
    if (@($view.Warnings).Count -gt 0) {
        $lines.Add('')
        $lines.Add('== Ostrzeżenia odczytu ==')
        foreach ($warning in $view.Warnings) {
            $lines.Add(('- {0}' -f $warning))
        }
    }
    $lines -join [Environment]::NewLine
}
