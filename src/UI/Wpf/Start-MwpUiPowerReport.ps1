function Start-MwpUiPowerReport {
    <#
    .SYNOPSIS
        Tworzy raport baterii albo energii na komputerze instancji w tle, zapisuje go w folderze z widoku i otwiera.

    .DESCRIPTION
        New-MwpPowerReport -AsOperation (raport powstaje na komputerze docelowym, treść wraca przez
        połączenie), potem w wątku okna Save-MwpPowerReport (folder z pola „Folder”, domyślnie
        <katalog danych>\reports) i Open-MwpPowerReport (przeglądarka komputera lokalnego, D-044).
        Raport energii trwa tyle, ile czas pomiaru (5–600 s); można go anulować z paska stanu.

    .PARAMETER Kind
        Battery albo Energy.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Raport nie zmienia ustawień systemu; zapis pliku raportu w wybranym folderze.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [Parameter(Mandatory)]
        [ValidateSet('Battery', 'Energy')]
        [string] $Kind,

        [AllowNull()]
        [object] $Owner
    )

    $p = $Entry.ModuleView.Controls
    $context = $Entry.Instance.Context
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        Show-MwpMessage -Text ('Najpierw połącz instancję z komputerem {0} (przycisk „Połącz”), żeby podać poświadczenia.' -f $context.ComputerName) -Owner $Owner
        return
    }
    $duration = 60
    if ($Kind -eq 'Energy') {
        $text = $p['EnergyDurationBox'].Text.Trim()
        if (-not [int]::TryParse($text, [ref]$duration) -or $duration -lt 5 -or $duration -gt 600) {
            Show-MwpMessage -Text 'Czas pomiaru raportu energii: liczba sekund od 5 do 600.' -Kind Warning -Owner $Owner
            return
        }
    }
    $folder = $p['ReportFolderBox'].Text.Trim()
    $operation = New-MwpPowerReport -Kind $Kind -Context $context -DurationSeconds $duration -AsOperation
    $label = if ($Kind -eq 'Battery') { 'raport baterii' } else { 'raport energii ({0} s)' -f $duration }
    $Entry.Power.Reporting = $true
    $p['ReportText'].Text = 'Tworzenie: {0} na komputerze {1}…' -f $label, $context.ComputerName
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation $operation -Name ('Zasilanie: {0} ({1})' -f $label, $context.ComputerName) `
        -State @{ InstanceId = $Entry.Id; Folder = $folder; Owner = $Owner } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Power.Reporting = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $parameters = @{ Report = $result }
        if ($Task.State.Folder) {
            $parameters['Directory'] = $Task.State.Folder
        }
        $saved = Save-MwpPowerReport @parameters -Confirm:$false
        $text = $entry.ModuleView.Controls['ReportText']
        if ($saved.Success) {
            $entry.Power.LastReport = $saved.Data.Path
            $text.Text = $saved.Message
            $open = Open-MwpPowerReport -Path $saved.Data.Path
            if (-not $open.Success) {
                $text.Text = '{0} {1}' -f $saved.Message, $open.Message
            }
        }
        else {
            $text.Text = $saved.Message
            Show-MwpMessage -Text $saved.Message -Kind Warning -Owner $Task.State.Owner
        }
        Update-MwpPowerView -Entry $entry -StateOnly
    }
    Update-MwpPowerView -Entry $Entry -StateOnly
}
