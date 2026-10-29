function Get-MwpAppProtection {
    <#
    .SYNOPSIS
        Ustala, czy aplikację można odinstalować z aplikacji (lista ochronna, składniki systemu) i czy wymaga ostrzeżenia.

    .DESCRIPTION
        Reguły (D-050), egzekwowane w Uninstall-MwpApp — GUI tylko je pokazuje:
        - Appx: podpis System, pakiet struktury (framework), pakiet zasobów, oznaczenie NonRemovable,
          kategoria AppxPackage listy ochronnej (nazwa pakietu);
        - rejestr: SystemComponent = 1, NoRemove = 1, aktualizacje (ParentKeyName, ReleaseType),
          kategoria App (nazwa wyświetlana);
        - winget: kategoria App (identyfikator źródła albo lokalny).
        Środowiska uruchomieniowe (VC++ Redistributable, .NET) nie są chronione — dostają ostrzeżenie.
        Wynik: IsProtected, Reason, Warning. Bez wywołań bloków skryptu w pętli (setki aplikacji w 5.1).

    .PARAMETER App
        Aplikacja MWP.App (Resolve-MwpInstalledApp; Source Registry, Appx albo Winget z pełnym zestawem pól).

    .PARAMETER ProtectedItem
        Wpisy listy ochronnej kategorii App i AppxPackage wczytane raz dla wielu aplikacji (bez parametru
        funkcja czyta listę sama).

    .PARAMETER RuntimePattern
        Wzorce nazw środowisk uruchomieniowych (bez parametru — z Get-MwpAppsTargetConfig).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $App,

        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $ProtectedItem,

        [AllowEmptyCollection()]
        [string[]] $RuntimePattern
    )

    if (-not $PSBoundParameters.ContainsKey('ProtectedItem')) {
        $ProtectedItem = @(Get-MwpProtectedItem | Where-Object { 'App', 'AppxPackage' -contains $_.Category })
    }
    if (-not $PSBoundParameters.ContainsKey('RuntimePattern')) {
        $RuntimePattern = @((Get-MwpAppsTargetConfig).RuntimePatterns)
    }
    $reason = $null
    if ($App.Source -eq 'Appx') {
        if ($App.SignatureKind -eq 'System') {
            $reason = 'Składnik systemu Windows (pakiet z podpisem System).'
        }
        elseif ($App.IsFramework) {
            $reason = 'Pakiet struktury (framework) używany przez inne aplikacje.'
        }
        elseif ($App.IsResourcePackage) {
            $reason = 'Pakiet zasobów (języka lub skalowania) innej aplikacji.'
        }
        elseif ($App.NonRemovable) {
            $reason = 'Windows oznacza ten pakiet jako nieusuwalny.'
        }
        else {
            foreach ($item in $ProtectedItem) {
                if ($null -ne $item -and $item.Category -eq 'AppxPackage' -and [string]$App.PackageName -like $item.Name) {
                    $reason = [string]$item.Reason
                    break
                }
            }
        }
    }
    elseif ($App.Source -eq 'Registry') {
        if ($App.SystemComponent) {
            $reason = 'Składnik systemowy (SystemComponent) — nie jest pokazywany w Ustawieniach.'
        }
        elseif ($App.IsUpdate) {
            $reason = 'Aktualizacja innego programu (usuwa się ją razem z programem).'
        }
        elseif ($App.NoRemove) {
            $reason = 'Program nie pozwala na odinstalowanie (NoRemove).'
        }
    }
    $names = @([string]$App.Name, [string]$App.WingetId, [string]$App.WingetLocalId)
    if (-not $reason) {
        foreach ($item in $ProtectedItem) {
            if ($null -eq $item -or $item.Category -ne 'App') {
                continue
            }
            foreach ($name in $names) {
                if ($name -and $name -like $item.Name) {
                    $reason = [string]$item.Reason
                    break
                }
            }
            if ($reason) {
                break
            }
        }
    }
    $warning = $null
    foreach ($pattern in $RuntimePattern) {
        if (($names[0] -and $names[0] -like $pattern) -or ($names[1] -and $names[1] -like $pattern)) {
            $warning = 'Środowisko uruchomieniowe — inne programy mogą z niego korzystać i przestać działać po jego usunięciu.'
            break
        }
    }
    [pscustomobject]@{
        IsProtected = [bool]$reason
        Reason      = $reason
        Warning     = $warning
    }
}
