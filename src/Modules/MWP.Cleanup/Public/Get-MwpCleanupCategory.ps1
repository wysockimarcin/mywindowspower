function Get-MwpCleanupCategory {
    <#
    .SYNOPSIS
        Zwraca definicje kategorii czyszczenia z pliku danych modułu (Data\cleanup-categories.json) po walidacji.

    .DESCRIPTION
        Kategorie są danymi, nie kodem (D-047). Każda ma identyfikator, nazwę, opis i listę katalogów
        głównych (path z tokenem, recurse, patterns, minAgeDays, removeEmptyDirectories, exclude).
        Dozwolone ścieżki (biała lista): {SystemRoot}\(Temp|SoftwareDistribution\Download|ServiceProfiles|Logs)\…,
        {ProgramData}\Microsoft\Windows\WER\…, {UserProfile}\AppData\(Local|Roaming|LocalLow)\…
        oraz {RecycleBin} (<dysk lokalny>\$Recycle.Bin\<SID>). Segmenty „.” i „..”, symbole wieloznaczne
        w ścieżce i wzorce z separatorem są odrzucane. Kategoria z błędem nie jest zwracana (ostrzeżenie),
        chyba że podano -IncludeInvalid (pola IsValid i Errors). Operacja klasy Odczyt, lokalna.

    .PARAMETER Id
        Tylko kategorie o tych identyfikatorach.

    .EXAMPLE
        Get-MwpCleanupCategory | Format-Table Id, Name, Scope
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Id,

        [switch] $IncludeInvalid
    )

    $path = Get-MwpCleanupDefinitionPath
    try {
        $data = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)) -ErrorAction Stop
    }
    catch {
        Write-Warning ("Nie udało się odczytać definicji kategorii czyszczenia ({0}): {1}" -f $path, $_.Exception.Message)
        return
    }

    $tokenRules = @{
        SystemRoot  = @{ First = @('Temp', 'SoftwareDistribution', 'ServiceProfiles', 'Logs'); MinDepth = 1 }
        ProgramData = @{ First = @('Microsoft'); MinDepth = 4 }
        UserProfile = @{ First = @('AppData'); MinDepth = 3 }
    }
    # Pola opcjonalne czytane bez błędu trybu ścisłego (brak pola = $null).
    $field = {
        param($Object, [string] $Name)
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) { $property.Value } else { $null }
    }
    $seen = @{}
    foreach ($category in @((& $field $data 'categories') | Where-Object { $null -ne $_ })) {
        $errors = New-Object -TypeName System.Collections.Generic.List[string]
        $categoryId = [string](& $field $category 'id')
        if ($categoryId -notmatch '^[A-Za-z][A-Za-z0-9]{1,40}$') {
            $errors.Add(("Niepoprawny identyfikator kategorii: '{0}'." -f $categoryId))
        }
        elseif ($seen.ContainsKey($categoryId)) {
            $errors.Add(("Powtórzony identyfikator kategorii: '{0}'." -f $categoryId))
        }
        $seen[$categoryId] = $true
        if (-not [string](& $field $category 'name')) {
            $errors.Add('Brak nazwy kategorii.')
        }
        $roots = @()
        foreach ($root in @((& $field $category 'roots') | Where-Object { $null -ne $_ })) {
            $rootPath = [string](& $field $root 'path')
            $token = $null
            $segments = @()
            if ($rootPath -eq '{RecycleBin}') {
                $token = 'RecycleBin'
            }
            elseif ($rootPath -match '^\{(SystemRoot|ProgramData|UserProfile)\}\\(.+)$') {
                $token = $Matches[1]
                $segments = @($Matches[2].Split('\'))
                $rule = $tokenRules[$token]
                $badSegment = @($segments | Where-Object { -not $_ -or $_ -in '.', '..' -or $_.IndexOfAny([char[]]'/:*?"<>|{}') -ge 0 -or $_ -ne $_.Trim() -or $_.EndsWith('.') })
                if ($badSegment.Count -gt 0) {
                    $errors.Add(("Niepoprawny segment ścieżki w '{0}'." -f $rootPath))
                }
                elseif ($rule.First -notcontains $segments[0] -or $segments.Count -lt $rule.MinDepth) {
                    $errors.Add(("Ścieżka '{0}' leży poza dozwolonymi lokalizacjami tokenu {{{1}}}." -f $rootPath, $token))
                }
                elseif ($token -eq 'ProgramData' -and ($segments[1] -ne 'Windows' -or $segments[2] -ne 'WER')) {
                    $errors.Add(("Ścieżka '{0}' leży poza dozwolonymi lokalizacjami tokenu {{ProgramData}} (tylko Microsoft\Windows\WER)." -f $rootPath))
                }
                elseif ($token -eq 'UserProfile' -and $segments[1] -notin 'Local', 'Roaming', 'LocalLow') {
                    $errors.Add(("Ścieżka '{0}' leży poza AppData\Local, Roaming albo LocalLow." -f $rootPath))
                }
                elseif ($token -eq 'SystemRoot' -and $segments[0] -eq 'SoftwareDistribution' -and ($segments.Count -lt 2 -or $segments[1] -ne 'Download')) {
                    $errors.Add(("Ścieżka '{0}' — z SoftwareDistribution dozwolony jest tylko folder Download." -f $rootPath))
                }
            }
            else {
                $errors.Add(("Ścieżka '{0}' musi zaczynać się od tokenu {{SystemRoot}}, {{ProgramData}}, {{UserProfile}} albo być {{RecycleBin}}." -f $rootPath))
            }
            $patterns = @(@(& $field $root 'patterns') | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
            if ($patterns.Count -eq 0 -or @($patterns | Where-Object { -not $_ -or $_.IndexOfAny([char[]]'\/:') -ge 0 -or $_ -match '\.\.' }).Count -gt 0) {
                $errors.Add(("Niepoprawne wzorce plików w '{0}'." -f $rootPath))
            }
            $exclude = @(@(& $field $root 'exclude') | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
            $minAge = 0
            $age = & $field $root 'minAgeDays'
            if ($null -ne $age) {
                $minAge = [int]$age
                if ($minAge -lt 0 -or $minAge -gt 3650) {
                    $errors.Add(("Niepoprawny minAgeDays w '{0}'." -f $rootPath))
                }
            }
            $roots += [pscustomobject]@{
                PSTypeName             = 'MWP.CleanupRootDefinition'
                Path                   = $rootPath
                Token                  = $token
                Scope                  = $(if ($token -in 'UserProfile', 'RecycleBin') { 'User' } else { 'System' })
                Recurse                = [bool](& $field $root 'recurse')
                Patterns               = $patterns
                Exclude                = $exclude
                MinAgeDays             = $minAge
                RemoveEmptyDirectories = [bool](& $field $root 'removeEmptyDirectories')
            }
        }
        if ($roots.Count -eq 0) {
            $errors.Add('Kategoria nie ma żadnej lokalizacji.')
        }
        $scopes = @($roots | ForEach-Object { $_.Scope } | Sort-Object -Unique)
        $item = [pscustomobject]@{
            PSTypeName  = 'MWP.CleanupCategory'
            Id          = $categoryId
            Name        = [string](& $field $category 'name')
            Description = [string](& $field $category 'description')
            Scope       = $(if ($scopes.Count -gt 1) { 'Mixed' } elseif ($scopes.Count -eq 1) { $scopes[0] } else { 'System' })
            Roots       = $roots
            IsValid     = $errors.Count -eq 0
            Errors      = $errors.ToArray()
        }
        if ($PSBoundParameters.ContainsKey('Id') -and $Id -notcontains $categoryId) {
            continue
        }
        if (-not $item.IsValid -and -not $IncludeInvalid) {
            Write-Warning ("Kategoria czyszczenia '{0}' jest pominięta: {1}" -f $categoryId, ($item.Errors -join ' '))
            continue
        }
        $item
    }
}
