function Resolve-MwpPowerReport {
    <#
    .SYNOPSIS
        Zamienia wynik bloku raportu (MWP.Result z tekstem JSON albo gotowy wynik) na MWP.Result z obiektem MWP.PowerReport.

    .DESCRIPTION
        Sukces tylko wtedy, gdy powercfg utworzył plik (treść w Base64). Przy błędzie komunikat
        zawiera tekst powercfg i podpowiedź (raport energii: uprawnienia administratora; raport
        baterii: brak baterii). Wynik błędu połączenia przechodzi bez zmian.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [ValidateSet('Battery', 'Energy', '')]
        [string] $Kind = ''
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.Result') {
        if (-not $Data.Success) {
            return $Data
        }
        if (@($Data.Data | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.PowerReport' }).Count -gt 0) {
            return $Data
        }
        $ComputerName = $Data.ComputerName
    }
    $raw = ConvertFrom-MwpPowerJson -Data $Data -Kind 'MWP.PowerReportRaw'
    if ($null -ne $raw) {
        $Kind = [string]$raw.ReportKind
    }
    $label = if ($Kind -eq 'Battery') { 'raport baterii' } else { 'raport energii' }
    $common = @{ Operation = ('Power.Report.{0}' -f $(if ($Kind) { $Kind } else { 'Unknown' })); Target = $label; ComputerName = $ComputerName }
    if ($null -eq $raw) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił raportu." -f $ComputerName)
    }
    $output = (@($raw.Output | Where-Object { $_ -and ([string]$_).Trim() -ne '' } | ForEach-Object { ([string]$_).Trim() }) -join ' ')
    if ([string]::IsNullOrEmpty([string]$raw.Content)) {
        $hint = if ($Kind -eq 'Energy') { ' Raport energii wymaga uprawnień administratora na komputerze docelowym.' } else { ' Raport baterii wymaga komputera z baterią.' }
        $message = "Nie udało się utworzyć: {0} na komputerze '{1}' (powercfg, kod {2}{3}).{4}" -f $label, $ComputerName, $raw.ExitCode, $(if ($output) { ': ' + $output } else { '' }), $hint
        Write-MwpLog -Level Warning -Source 'MWP.Power' -Operation $common.Operation -ComputerName $ComputerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $output
    }
    $report = [pscustomobject]@{
        PSTypeName   = 'MWP.PowerReport'
        Kind         = 'MWP.PowerReport'
        ReportKind   = $Kind
        ComputerName = $ComputerName
        CreatedAt    = [string]$raw.CreatedAt
        ExitCode     = [int]$raw.ExitCode
        Output       = $output
        Content      = [string]$raw.Content
    }
    # powercfg /energy kończy się niezerowym kodem, gdy wykrył problemy — raport i tak powstał.
    $message = "Utworzono {0} na komputerze '{1}'{2}." -f $label, $ComputerName, $(if ([int]$raw.ExitCode -ne 0) { ' (powercfg zgłosił uwagi, kod {0})' -f $raw.ExitCode } else { '' })
    New-MwpResult @common -Success $true -Message $message -Data $report
}
