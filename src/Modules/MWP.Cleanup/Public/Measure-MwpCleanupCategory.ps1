function Measure-MwpCleanupCategory {
    <#
    .SYNOPSIS
        Skanuje kategorie czyszczenia na komputerze docelowym (tylko odczyt): liczba plików i rozmiar na kategorię.

    .DESCRIPTION
        Operacja klasy Odczyt (D-027) — niczego nie usuwa. Najpierw odczyt lokalizacji komputera
        docelowego (Get-MwpCleanupEnvironment), potem jedno wywołanie bloku Process (Mode Scan) na
        kategorię. Liczone są tylko pliki pasujące do definicji kategorii (wzorce, próg wieku), wewnątrz
        jej katalogów, z pominięciem dowiązań i lokalizacji chronionych użytkownika (D-047).
        Profile użytkowników (D-019): lokalnie domyślnie tylko bieżące konto (-IncludeUserProfiles:
        wszystkie profile), zdalnie domyślnie żadne — tylko lokalizacje systemowe (-IncludeUserProfiles:
        jawny wybór wszystkich profili). Lokalizacje systemowe i cudze profile wymagają administratora
        na komputerze docelowym (bez niego są oznaczone jako niedostępne).
        -Progress (opcjonalna tabela: Percent, Message, CancelRequested — np. z zadania GUI) dostaje postęp
        po kategoriach; CancelRequested przerywa skan (lokalnie także w trakcie kategorii).
        Zwraca MWP.Result z MWP.CleanupScan w Data (Categories: MWP.CleanupCategoryResult).

    .PARAMETER Category
        Identyfikatory kategorii (domyślnie wszystkie).

    .EXAMPLE
        (Measure-MwpCleanupCategory).Data.Categories | Format-Table Name, FileCount, SizeText, SkippedCount

    .EXAMPLE
        (Measure-MwpCleanupCategory -Context $remote -IncludeUserProfiles).Data.TotalText
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [string[]] $Category,

        [switch] $IncludeUserProfiles,

        [AllowNull()]
        [hashtable] $Progress
    )

    $operation = 'Cleanup.Scan'
    $computerName = $Context.ComputerName
    $common = @{ Operation = $operation; Target = $computerName; ComputerName = $computerName }
    $isRemote = $Context.Mode -eq 'Remote'
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    $definitionWarnings = $null
    $definitions = @(Get-MwpCleanupCategory -WarningVariable definitionWarnings -WarningAction SilentlyContinue)
    foreach ($warning in @($definitionWarnings)) {
        $warnings.Add([string]$warning)
    }
    if ($PSBoundParameters.ContainsKey('Category')) {
        $known = @($definitions | ForEach-Object { $_.Id })
        foreach ($id in @($Category | Where-Object { $known -notcontains $_ })) {
            $warnings.Add(("Nieznana kategoria czyszczenia: '{0}'." -f $id))
        }
        $definitions = @($definitions | Where-Object { $Category -contains $_.Id })
    }

    if ($definitions.Count -eq 0) {
        return New-MwpResult @common -Success $false -Message ('Brak kategorii czyszczenia do skanowania. {0}' -f ($warnings -join ' ')).Trim()
    }

    $environment = Get-MwpCleanupEnvironment -Context $Context -Operation $operation
    if (-not $environment.Success) {
        return New-MwpResult @common -Success $false -Message $environment.Result.Message -ErrorMessage $environment.Result.ErrorMessage
    }
    $environment = $environment.Environment
    if ($environment.Error) {
        $warnings.Add(('Część danych o profilach i dyskach jest niepełna: {0}' -f $environment.Error))
    }
    if (-not $environment.IsAdministrator) {
        $warnings.Add(("Brak uprawnień administratora na komputerze '{0}': lokalizacje systemowe i profile innych użytkowników są pominięte." -f $computerName))
    }
    if ($isRemote -and -not $IncludeUserProfiles) {
        $warnings.Add('Komputer zdalny: skanowane są tylko lokalizacje systemowe; profile użytkowników — po jawnym wyborze (-IncludeUserProfiles).')
    }
    $selectedProfiles = @($environment.Profiles | Where-Object { $null -ne $_ -and ($IncludeUserProfiles -or (-not $isRemote -and $_.IsCurrent)) })

    $results = New-Object -TypeName System.Collections.Generic.List[object]
    $cancelled = $false
    $index = 0
    foreach ($definition in $definitions) {
        if ($null -ne $Progress) {
            if ($Progress['CancelRequested']) {
                $cancelled = $true
                break
            }
            $Progress['Percent'] = [int](100 * $index / [Math]::Max(1, $definitions.Count))
            $Progress['Message'] = 'Skanowanie: {0}' -f $definition.Name
        }
        $index++
        $roots = @(Resolve-MwpCleanupRoot -Category @($definition) -Environment $environment -Remote:$isRemote -IncludeUserProfiles:$IncludeUserProfiles)
        $available = @($roots | Where-Object { $_.Available })
        $raw = @()
        if ($available.Count -gt 0) {
            $process = Invoke-MwpCleanupProcess -Context $Context -Operation $operation -Root $available -Mode Scan -Protected @($environment.Protected) -Progress $Progress
            if (-not $process.Success) {
                return New-MwpResult @common -Success $false -Message ("Skan kategorii '{0}' na komputerze '{1}' nie powiódł się: {2}" -f $definition.Name, $computerName, $process.Result.Message) -ErrorMessage $process.Result.ErrorMessage
            }
            $raw = @($process.Raw.Roots)
            if ($process.Raw.Cancelled) {
                $cancelled = $true
            }
        }
        $results.Add((New-MwpCleanupCategoryResult -Category $definition -Root $roots -RawRoot $raw -Mode Scan))
        if ($cancelled) {
            break
        }
    }
    if ($null -ne $Progress) {
        $Progress['Percent'] = 100
        $Progress['Message'] = ''
    }
    if ($cancelled) {
        $warnings.Add('Skan przerwany — wyniki są niepełne.')
    }

    $totalBytes = [long]0
    $totalFiles = [long]0
    foreach ($item in $results) {
        $totalBytes += $item.SizeBytes
        $totalFiles += $item.FileCount
    }
    $scan = [pscustomobject]@{
        PSTypeName          = 'MWP.CleanupScan'
        ComputerName        = $computerName
        CollectedAt         = Get-Date
        IsAdministrator     = [bool]$environment.IsAdministrator
        IsRemote            = $isRemote
        IncludeUserProfiles = [bool]$IncludeUserProfiles
        UserProfiles        = @($selectedProfiles | ForEach-Object { [string]$_.UserName })
        Categories          = $results.ToArray()
        TotalFiles          = $totalFiles
        TotalBytes          = $totalBytes
        TotalText           = Format-MwpCleanupSize -Bytes $totalBytes
        Cancelled           = $cancelled
        Warnings            = $warnings.ToArray()
    }
    $message = "Skan komputera '{0}': {1} kategorii, do zwolnienia {2} ({3} plików){4}." -f $computerName, $results.Count, $scan.TotalText, $totalFiles, $(if ($cancelled) { ' — skan przerwany' } else { '' })
    New-MwpResult @common -Success $true -Message $message -Data $scan
}
