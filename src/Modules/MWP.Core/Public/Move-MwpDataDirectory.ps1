function Move-MwpDataDirectory {
    <#
    .SYNOPSIS
        Przenosi dane aplikacji (logs, undo, modules) do nowego katalogu i zmienia ustawienie dataPath.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027, D-038): -WhatIf, -Confirm i log. Kolejność:
        1. walidacja nowej wartości (Get-MwpDataLocation -DataPath): poprawna ścieżka, zapisywalny
           katalog, brak zagnieżdżenia z bieżącym katalogiem danych, brak danych w miejscu docelowym;
        2. podgląd i potwierdzenie (liczba plików w każdym podkatalogu);
        3. kopia podkatalogów do katalogu roboczego w miejscu docelowym (.mwp-move-<GUID>), potem
           przeniesienie ich na miejsce i zapis dataPath w settings.local.json;
        4. dopiero po udanym zapisie ustawienia — usunięcie danych ze starego miejsca.
        Błąd w krokach 3 usuwa kopię i nie zmienia ustawienia, więc dane nie zostają w połowie.
        Błąd usuwania starych danych nie cofa przeniesienia (dane są już w nowym miejscu); wynik
        zawiera ostrzeżenie z listą katalogów do usunięcia ręcznie.
        W trakcie kopiowania funkcja trzyma muteks logu (Local\MyWindowsPower.Log), żeby inne wątki
        nie dopisywały wpisów do przenoszonego pliku. Moduły z paczek już załadowane w procesie
        działają dalej; nowe położenie obowiązuje od następnego uruchomienia. Cofnięcie: ponowne
        wywołanie z poprzednią wartością dataPath (podaną w komunikacie wyniku). Wpisu w rejestrze
        cofnięć nie ma, bo rejestr cofnięć jest częścią przenoszonych danych (wpis znalazłby się
        w katalogu, który jego wykonanie przenosi).
        Bez automatycznej migracji przy starcie (D-032). Dotyczy tylko komputera, na którym działa host.

    .PARAMETER DataPath
        Nowa wartość ustawienia dataPath (pusta = <folder aplikacji>\data).

    .EXAMPLE
        Move-MwpDataDirectory -DataPath 'D:\Dane MWP' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $DataPath
    )

    $operation = 'DataPath.Move'
    $computerName = 'localhost'
    $common = @{ Operation = $operation; Target = 'dataPath'; ComputerName = $computerName }
    $fail = {
        param($Message)
        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $Message
        New-MwpResult @common -Success $false -Message $Message
    }

    $subdirectories = @('logs', 'undo', 'modules')
    $current = Get-MwpDataPath -Detailed
    $source = $current.Root.TrimEnd([char]92)
    $target = Get-MwpDataLocation -DataPath $DataPath
    if (-not $target.IsValid) {
        return & $fail $target.Error
    }
    if (-not $target.Writable) {
        return & $fail ("Katalog '{0}' jest niezapisywalny; dane nie zostały przeniesione." -f $target.Root)
    }
    $destination = $target.Root.TrimEnd([char]92)
    $before = $current.Configured
    $after = $target.Configured
    if ($target.IsCurrent) {
        if ($before -eq $after) {
            return New-MwpResult @common -Success $true -Before $before -After $after -Message ("Dane już są w katalogu '{0}'." -f $destination)
        }
    }
    else {
        foreach ($name in $subdirectories) {
            $sourceItem = [IO.Path]::Combine($source, $name) + [IO.Path]::DirectorySeparatorChar
            $destinationItem = [IO.Path]::Combine($destination, $name) + [IO.Path]::DirectorySeparatorChar
            if (($destination + [IO.Path]::DirectorySeparatorChar).StartsWith($sourceItem, [StringComparison]::OrdinalIgnoreCase) -or
                ($source + [IO.Path]::DirectorySeparatorChar).StartsWith($destinationItem, [StringComparison]::OrdinalIgnoreCase)) {
                return & $fail ("Nowy katalog danych '{0}' nie może leżeć wewnątrz danych bieżącego katalogu '{1}' (ani odwrotnie)." -f $destination, $source)
            }
        }
        if ($target.HasData) {
            return & $fail ("W katalogu '{0}' są już dane aplikacji (logs, undo albo modules); wybierz pusty katalog albo usuń je ręcznie." -f $destination)
        }
    }

    # Podgląd: co zostanie przeniesione.
    $items = @(foreach ($name in $subdirectories) {
            $path = [IO.Path]::Combine($source, $name)
            if (-not $target.IsCurrent -and [IO.Directory]::Exists($path)) {
                [pscustomobject]@{ Name = $name; Path = $path; Files = @([IO.Directory]::GetFiles($path, '*', [IO.SearchOption]::AllDirectories)).Count }
            }
        })
    $summary = if ($items.Count -eq 0) { 'brak danych do przeniesienia' } else { (@($items | ForEach-Object { '{0} ({1} plików)' -f $_.Name, $_.Files }) -join ', ') }
    $description = "katalog danych '{0}' -> '{1}' ({2}); dataPath: '{3}' -> '{4}'" -f $source, $destination, $summary, $before, $after
    $operationTarget = Format-MwpOperationTarget -Target $description -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($operationTarget, 'Przeniesienie danych aplikacji')) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $after -Data $items `
            -Message ("Podgląd: {0}." -f $description)
    }

    $staging = [IO.Path]::Combine($destination, ('.mwp-move-{0}' -f [guid]::NewGuid().ToString('N')))
    $moved = New-Object -TypeName System.Collections.Generic.List[string]
    $mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, 'Local\MyWindowsPower.Log'
    $acquired = $false
    try {
        try {
            $acquired = $mutex.WaitOne(30000)
        }
        catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
        }
        if (-not $acquired) {
            return & $fail 'Plik logu jest zajęty przez inną operację; spróbuj ponownie za chwilę.'
        }

        try {
            if ($items.Count -gt 0) {
                $null = [IO.Directory]::CreateDirectory($staging)
                foreach ($item in $items) {
                    $null = Copy-MwpDirectory -Path $item.Path -Destination ([IO.Path]::Combine($staging, $item.Name))
                }
                foreach ($item in $items) {
                    $final = [IO.Path]::Combine($destination, $item.Name)
                    if ([IO.Directory]::Exists($final)) {
                        # Pusty katalog (sprawdzone wyżej przez HasData).
                        [IO.Directory]::Delete($final, $true)
                    }
                    Move-MwpDirectory -Path ([IO.Path]::Combine($staging, $item.Name)) -Destination $final
                    $moved.Add($final)
                }
                [IO.Directory]::Delete($staging, $true)
            }
            Write-MwpLocalSetting -Values @{ dataPath = $after } -Data (Read-MwpSettingsData)
        }
        catch {
            $errorMessage = $_.Exception.Message
            foreach ($path in @($moved) + $staging) {
                try {
                    if ([IO.Directory]::Exists($path)) {
                        [IO.Directory]::Delete($path, $true)
                    }
                }
                catch {
                    $errorMessage = "{0} Nie udało się usunąć kopii '{1}': {2}" -f $errorMessage, $path, $_.Exception.Message
                }
            }
            $message = "Nie udało się przenieść danych do '{0}'; dane zostały w '{1}', ustawienie dataPath bez zmian: {2}" -f $destination, $source, $errorMessage
            Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message
            return New-MwpResult @common -Success $false -Before $before -Message $message -ErrorMessage $errorMessage
        }

        # Ustawienie zapisane: stare dane można usunąć. Błąd nie cofa przeniesienia.
        $leftovers = @(foreach ($item in $items) {
                try {
                    [IO.Directory]::Delete($item.Path, $true)
                }
                catch {
                    $item.Path
                }
            })
        $message = "Przeniesiono dane aplikacji z '{0}' do '{1}' ({2}). Powrót: Przenieś dane z poprzednią wartością dataPath '{3}'." -f $source, $destination, $summary, $before
        if ($leftovers.Count -gt 0) {
            $message = "{0} Nie udało się usunąć starych katalogów (usuń je ręcznie): {1}." -f $message, ($leftovers -join ', ')
        }
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $operation -ComputerName $computerName -Message $message `
            -Data @{ From = $source; To = $destination; Before = $before; After = $after }
        New-MwpResult @common -Success $true -Changed $true -Before $before -After $after -Data $items -Message $message
    }
    finally {
        if ($acquired) {
            $mutex.ReleaseMutex()
        }
        $mutex.Dispose()
    }
}
