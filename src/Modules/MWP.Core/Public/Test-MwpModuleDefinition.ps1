function Test-MwpModuleDefinition {
    <#
    .SYNOPSIS
        Waliduje definicję modułu: pola kontraktu, wersję hosta i zależności.

    .DESCRIPTION
        Zwraca obiekt z polami IsValid i Errors (czytelne komunikaty po polsku). Sprawdza:
        obecność i typy pól kontraktu, dozwolone wartości (słownik kontraktu), EntryPoint
        wśród eksportowanych funkcji, MinimumHostVersion względem wersji hosta, unikalność Id,
        obecność i wersje zależności oraz cykle zależności.

    .PARAMETER Definition
        Definicja z Get-MwpModuleDefinition.

    .PARAMETER AvailableDefinition
        Wszystkie odkryte definicje (do sprawdzenia zależności i unikalności Id).

    .PARAMETER HostVersion
        Wersja hosta; domyślnie wersja MWP.Core.

    .EXAMPLE
        $all = Get-MwpModuleDefinition; Test-MwpModuleDefinition -Definition $all[0] -AvailableDefinition $all
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ModuleDefinition')]
        [object] $Definition,

        [object[]] $AvailableDefinition = @(),

        [version] $HostVersion
    )

    if (-not $PSBoundParameters.ContainsKey('HostVersion')) {
        $HostVersion = $MyInvocation.MyCommand.Module.Version
    }

    $vocabulary = Get-MwpContractVocabulary
    $errors = New-Object -TypeName System.Collections.Generic.List[string]
    $contract = $Definition.Contract
    $parseVersion = {
        param($Text)
        $parsed = $null
        if ([version]::TryParse([string]$Text, [ref]$parsed)) {
            $parsed
        }
    }

    if ($null -ne $Definition.LoadError) {
        $errors.Add(("Nie udało się odczytać manifestu: {0}" -f $Definition.LoadError))
    }
    elseif ($null -eq $contract) {
        $errors.Add('Manifest nie zawiera kontraktu modułu (sekcja PrivateData.MWP).')
    }
    else {
        foreach ($field in $vocabulary.RequiredFields) {
            if (-not $contract.Contains($field)) {
                $errors.Add(("Brak pola '{0}' w kontrakcie modułu." -f $field))
            }
        }

        if ($contract.Contains('ContractVersion') -and $vocabulary.ContractVersions -notcontains $contract['ContractVersion']) {
            $errors.Add(("Nieobsługiwana wersja kontraktu {0} (obsługiwane: {1})." -f $contract['ContractVersion'], ($vocabulary.ContractVersions -join ', ')))
        }

        if ($Definition.Id -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
            $errors.Add(("Niepoprawne Id '{0}' (dozwolone litery i cyfry, zaczyna się od litery)." -f $Definition.Id))
        }
        elseif (@($AvailableDefinition | Where-Object { $_.Id -eq $Definition.Id -and $_.ManifestPath -ne $Definition.ManifestPath }).Count -gt 0) {
            $errors.Add(("Id '{0}' jest używane także przez inny moduł." -f $Definition.Id))
        }
        if (@($AvailableDefinition | Where-Object { $_.ModuleName -eq $Definition.ModuleName -and $_.ManifestPath -ne $Definition.ManifestPath }).Count -gt 0) {
            $errors.Add(("Folder modułu '{0}' występuje w kilku katalogach modułów." -f $Definition.ModuleName))
        }

        if ([string]::IsNullOrWhiteSpace($Definition.Name)) {
            $errors.Add('Pole Name nie może być puste.')
        }
        if ($null -eq $Definition.Version) {
            $errors.Add('Manifest nie zawiera poprawnej wersji modułu (ModuleVersion).')
        }
        if ($contract.Contains('EntryPoint') -and $Definition.ExportedFunctions -notcontains $Definition.EntryPoint) {
            $errors.Add(("EntryPoint '{0}' nie jest eksportowaną funkcją modułu." -f $Definition.EntryPoint))
        }

        if ($contract.Contains('MinimumHostVersion')) {
            $minimumHost = & $parseVersion $Definition.MinimumHostVersion
            if ($null -eq $minimumHost) {
                $errors.Add(("Niepoprawna wartość MinimumHostVersion '{0}'." -f $Definition.MinimumHostVersion))
            }
            elseif ($null -ne $HostVersion -and $HostVersion -lt $minimumHost) {
                $errors.Add(("Moduł wymaga hosta w wersji co najmniej {0}, dostępna wersja: {1}." -f $minimumHost, $HostVersion))
            }
        }

        $lists = @(
            @{ Field = 'Capabilities'; Values = $Definition.Capabilities; Allowed = $vocabulary.Capabilities }
            @{ Field = 'SupportedPresentationModes'; Values = $Definition.SupportedPresentationModes; Allowed = $vocabulary.PresentationModes }
            @{ Field = 'RequiredPermissions'; Values = $Definition.RequiredPermissions; Allowed = $vocabulary.Permissions }
        )
        foreach ($list in $lists) {
            foreach ($value in @($list.Values)) {
                if ($list.Allowed -notcontains $value) {
                    $errors.Add(("Niedozwolona wartość '{0}' w polu {1} (dozwolone: {2})." -f $value, $list.Field, ($list.Allowed -join ', ')))
                }
            }
        }
        if ($contract.Contains('RequiredPermissions') -and @($Definition.RequiredPermissions).Count -eq 0) {
            $errors.Add('Pole RequiredPermissions musi zawierać co najmniej jedną wartość.')
        }

        if ($contract.Contains('ConfigurationSchema')) {
            $schema = $Definition.ConfigurationSchema
            if ($schema -isnot [Collections.IDictionary]) {
                $errors.Add('Pole ConfigurationSchema musi być tabelą (@{}).')
            }
            else {
                foreach ($key in $schema.Keys) {
                    $setting = $schema[$key]
                    if ($setting -isnot [Collections.IDictionary] -or -not $setting.Contains('Type') -or -not $setting.Contains('Default')) {
                        $errors.Add(("Ustawienie '{0}' w ConfigurationSchema musi mieć pola Type i Default." -f $key))
                    }
                    elseif ($vocabulary.ConfigurationTypes -notcontains $setting['Type']) {
                        $errors.Add(("Niedozwolony typ '{0}' ustawienia '{1}' (dozwolone: {2})." -f $setting['Type'], $key, ($vocabulary.ConfigurationTypes -join ', ')))
                    }
                }
            }
        }

        # Widgety Dashboardu (opcjonalne pole, D-043).
        if ($contract.Contains('Widgets')) {
            $widgetIds = @{}
            $widgets = @($Definition.Widgets)
            if ($widgets.Count -gt 0 -and @($Definition.SupportedPresentationModes) -notcontains 'DashboardWidget') {
                $errors.Add('Moduł z polem Widgets musi deklarować tryb DashboardWidget w SupportedPresentationModes.')
            }
            foreach ($widget in $widgets) {
                if ($widget -isnot [Collections.IDictionary]) {
                    $errors.Add('Każdy element pola Widgets musi być tabelą (@{}).')
                    continue
                }
                $widgetId = [string]$widget['Id']
                if ($widgetId -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
                    $errors.Add(("Niepoprawne Id widgetu '{0}' (dozwolone litery i cyfry, zaczyna się od litery)." -f $widgetId))
                }
                elseif ($widgetIds.ContainsKey($widgetId)) {
                    $errors.Add(("Id widgetu '{0}' występuje kilka razy." -f $widgetId))
                }
                $widgetIds[$widgetId] = $true
                if ([string]::IsNullOrWhiteSpace([string]$widget['Name'])) {
                    $errors.Add(("Widget '{0}' nie ma nazwy (Name)." -f $widgetId))
                }
                foreach ($field in @('DataCommand', 'ViewCommand', 'ExportCommand')) {
                    $command = [string]$widget[$field]
                    if ([string]::IsNullOrWhiteSpace($command)) {
                        if ($field -ne 'ExportCommand') {
                            $errors.Add(("Widget '{0}' nie ma pola {1}." -f $widgetId, $field))
                        }
                    }
                    elseif ($Definition.ExportedFunctions -notcontains $command) {
                        $errors.Add(("{0} '{1}' widgetu '{2}' nie jest eksportowaną funkcją modułu." -f $field, $command, $widgetId))
                    }
                }
                if ($widget.Contains('DefaultRefreshSeconds') -and $vocabulary.WidgetRefreshSeconds -notcontains $widget['DefaultRefreshSeconds']) {
                    $errors.Add(("Niedozwolone DefaultRefreshSeconds {0} widgetu '{1}' (dozwolone: {2})." -f $widget['DefaultRefreshSeconds'], $widgetId, ($vocabulary.WidgetRefreshSeconds -join ', ')))
                }
                # Konfiguracja widgetów modułu (D-053): pola opcjonalne, wartości logiczne.
                foreach ($field in @('Enabled', 'LocalOnly')) {
                    if ($widget.Contains($field) -and $widget[$field] -isnot [bool]) {
                        $errors.Add(("Pole {0} widgetu '{1}' musi być wartością logiczną (`$true albo `$false)." -f $field, $widgetId))
                    }
                }
                if ($widget.Contains('Parameters')) {
                    $parameters = $widget['Parameters']
                    if ($parameters -isnot [Collections.IDictionary]) {
                        $errors.Add(("Pole Parameters widgetu '{0}' musi być tabelą (@{{}})." -f $widgetId))
                        continue
                    }
                    foreach ($key in $parameters.Keys) {
                        $parameter = $parameters[$key]
                        if ($parameter -isnot [Collections.IDictionary] -or -not $parameter.Contains('Type') -or -not $parameter.Contains('Default')) {
                            $errors.Add(("Parametr '{0}' widgetu '{1}' musi mieć pola Type i Default." -f $key, $widgetId))
                        }
                        elseif ($vocabulary.ConfigurationTypes -notcontains $parameter['Type']) {
                            $errors.Add(("Niedozwolony typ '{0}' parametru '{1}' widgetu '{2}'." -f $parameter['Type'], $key, $widgetId))
                        }
                        elseif ($parameter.Contains('Values') -and @($parameter['Default'] | Where-Object { @($parameter['Values']) -notcontains $_ }).Count -gt 0) {
                            $errors.Add(("Wartość domyślna parametru '{0}' widgetu '{1}' spoza listy Values." -f $key, $widgetId))
                        }
                        elseif ($parameter.Contains('Values') -and $parameter.Contains('PreviousDefault') -and @($parameter['PreviousDefault'] | Where-Object { @($parameter['Values']) -notcontains $_ }).Count -gt 0) {
                            $errors.Add(("Wartość PreviousDefault parametru '{0}' widgetu '{1}' spoza listy Values." -f $key, $widgetId))
                        }
                    }
                }
            }
        }

        foreach ($dependency in $Definition.Dependencies) {
            if ([string]::IsNullOrWhiteSpace($dependency.Id)) {
                $errors.Add('Zależność bez pola Id.')
                continue
            }
            if ($dependency.Id -eq $Definition.Id) {
                $errors.Add('Moduł nie może zależeć od samego siebie.')
                continue
            }
            $provider = @($AvailableDefinition | Where-Object { $_.Id -eq $dependency.Id }) | Select-Object -First 1
            if ($null -eq $provider) {
                $errors.Add(("Brakująca zależność: nie znaleziono modułu '{0}'." -f $dependency.Id))
                continue
            }
            $required = & $parseVersion $dependency.MinimumVersion
            if ($null -eq $required) {
                $errors.Add(("Zależność '{0}' ma niepoprawne MinimumVersion '{1}'." -f $dependency.Id, $dependency.MinimumVersion))
            }
            elseif ($null -eq $provider.Version -or $provider.Version -lt $required) {
                $errors.Add(("Zależność '{0}' wymaga wersji co najmniej {1}, dostępna wersja: {2}." -f $dependency.Id, $required, $provider.Version))
            }
        }

        # Wykrywanie cykli: przeszukanie zależności w głąb od bieżącego modułu.
        $stack = New-Object -TypeName System.Collections.Generic.Stack[object]
        $stack.Push(@($Definition.Id))
        $visited = @{}
        $cycle = $null
        while ($stack.Count -gt 0 -and $null -eq $cycle) {
            $path = $stack.Pop()
            $currentId = $path[-1]
            $current = @($AvailableDefinition | Where-Object { $_.Id -eq $currentId }) | Select-Object -First 1
            if ($null -eq $current -and $currentId -eq $Definition.Id) {
                $current = $Definition
            }
            if ($null -eq $current) {
                continue
            }
            foreach ($dependency in $current.Dependencies) {
                if ($dependency.Id -eq $Definition.Id -and $path.Count -gt 1) {
                    $cycle = @($path) + $Definition.Id
                    break
                }
                if ($dependency.Id -ne $Definition.Id -and -not $visited.ContainsKey($dependency.Id)) {
                    $visited[$dependency.Id] = $true
                    $stack.Push(@($path) + $dependency.Id)
                }
            }
        }
        if ($null -ne $cycle) {
            $errors.Add(("Cykliczna zależność: {0}." -f ($cycle -join ' -> ')))
        }
    }

    [pscustomobject]@{
        PSTypeName = 'MWP.ModuleValidation'
        ModuleName = $Definition.ModuleName
        IsValid    = $errors.Count -eq 0
        Errors     = $errors.ToArray()
    }
}
