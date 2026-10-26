function Get-MwpNavigationItem {
    <#
    .SYNOPSIS
        Buduje listę pozycji nawigacji hosta z definicji modułów i katalogu obszarów.

    .DESCRIPTION
        Kolejność (D-039): Pulpit (Dashboard, FAZA 5), grupy obszarów z katalogu (Get-MwpAreaCatalog),
        grupa „Moduły z paczek" (moduły zainstalowane spoza katalogu), a na dole: Moduły, Dziennik
        operacji, Ustawienia, O programie. Pozycja obszaru ma pole ModuleId i IsAvailable: moduł
        istnieje i ma poprawny kontrakt — wtedy widok obszaru otwiera instancje; w przeciwnym razie
        widok-zaślepka z numerem fazy. Moduły bazowe (Core, Remote) nie mają pozycji.
        Pola: Kind (Item, Header), Section (Main, Bottom), Key, Title, Glyph, Group, ModuleId,
        IsAvailable, Phase, Description, Definition.

    .PARAMETER Definition
        Definicje modułów (Get-MwpModuleDefinition).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Definition = @()
    )

    $glyph = { param($Code) [string][char][Convert]::ToInt32($Code, 16) }
    $item = {
        param($Section, $Key, $Title, $Code, $Group, $ModuleId, $Available, $Phase, $Description, $ModuleDefinition)
        [pscustomobject]@{
            PSTypeName  = 'MWP.UiNavigationItem'
            Kind        = 'Item'
            Section     = $Section
            Key         = $Key
            Title       = $Title
            Glyph       = $(if ($Code) { & $glyph $Code } else { '' })
            Group       = $Group
            ModuleId    = $ModuleId
            IsAvailable = [bool]$Available
            Phase       = $Phase
            Description = $Description
            Definition  = $ModuleDefinition
        }
    }
    $header = {
        param($Title)
        [pscustomobject]@{
            PSTypeName = 'MWP.UiNavigationItem'; Kind = 'Header'; Section = 'Main'; Key = 'header:' + $Title; Title = $Title
            Glyph = ''; Group = $Title; ModuleId = $null; IsAvailable = $false; Phase = $null; Description = $null; Definition = $null
        }
    }
    $find = {
        param($Id)
        @($Definition | Where-Object { $_.Id -eq $Id -and $_.IsValid -and -not $_.IsBase }) | Select-Object -First 1
    }

    $dashboard = & $find 'Dashboard'
    & $item 'Main' 'dashboard' 'Pulpit' 'E80F' $null 'Dashboard' ($null -ne $dashboard) 5 'Dashboard: widgety modułów dla wielu komputerów (FAZA 5).' $dashboard

    $catalog = @(Get-MwpAreaCatalog)
    $known = @('Dashboard') + @($catalog | ForEach-Object { $_.Id })
    $currentGroup = $null
    foreach ($area in $catalog) {
        if ($area.Group -ne $currentGroup) {
            & $header $area.Group
            $currentGroup = $area.Group
        }
        $found = & $find $area.Id
        & $item 'Main' ('area:' + $area.Id) $area.Title $null $area.Group $area.Id ($null -ne $found) $area.Phase $area.Description $found |
            ForEach-Object { $_.Glyph = $area.Glyph; $_ }
    }

    $extra = @($Definition | Where-Object { $_.IsValid -and -not $_.IsBase -and $known -notcontains $_.Id } | Sort-Object -Property Name)
    if ($extra.Count -gt 0) {
        & $header 'Moduły z paczek'
        foreach ($package in $extra) {
            $description = if ([string]::IsNullOrEmpty($package.Description)) { 'Moduł zainstalowany z paczki.' } else { $package.Description }
            & $item 'Main' ('area:' + $package.Id) $package.Name 'EA86' 'Moduły z paczek' $package.Id $true $null $description $package
        }
    }

    & $item 'Bottom' 'modules' 'Moduły' 'EA86' $null $null $true $null 'Moduły wbudowane i zainstalowane z paczek.' $null
    & $item 'Bottom' 'log' 'Dziennik operacji' 'E9F9' $null $null $true $null 'Panel logu operacji.' $null
    & $item 'Bottom' 'settings' 'Ustawienia' 'E713' $null $null $true $null 'Motyw, komputery docelowe, katalog danych.' $null
    & $item 'Bottom' 'about' 'O programie' 'E946' $null $null $true $null 'Wersje, środowisko, katalog danych.' $null
}
