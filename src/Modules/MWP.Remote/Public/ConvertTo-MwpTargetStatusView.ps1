function ConvertTo-MwpTargetStatusView {
    <#
    .SYNOPSIS
        Zamienia stan komputerów z rejestru na widok widgetu „Komputery” (MWP.WidgetView).

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF i bez połączeń. Jeden wiersz
        na komputer zdalny: dostępność portu WinRM (z czasem odpowiedzi) albo — bez prób połączenia —
        stan hasła w pamięci aplikacji. Zwraca $null, gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu (Probe); próby połączenia wykonuje funkcja danych.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043); Probe stosuje funkcja danych.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    $status = Resolve-MwpTargetStatus -Data $Data
    if ($null -eq $status) {
        return $null
    }
    $targets = @($status.Targets)
    $items = @(foreach ($target in $targets) {
            $label = $(if ($target.DisplayName -and $target.DisplayName -ne $target.Name) { '{0} ({1})' -f $target.DisplayName, $target.Name } else { $target.Name })
            if ($status.Probe) {
                $value = if ($true -eq $target.Reachable) { 'dostępny · {0} ms · {1}' -f $target.LatencyMs, $target.CredentialText } elseif ($target.Error) { 'niedostępny: {0}' -f $target.Error } else { 'niedostępny' }
                $tone = if ($true -eq $target.Reachable) { $(if ($target.Credential -eq 'Invalid') { 'Warning' } else { 'Success' }) } else { 'Danger' }
            }
            else {
                $value = $target.CredentialText
                $tone = if ($target.Credential -eq 'Invalid') { 'Warning' } elseif ($target.Credential -eq 'Verified') { 'Success' } else { 'Neutral' }
            }
            [pscustomobject]@{ Label = $label; Value = $value; Percent = -1; Tone = $tone }
        })
    if ($items.Count -eq 0) {
        $items = @([pscustomobject]@{ Label = 'Komputery zdalne'; Value = 'brak — dodaj komputer w Ustawieniach'; Percent = -1; Tone = 'Neutral' })
    }
    $reachable = @($targets | Where-Object { $true -eq $_.Reachable }).Count
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = $(if ($status.Probe) { 'Komputery zdalne: {0} · dostępne {1}' -f $targets.Count, $reachable } else { 'Komputery zdalne: {0}' -f $targets.Count })
        CollectedAt = $status.CollectedAt
        Sections    = @([pscustomobject]@{ Title = 'Port WinRM'; Items = $items })
        Warnings    = @()
    }
}
