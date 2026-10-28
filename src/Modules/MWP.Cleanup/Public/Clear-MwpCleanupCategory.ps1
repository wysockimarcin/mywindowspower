function Clear-MwpCleanupCategory {
    <#
    .SYNOPSIS
        Trwale usuwa pliki wybranych kategorii czyszczenia na komputerze docelowym — dopiero po potwierdzeniu, z raportem.

    .DESCRIPTION
        Operacja klasy Destrukcyjna (D-027, ConfirmImpact High: przy domyślnym $ConfirmPreference
        zawsze pyta; -WhatIf daje podgląd). Dla każdej kategorii: rozwinięcie lokalizacji na komputerze
        docelowym, skan (liczba plików i rozmiar do podglądu i potwierdzenia z nazwą komputera), potem
        usuwanie w tym samym bloku zasad co skan (D-047): tylko pliki pasujące do definicji, tylko
        wewnątrz katalogów kategorii, bez wchodzenia w dowiązania (junction/symlink), z pominięciem
        lokalizacji chronionych użytkownika (pulpit, dokumenty itp.) i plików w użyciu; puste katalogi
        usuwane bez rekurencji. Usunięcia nie można cofnąć (brak wpisu w rejestrze cofnięć); log
        zapisuje początek i wynik każdej kategorii z nazwą komputera. Lokalizacje systemowe i cudze
        profile wymagają administratora na komputerze docelowym (bez niego kategoria jest odrzucana
        przed podglądem). Profile użytkowników jak w Measure-MwpCleanupCategory (zdalnie tylko
        z -IncludeUserProfiles). Zwraca jeden MWP.Result na kategorię (Data: MWP.CleanupCategoryResult
        z liczbą usuniętych i pominiętych plików według powodu); raport zbiorczy: ConvertTo-MwpCleanupReport.

    .PARAMETER Category
        Identyfikatory kategorii (Get-MwpCleanupCategory).

    .PARAMETER Progress
        Opcjonalna tabela postępu (Percent, Message, CancelRequested): CancelRequested zatrzymuje pracę
        po bieżącym pliku (lokalnie) albo przed następną kategorią.

    .EXAMPLE
        Clear-MwpCleanupCategory -Category UserTemp, RecycleBin -WhatIf

    .EXAMPLE
        Clear-MwpCleanupCategory -Category WindowsTemp -Context $remote | ConvertTo-MwpCleanupReport
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Category,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [switch] $IncludeUserProfiles,

        [AllowNull()]
        [hashtable] $Progress
    )

    $operation = 'Cleanup.Clear'
    $computerName = $Context.ComputerName
    $isRemote = $Context.Mode -eq 'Remote'
    $definitions = @(Get-MwpCleanupCategory -WarningAction SilentlyContinue)
    $environment = $null
    $index = 0

    foreach ($id in $Category) {
        $common = @{ Operation = $operation; Target = $id; ComputerName = $computerName }
        $definition = @($definitions | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
        if ($null -ne $Progress) {
            if ($Progress['CancelRequested']) {
                New-MwpResult @common -Success $false -Message ("Pominięto kategorię '{0}': czyszczenie anulowane." -f $id)
                continue
            }
            $Progress['Percent'] = [int](100 * $index / [Math]::Max(1, $Category.Count))
            $Progress['Message'] = 'Czyszczenie: {0}' -f $(if ($null -ne $definition) { $definition.Name } else { $id })
        }
        $index++
        if ($null -eq $definition) {
            New-MwpResult @common -Success $false -Message ("Nieznana albo niepoprawna kategoria czyszczenia: '{0}'." -f $id)
            continue
        }
        if ($null -eq $environment) {
            $read = Get-MwpCleanupEnvironment -Context $Context -Operation $operation
            if (-not $read.Success) {
                New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
                continue
            }
            $environment = $read.Environment
        }

        # 1. Lokalizacje i uprawnienia — przed podglądem.
        $roots = @(Resolve-MwpCleanupRoot -Category @($definition) -Environment $environment -Remote:$isRemote -IncludeUserProfiles:$IncludeUserProfiles)
        $available = @($roots | Where-Object { $_.Available })
        if ($available.Count -eq 0) {
            $summary = New-MwpCleanupCategoryResult -Category $definition -Root $roots -Mode Scan
            $reason = if (@($roots | Where-Object { $_.Reason -eq 'RequiresAdmin' }).Count -gt 0) {
                "wymagane uprawnienia administratora na komputerze '{0}'" -f $computerName
            }
            elseif (@($roots | Where-Object { $_.Reason -eq 'UserProfilesNotSelected' }).Count -gt 0) {
                'kategoria dotyczy profili użytkowników — na komputerze zdalnym tylko po jawnym wyborze profili (-IncludeUserProfiles)'
            }
            else {
                $summary.Notes -join ' '
            }
            New-MwpResult @common -Success $false -Message ("Kategoria '{0}' nie może być wyczyszczona: {1}." -f $definition.Name, $reason) -Data $summary
            continue
        }

        # 2. Stan przed zmianą — skan tych samych lokalizacji.
        $scan = Invoke-MwpCleanupProcess -Context $Context -Operation $operation -Root $available -Mode Scan -Protected @($environment.Protected) -Progress $Progress
        if (-not $scan.Success) {
            New-MwpResult @common -Success $false -Message ("Skan kategorii '{0}' przed czyszczeniem nie powiódł się: {1}" -f $definition.Name, $scan.Result.Message) -ErrorMessage $scan.Result.ErrorMessage
            continue
        }
        $before = New-MwpCleanupCategoryResult -Category $definition -Root $roots -RawRoot @($scan.Raw.Roots) -Mode Scan
        $beforeText = '{0} plików, {1}' -f $before.FileCount, $before.SizeText
        $skipNote = if ($before.SkippedCount -gt 0) {
            ' Pominięte: {0}.' -f (@($before.Skipped | ForEach-Object { '{0} — {1} ({2})' -f $_.ReasonText, $_.Count, $_.SizeText }) -join '; ')
        }
        else {
            ''
        }
        if ($before.FileCount -eq 0) {
            $scanErrors = @($before.Roots | Where-Object { $_.Error })
            if ($scanErrors.Count -gt 0) {
                New-MwpResult @common -Success $false -Before $beforeText -Data $before `
                    -Message ("Kategoria '{0}' na komputerze '{1}' — błędy lokalizacji: {2}" -f $definition.Name, $computerName, (@($scanErrors | ForEach-Object { '{0}: {1}' -f $_.Path, $_.Error }) -join '; '))
                continue
            }
            New-MwpResult @common -Success $true -Before $beforeText -After $beforeText -Message ("Nic do usunięcia: '{0}' na komputerze '{1}'.{2}" -f $definition.Name, $computerName, $skipNote) -Data $before
            continue
        }

        # 3. Podgląd i potwierdzenie z nazwą komputera.
        $target = Format-MwpOperationTarget -Target ("kategoria czyszczenia '{0}'" -f $definition.Name) -ComputerName $computerName
        if (-not $PSCmdlet.ShouldProcess($target, ('Trwałe usunięcie {0} plików ({1}); operacji nie można cofnąć' -f $before.FileCount, $before.SizeText))) {
            New-MwpResult @common -Success $true -IsPreview -Before $beforeText -After 'Usunięte' `
                -Message ("Podgląd: '{0}' — {1} plików, {2} do trwałego usunięcia.{3}" -f $definition.Name, $before.FileCount, $before.SizeText, $skipNote) -Data $before
            continue
        }

        # 4. Usuwanie (ten sam blok zasad), log początku i wyniku; bez wpisu cofnięcia.
        Write-MwpLog -Level Info -Source 'MWP.Cleanup' -Operation $operation -ComputerName $computerName `
            -Message ("Rozpoczęto czyszczenie '{0}': {1}." -f $definition.Name, $beforeText) -Data @{ Category = $id; Roots = @($available | ForEach-Object { $_.Path }) }
        $delete = Invoke-MwpCleanupProcess -Context $Context -Operation $operation -Root $available -Mode Delete -Protected @($environment.Protected) -Progress $Progress
        if (-not $delete.Success) {
            $message = "Czyszczenie '{0}' na komputerze '{1}' nie powiodło się (część plików mogła zostać usunięta): {2}" -f $definition.Name, $computerName, $delete.Result.Message
            Write-MwpLog -Level Error -Source 'MWP.Cleanup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Category = $id }
            New-MwpResult @common -Success $false -Before $beforeText -Message $message -ErrorMessage $delete.Result.ErrorMessage
            continue
        }
        $after = New-MwpCleanupCategoryResult -Category $definition -Root $roots -RawRoot @($delete.Raw.Roots) -Mode Delete
        $rootErrors = @($after.Roots | Where-Object { $_.Error })
        $skipText = if ($after.SkippedCount -gt 0) {
            ' Pominięto {0} plików ({1}): {2}.' -f $after.SkippedCount, $after.SkippedText, (@($after.Skipped | ForEach-Object { '{0} — {1}' -f $_.ReasonText, $_.Count }) -join '; ')
        }
        else {
            ''
        }
        $message = "Wyczyszczono '{0}' na komputerze '{1}': usunięto {2} plików ({3}).{4}{5}{6} Usunięcia nie można cofnąć." -f $definition.Name, $computerName,
        $after.DeletedCount, $after.DeletedText, $skipText, $(if ($after.Cancelled) { ' Czyszczenie przerwane przez użytkownika.' } else { '' }),
        $(if ($rootErrors.Count -gt 0) { ' Błędy lokalizacji: ' + (@($rootErrors | ForEach-Object { '{0}: {1}' -f $_.Path, $_.Error }) -join '; ') + '.' } else { '' })
        $level = if ($rootErrors.Count -gt 0) { 'Error' } elseif (@($after.Skipped | Where-Object { $_.Reason -ne 'TooNew' }).Count -gt 0) { 'Warning' } else { 'Info' }
        $skippedData = @{}
        foreach ($row in @($after.Skipped)) {
            $skippedData[$row.Reason] = $row.Count
        }
        Write-MwpLog -Level $level -Source 'MWP.Cleanup' -Operation $operation -ComputerName $computerName -Message $message `
            -Data @{ Category = $id; Deleted = $after.DeletedCount; DeletedBytes = $after.DeletedBytes; Directories = $after.DirectoriesRemoved; Skipped = $skippedData; Cancelled = $after.Cancelled }
        $success = -not ($rootErrors.Count -gt 0 -and $after.DeletedCount -eq 0)
        New-MwpResult @common -Success $success -Changed ($after.DeletedCount -gt 0 -or $after.DirectoriesRemoved -gt 0) -Before $beforeText `
            -After ('usunięto {0} plików ({1})' -f $after.DeletedCount, $after.DeletedText) -Message $message -Data $after
    }
    if ($null -ne $Progress) {
        $Progress['Percent'] = 100
    }
}
