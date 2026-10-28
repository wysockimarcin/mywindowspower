function Get-MwpUpdateDetail {
    <#
    .SYNOPSIS
        Zwraca tytuł i tekst panelu szczegółów widoku Windows Update: wybrana aktualizacja (-Update) albo podsumowanie stanu (-Status).

    .DESCRIPTION
        Czysta funkcja (bez WPF). Aktualizacja: opis, KB, kategorie, rozmiar, data publikacji, restart,
        pobrana, obowiązkowa, adres pomocy i powód, dla którego aplikacja jej nie zainstaluje. Stan:
        ostatnie wyszukiwanie i instalacja, pauza, kopie folderów z resetu.

    .PARAMETER Update
        MWP.UpdateItem albo $null.

    .PARAMETER Status
        MWP.UpdateStatus albo $null.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Update')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Update')]
        [AllowNull()]
        [object] $Update,

        [Parameter(Mandatory, ParameterSetName = 'Status')]
        [AllowNull()]
        [object] $Status
    )

    $nl = [Environment]::NewLine
    if ($PSCmdlet.ParameterSetName -eq 'Status') {
        if ($null -eq $Status) {
            return [pscustomobject]@{ Title = 'Brak odczytu stanu Windows Update.'; Text = ''; Backup = '' }
        }
        $lines = @(
            'Ostatnie udane wyszukiwanie: {0} · ostatnia udana instalacja: {1}' -f $Status.LastSearchText, $Status.LastInstallText
            $Status.PauseText
        )
        $backups = @($Status.Backups)
        $backup = if ($backups.Count -eq 0) {
            'Brak kopii folderów z resetu.'
        }
        else {
            'Kopie z resetu: {0} (cofnięcie z listy zmian niżej albo Restore-MwpUpdateComponent -Suffix <sufiks>).' -f (@($backups | ForEach-Object { '{0} — {1}' -f $_.Suffix, (@($_.Folders) -join ', ') }) -join '; ')
        }
        return [pscustomobject]@{ Title = $Status.RebootText; Text = ($lines -join $nl); Backup = $backup }
    }
    if ($null -eq $Update) {
        return [pscustomobject]@{ Title = 'Wybierz aktualizację z listy (Ctrl lub Shift — kilka).'; Text = '' }
    }
    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    if ($Update.Description) {
        $lines.Add([string]$Update.Description)
    }
    $facts = @(
        $(if ($Update.KBText) { 'KB: ' + $Update.KBText })
        $(if ($Update.CategoryText) { 'Kategorie: ' + $Update.CategoryText })
        $(if ($Update.SizeText) { 'Rozmiar do pobrania: ' + $Update.SizeText })
        $(if ($null -ne $Update.Published) { 'Opublikowana: ' + ([datetime]$Update.Published).ToString('yyyy-MM-dd') })
        ('Restart: ' + $Update.RebootText)
        ('Pobrana: ' + $(if ($Update.IsDownloaded) { 'tak' } else { 'nie' }))
        $(if ($Update.IsMandatory) { 'Obowiązkowa' })
    ) | Where-Object { $_ }
    $lines.Add((@($facts) -join ' · '))
    if ($Update.SupportUrl) {
        $lines.Add(('Pomoc: ' + $Update.SupportUrl))
    }
    if (-not $Update.IsInstallable) {
        $lines.Add(('Aplikacja jej nie zainstaluje: ' + $Update.NotInstallableReason + '.'))
    }
    [pscustomobject]@{ Title = [string]$Update.Title; Text = ($lines -join $nl) }
}
