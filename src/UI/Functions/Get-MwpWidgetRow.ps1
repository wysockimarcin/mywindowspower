function Get-MwpWidgetRow {
    <#
    .SYNOPSIS
        Zamienia widgety Dashboardu na wiersze do szablonu kafelka (bez WPF).

    .DESCRIPTION
        Wiersz: Id, Title, Subtitle (komputer, typ widgetu, częstotliwość), State (plakietka:
        Label, Tone), Message (skrócony do 300 znaków; pełny w MessageFull — podpowiedź) i MessageVisibility, Summary, Sections (z MWP.WidgetView: Title, Items —
        Label, Value, Percent, Tone, BarVisibility), Footer (czas ostatniego odświeżenia, ostrzeżenia
        odczytu), Width (Normal 420, Wide 864), przyciski: ConnectVisibility (komputer zdalny bez
        poświadczeń albo po utracie połączenia), ExportEnabled, CanMoveLeft, CanMoveRight, IsBusy.

    .PARAMETER Widget
        Widgety w kolejności wyświetlania.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Widget = @()
    )

    $active = @($Widget | Where-Object { $null -ne $_ -and -not $_.Removed })
    $refreshNames = @{ 0 = 'odświeżanie ręczne'; 30 = 'co 30 s'; 60 = 'co 1 min'; 300 = 'co 5 min'; 900 = 'co 15 min' }
    for ($index = 0; $index -lt $active.Count; $index++) {
        $item = $active[$index]
        $config = $item.Config
        $title = if ([string]$config['title']) { [string]$config['title'] } else { $item.Definition.Name }
        $refresh = [int]$config['refreshSeconds']
        $isRemote = $null -ne $item.Instance -and $item.Instance.Context.Mode -eq 'Remote'
        $sections = @()
        $summary = $null
        $warnings = @()
        if ($null -ne $item.View) {
            $summary = $item.View.Summary
            $warnings = @($item.View.Warnings | Where-Object { $_ })
            $sections = @(foreach ($section in @($item.View.Sections)) {
                    [pscustomobject]@{
                        Title = $section.Title
                        Items = @(foreach ($row in @($section.Items)) {
                                [pscustomobject]@{
                                    Label         = $row.Label
                                    Value         = $row.Value
                                    Percent       = $(if ($row.Percent -ge 0) { [double]$row.Percent } else { 0 })
                                    Tone          = $row.Tone
                                    BarVisibility = $(if ($row.Percent -ge 0) { 'Visible' } else { 'Collapsed' })
                                }
                            })
                    }
                })
        }
        $footer = if ($null -ne $item.LastRefresh) { 'Odświeżono {0:HH:mm:ss}' -f $item.LastRefresh } else { 'Jeszcze nie odświeżono' }
        if ($null -ne $item['LastAttempt'] -and $item.Status -in @('Error', 'ConnectionLost', 'NeedsCredential')) {
            $footer = '{0} · ostatnia próba {1:HH:mm:ss}' -f $footer, $item.LastAttempt
        }
        if ($warnings.Count -gt 0) {
            $footer = '{0} · ostrzeżenia odczytu: {1}' -f $footer, ($warnings -join '; ')
        }
        $message = [string]$item.Message
        if (-not $message -and $null -eq $item.View -and $item.Status -in @('Idle', 'Loading')) {
            $message = 'Wczytywanie danych…'
        }
        [pscustomobject]@{
            Id                = $item.Id
            Title             = $title
            Subtitle          = '{0} · {1} · {2}' -f $config['computerName'], $item.Definition.Name, $refreshNames[$refresh]
            State             = Get-MwpWidgetStateInfo -Status $item.Status
            Message           = $(if ($message.Length -gt 300) { $message.Substring(0, 297) + '…' } else { $message })
            MessageFull       = $message
            MessageVisibility = $(if ($message) { 'Visible' } else { 'Collapsed' })
            Summary           = $summary
            Sections          = $sections
            Footer            = $footer
            # [double] wprost: wartość z podwyrażenia jest opakowana w PSObject i wiązanie Width w WPF jej nie konwertuje.
            Width             = [double]$(if ($config['size'] -eq 'Wide') { 864 } else { 420 })
            ConnectVisibility = $(if ($isRemote -and $item.Status -in @('NeedsCredential', 'ConnectionLost')) { 'Visible' } else { 'Collapsed' })
            ExportEnabled     = $null -ne $item.Definition.ExportCommand -and $null -ne $item.Data
            CanMoveLeft       = $index -gt 0
            CanMoveRight      = $index -lt $active.Count - 1
            IsBusy            = $null -ne $item.Task
        }
    }
}
