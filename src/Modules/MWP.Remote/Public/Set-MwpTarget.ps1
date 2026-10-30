function Set-MwpTarget {
    <#
    .SYNOPSIS
        Zmienia dane komputera zdalnego w rejestrze komputerów docelowych (config\settings.local.json).

    .DESCRIPTION
        Operacja klasy Zmiana na konfiguracji aplikacji (komputer lokalny): -WhatIf, -Confirm i log.
        Zmienia tylko podane pola: adres połączenia, nazwę wyświetlaną, sposób uwierzytelnienia,
        podpowiedź konta, port i HTTPS (wpis cofnięcia przez Set-MwpSetting). Hasło nie jest zapisywane
        w rejestrze komputerów (D-034). Otwarte instancje mają własne, niezmienne konteksty: zmiana
        obowiązuje dla nowych instancji. Funkcja nie zmienia konfiguracji WinRM ani TrustedHosts.

        Zmiana nazwy (-NewName, D-054) zmienia identyfikator komputera, więc przenosi wszystko, co jest
        do niego przypisane:
        1. zapisane hasło: wpis MWP:<stara> w Menedżerze poświadczeń Windows jest kopiowany do
           MWP:<nowa>, a stary usuwany dopiero po udanym zapisie ustawień (hasło nigdy nie trafia do
           logu ani wyniku; przenoszone zawsze, gdy wpis istnieje — jak usuwanie w Remove-MwpTarget —
           żeby nie został osierocony),
        2. wpis w rejestrze komputerów i computerName widgetów Pulpitu — jednym zapisem atomowym; gdy
           stara nazwa była adresem IPv4, a adres połączenia jest pusty, stara nazwa staje się adresem,
        3. wpisy cofnięcia w stanie Pending (Rename-MwpUndoComputer),
        4. sprawdzone hasło w pamięci podręcznej procesu (D-052).
        Odmowa (bez zmian): nowa nazwa niepoprawna, już w rejestrze albo oznacza komputer lokalny,
        albo dla komputera są otwarte instancje modułów lub widgetów (trzeba je najpierw zamknąć;
        podgląd -WhatIf tylko o tym uprzedza, żeby okno mogło pokazać podsumowanie przed zamknięciem widgetów).
        Gdy kopia hasła albo zapis ustawień się nie uda, nic nie zostaje zmienione (kopia hasła jest
        wycofywana). Późniejsze kroki (cofnięcia, pamięć, usunięcie starego wpisu hasła) przy błędzie
        dają ostrzeżenie w wyniku, a stan pozostaje spójny. Sama zmiana nazwy nie ma wpisu cofnięcia
        (cofnięcie samych ustawień rozspójniłoby hasło i wpisy cofnięcia) — wraca się do starej nazwy
        kolejnym -NewName. Data wyniku: Steps (krok, Success, Message), Moved (Credential, Widgets,
        UndoEntries, CachedCredential).

    .PARAMETER Name
        Nazwa komputera w rejestrze.

    .PARAMETER Address
        Adres połączenia (IPv4 albo nazwa DNS); pusty tekst czyści pole (połączenie po nazwie).

    .PARAMETER NewName
        Nowa nazwa (faktyczna nazwa komputera), np. odczytana przyciskiem „Odczytaj nazwę z komputera”.

    .EXAMPLE
        Set-MwpTarget -Name 'PC-BIURO' -UserName 'PC-BIURO\admin2' -WhatIf

    .EXAMPLE
        Set-MwpTarget -Name '192.0.2.10' -NewName 'PC-BIURO' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateNotNullOrEmpty()]
        [string] $NewName,

        [AllowEmptyString()]
        [string] $Address,

        [ValidateNotNullOrEmpty()]
        [string] $DisplayName,

        [ValidateSet('Credential', 'CurrentUser')]
        [string] $Authentication,

        [AllowEmptyString()]
        [ValidatePattern('^[^:;"/\[\]|=+*?<>]*$')]
        [string] $UserName,

        [ValidateRange(1, 65535)]
        [int] $Port,

        [bool] $UseSsl
    )

    $operation = 'Remote.SetTarget'
    $common = @{ Operation = $operation; Target = $Name; ComputerName = 'localhost' }

    $entries = @(Get-MwpTargetEntry)
    $existing = @($entries | Where-Object { [string]$_['name'] -eq $Name }) | Select-Object -First 1
    if ($null -eq $existing) {
        return New-MwpResult @common -Success $false -Message ("Komputera '{0}' nie ma w rejestrze komputerów docelowych." -f $Name)
    }

    $before = [ordered]@{}
    foreach ($key in $existing.Keys) {
        $before[$key] = $existing[$key]
    }
    $after = [ordered]@{}
    foreach ($key in $before.Keys) {
        $after[$key] = $before[$key]
    }

    $rename = $PSBoundParameters.ContainsKey('NewName') -and -not [string]::Equals($NewName, $Name, [StringComparison]::Ordinal)
    $caseOnly = $rename -and [string]::Equals($NewName, $Name, [StringComparison]::OrdinalIgnoreCase)
    if ($rename) {
        if (-not (Test-MwpTargetName -Name $NewName)) {
            return New-MwpResult @common -Success $false -Message ("Niepoprawna nazwa komputera '{0}' (dozwolone: nazwa NetBIOS/DNS albo adres IPv4)." -f $NewName)
        }
        if (Test-MwpLocalTargetName -Name $NewName) {
            return New-MwpResult @common -Success $false -Message ("Nazwa '{0}' oznacza komputer lokalny (localhost); nie można jej nadać komputerowi zdalnemu." -f $NewName)
        }
        if (-not $caseOnly -and @($entries | Where-Object { [string]$_['name'] -eq $NewName }).Count -gt 0) {
            return New-MwpResult @common -Success $false -Message ("Komputer '{0}' jest już w rejestrze komputerów docelowych." -f $NewName)
        }
        $after['name'] = $NewName
        $currentAddress = if ($after.Contains('address')) { [string]$after['address'] } else { '' }
        if (-not $PSBoundParameters.ContainsKey('Address') -and $currentAddress -eq '' -and (Test-MwpIPv4Address -Value $Name)) {
            $after.Insert(1, 'address', $Name)
        }
        if (-not $PSBoundParameters.ContainsKey('DisplayName') -and [string]$before['displayName'] -eq $Name) {
            $after['displayName'] = $NewName
        }
    }
    if ($PSBoundParameters.ContainsKey('Address')) {
        if ($Address -ne '' -and -not (Test-MwpTargetName -Name $Address)) {
            return New-MwpResult @common -Success $false -Message ("Niepoprawny adres połączenia '{0}' (dozwolone: adres IPv4 albo nazwa DNS)." -f $Address)
        }
        if ($Address -eq '' -or $Address -eq [string]$after['name']) {
            $after.Remove('address')
        }
        elseif ($after.Contains('address')) {
            $after['address'] = $Address
        }
        else {
            $after.Insert(1, 'address', $Address)
        }
    }
    $map = [ordered]@{ DisplayName = 'displayName'; Authentication = 'authentication'; UserName = 'userName'; Port = 'port'; UseSsl = 'useSsl' }
    foreach ($parameter in $map.Keys) {
        if ($PSBoundParameters.ContainsKey($parameter)) {
            $after[$map[$parameter]] = $PSBoundParameters[$parameter]
        }
    }
    # Zmiana HTTPS bez jawnego portu przestawia port domyślny (5985/5986).
    if ($PSBoundParameters.ContainsKey('UseSsl') -and -not $PSBoundParameters.ContainsKey('Port') -and [int]$before['port'] -in @(5985, 5986)) {
        $after['port'] = $(if ($UseSsl) { 5986 } else { 5985 })
    }

    $changes = @(foreach ($key in @(@($before.Keys) + @($after.Keys) | Select-Object -Unique)) {
            $old = if ($before.Contains($key)) { [string]$before[$key] } else { '' }
            $new = if ($after.Contains($key)) { [string]$after[$key] } else { '' }
            if (-not [string]::Equals($old, $new, [StringComparison]::Ordinal)) {
                "{0}: '{1}' -> '{2}'" -f $key, $old, $new
            }
        })
    if ($changes.Count -eq 0) {
        return New-MwpResult @common -Success $true -Before $before -After $after -Message ("Komputer '{0}': bez zmian." -f $Name)
    }

    # D-054: ostrzeżenia bez blokady — ten komputer jako zdalny, adres pomijany przy HTTPS.
    $notes = New-Object -TypeName System.Collections.Generic.List[string]
    $finalAddress = if ($after.Contains('address')) { [string]$after['address'] } else { '' }
    $self = Test-MwpTargetIsLocalComputer -Name ([string]$after['name']) -Address $finalAddress
    if ($self.IsLocalComputer) {
        $notes.Add($self.Message)
    }
    if ($finalAddress -ne '' -and [bool]$after['useSsl']) {
        $notes.Add(("Przy HTTPS połączenie idzie po nazwie '{0}' (certyfikat), adres '{1}' jest pomijany." -f $after['name'], $finalAddress))
    }
    $noteText = if ($notes.Count -gt 0) { ' Uwaga: {0}' -f ($notes -join ' ') } else { '' }

    if (-not $rename) {
        $target = Format-MwpOperationTarget -Target ("rejestr komputerów docelowych (zmiana '{0}': {1})" -f $Name, ($changes -join ', ')) -ComputerName 'localhost'
        if (-not $PSCmdlet.ShouldProcess($target, 'Zmiana komputera docelowego')) {
            return New-MwpResult @common -Success $true -IsPreview -Before $before -After $after `
                -Message ("Podgląd: komputer '{0}' — {1}.{2}" -f $Name, ($changes -join ', '), $noteText)
        }

        $updated = @(foreach ($entry in $entries) {
                if ([string]$entry['name'] -eq $Name) { $after } else { $entry }
            })
        $change = Set-MwpSetting -Name 'targets' -Value $updated -WhatIf:$false -Confirm:$false
        if (-not $change.Success) {
            return New-MwpResult @common -Success $false -Before $before -Message ("Nie udało się zmienić komputera '{0}': {1}" -f $Name, $change.Message) -ErrorMessage $change.ErrorMessage
        }
        $message = "Zmieniono komputer '{0}' w rejestrze komputerów docelowych ({1}).{2}" -f $Name, ($changes -join ', '), $noteText
        Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $message -Data $after
        return New-MwpResult @common -Success $true -Changed $true -Before $before -After $after -UndoId $change.UndoId -Message $message
    }

    # Zmiana nazwy: co zostanie przeniesione (podgląd i potwierdzenie).
    $operation = 'Remote.RenameTarget'
    $common.Operation = $operation
    $widgets = @()
    try {
        $widgets = @(Get-MwpSetting -Name 'dashboardWidgets')
    }
    catch {
        $widgets = @()
    }
    $widgetCount = @($widgets | Where-Object { $_ -is [Collections.IDictionary] -and [string]$_['computerName'] -eq $Name }).Count
    $storedInfo = if ($caseOnly) { $null } else { Test-MwpStoredCredential -ComputerName $Name }
    $hasStored = $null -ne $storedInfo -and $storedInfo.Status -eq 'Found'
    $undoCount = @(Get-MwpUndoEntry -ComputerName $Name -Status Pending -WarningAction SilentlyContinue).Count
    $summary = "zmiana nazwy '{0}' -> '{1}'; przeniesione: wpis rejestru ({2}), widgety Pulpitu: {3}, wpisy cofnięcia: {4}, zapisane hasło: {5}" -f `
        $Name, $NewName, ($changes -join ', '), $widgetCount, $undoCount, $(if ($hasStored) { 'tak' } else { 'brak' })

    # Otwarte instancje mają niezmienne konteksty ze starą nazwą: zmiana dopiero po ich zamknięciu (podgląd tylko uprzedza).
    $open = @($script:MwpInstanceRegistry.Values | Where-Object { $_.Context.ComputerName -eq $Name })
    $openText = "Komputer '{0}' ma otwarte instancje modułów lub widgetów ({1}); zamknij je przed zmianą nazwy." -f $Name, $open.Count
    if ($open.Count -gt 0) {
        $notes.Add(("Komputer '{0}' ma otwarte instancje modułów lub widgetów ({1}) — muszą być zamknięte przed zapisem (okno aplikacji zamyka i odtwarza widgety tego komputera samo)." -f $Name, $open.Count))
        $noteText = ' Uwaga: {0}' -f ($notes -join ' ')
    }
    $target = Format-MwpOperationTarget -Target ("rejestr komputerów docelowych ({0})" -f $summary) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Zmiana nazwy komputera docelowego')) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $after -Message ("Podgląd: {0}.{1}" -f $summary, $noteText) `
            -Data ([ordered]@{ Moved = [ordered]@{ Credential = $hasStored; Widgets = $widgetCount; UndoEntries = $undoCount; CachedCredential = $false }; Steps = @() })
    }

    if ($open.Count -gt 0) {
        return New-MwpResult @common -Success $false -Before $before -Message $openText
    }
    $steps = New-Object -TypeName System.Collections.Generic.List[object]
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    $moved = [ordered]@{ Credential = $false; Widgets = 0; UndoEntries = 0; CachedCredential = $false }
    $addStep = {
        param([string] $Step, [bool] $Ok, [string] $Text)
        $steps.Add([pscustomobject]@{ Step = $Step; Success = $Ok; Message = $Text })
    }
    $fail = {
        param([string] $Text)
        Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $Text
        New-MwpResult @common -Success $false -Before $before -Message $Text -Data ([ordered]@{ Moved = $moved; Steps = $steps.ToArray() })
    }

    # 1. Kopia zapisanego hasła pod nową nazwę (stary wpis zostaje do końca).
    $credentialCopied = $false
    if (-not $caseOnly) {
        $stored = Get-MwpStoredCredential -ComputerName $Name
        if ($stored.Status -eq 'Found') {
            $copy = Set-MwpStoredCredential -ComputerName $NewName -Credential $stored.Credential
            $stored.Credential = $null
            if (-not $copy.Success) {
                & $addStep 'Credential' $false $copy.Message
                return & $fail ("Nie zmieniono nazwy komputera '{0}': nie udało się przenieść zapisanego hasła ({1})." -f $Name, $copy.Message)
            }
            $credentialCopied = $true
            & $addStep 'Credential' $true ("Skopiowano zapisane hasło do wpisu MWP:{0}." -f $NewName)
        }
        elseif ($stored.Status -eq 'Error') {
            & $addStep 'Credential' $false $stored.Message
            return & $fail ("Nie zmieniono nazwy komputera '{0}': nie udało się odczytać Menedżera poświadczeń ({1})." -f $Name, $stored.Message)
        }
        elseif ($stored.Status -eq 'InvalidFormat') {
            $warnings.Add($stored.Message)
            & $addStep 'Credential' $false $stored.Message
        }
    }

    # 2. Rejestr komputerów i widgety Pulpitu — jeden zapis atomowy, bez wpisu cofnięcia.
    $updated = @(foreach ($entry in $entries) {
            if ([string]$entry['name'] -eq $Name) { $after } else { $entry }
        })
    $values = [ordered]@{ targets = $updated }
    if ($widgetCount -gt 0) {
        foreach ($widget in $widgets) {
            if ($widget -is [Collections.IDictionary] -and [string]$widget['computerName'] -eq $Name) {
                $widget['computerName'] = $NewName
            }
        }
        $values['dashboardWidgets'] = $widgets
    }
    $change = Set-MwpSetting -Values $values -NoUndo -WhatIf:$false -Confirm:$false
    if (-not $change.Success) {
        & $addStep 'Settings' $false $change.Message
        if ($credentialCopied) {
            $rollback = Remove-MwpStoredCredential -ComputerName $NewName
            & $addStep 'CredentialRollback' $rollback.Success $(if ($rollback.Success) { 'Wycofano kopię hasła.' } else { $rollback.Message })
        }
        return & $fail ("Nie zmieniono nazwy komputera '{0}': {1}" -f $Name, $change.Message)
    }
    $moved.Widgets = $widgetCount
    & $addStep 'Settings' $true ("Zapisano rejestr komputerów i {0} widgetów Pulpitu." -f $widgetCount)

    # 3. Wpisy cofnięcia oczekujące na cofnięcie.
    $undo = Rename-MwpUndoComputer -OldName $Name -NewName $NewName -Confirm:$false -WhatIf:$false
    $moved.UndoEntries = @($undo.Data['Renamed']).Count
    & $addStep 'UndoEntries' $undo.Success $undo.Message
    if (-not $undo.Success) {
        $warnings.Add($undo.Message)
    }

    if (-not $caseOnly) {
        # 4. Sprawdzone hasło w pamięci procesu (D-052) — bez ponownego pytania o hasło.
        $cached = Get-MwpCachedCredential -ComputerName $Name
        if ($null -ne $cached -and $cached['State'] -eq 'Verified' -and $null -ne $cached['Credential']) {
            $null = Set-MwpCachedCredential -ComputerName $NewName -Credential $cached['Credential'] -Source ([string]$cached['Source'])
            $moved.CachedCredential = $true
        }
        $null = Remove-MwpCachedCredential -ComputerName $Name
        & $addStep 'CachedCredential' $true $(if ($moved.CachedCredential) { 'Przeniesiono sprawdzone hasło w pamięci procesu.' } else { 'Brak sprawdzonego hasła w pamięci procesu.' })

        # 5. Stary wpis hasła — dopiero po udanym zapisie nowego i ustawień.
        if ($credentialCopied) {
            $remove = Remove-MwpStoredCredential -ComputerName $Name
            if ($remove.Success) {
                $moved.Credential = $true
                & $addStep 'CredentialCleanup' $true ("Usunięto stary wpis MWP:{0}." -f $Name)
            }
            else {
                $moved.Credential = $true
                $text = "Hasło przeniesione, ale nie udało się usunąć starego wpisu MWP:{0} ({1}); usuń go w Menedżerze poświadczeń Windows." -f $Name, $remove.Message
                $warnings.Add($text)
                & $addStep 'CredentialCleanup' $false $text
            }
        }
    }

    $message = "Zmieniono nazwę komputera '{0}' na '{1}' ({2}; widgety: {3}, wpisy cofnięcia: {4}, hasło: {5})." -f `
        $Name, $NewName, ($changes -join ', '), $moved.Widgets, $moved.UndoEntries, $(if ($moved.Credential) { 'przeniesione' } else { 'brak' })
    if ($warnings.Count -gt 0) {
        $message = '{0} Uwaga: {1}' -f $message, ($warnings -join ' ')
    }
    $message = '{0}{1}' -f $message, $noteText
    $level = if ($warnings.Count -gt 0) { 'Warning' } else { 'Info' }
    Write-MwpLog -Level $level -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $message -Data $after
    New-MwpResult @common -Success $true -Changed $true -Before $before -After $after -Message $message `
        -Data ([ordered]@{ Moved = $moved; Steps = $steps.ToArray() })
}
