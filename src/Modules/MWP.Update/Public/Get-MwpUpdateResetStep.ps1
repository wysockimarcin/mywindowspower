function Get-MwpUpdateResetStep {
    <#
    .SYNOPSIS
        Zwraca listę kroków resetu składników Windows Update (albo przywrócenia kopii) — do podglądu przed potwierdzeniem.

    .DESCRIPTION
        Czysta funkcja (bez wywołań na komputerze docelowym). Kroki: zatrzymanie usług (usosvc
        opcjonalnie, wuauserv, bits, cryptsvc), zmiana nazw %SystemRoot%\SoftwareDistribution
        i %SystemRoot%\System32\catroot2 na <nazwa>.<sufiks> (stare foldery zostają — cofnięcie
        przywraca je pod dawną nazwą), ponowne uruchomienie usług, które działały. Przywrócenie
        (-Restore): bieżące foldery dostają sufiks -ReplacedSuffix, a kopie wracają pod dawną nazwę.

    .PARAMETER Suffix
        Sufiks kopii (mwp-RRRRMMDD-GGmmss).

    .PARAMETER Restore
        Kroki przywrócenia kopii zamiast resetu.

    .PARAMETER ReplacedSuffix
        Sufiks dla bieżących folderów przy przywróceniu.

    .EXAMPLE
        Get-MwpUpdateResetStep -Suffix 'mwp-20261028-120000'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^mwp-\d{8}-\d{6}$')]
        [string] $Suffix,

        [switch] $Restore,

        [ValidatePattern('^mwp-replaced-\d{8}-\d{6}$')]
        [string] $ReplacedSuffix = ('mwp-replaced-{0:yyyyMMdd-HHmmss}' -f (Get-Date))
    )

    $config = Get-MwpUpdateTargetConfig
    $index = 0
    $step = {
        param($Kind, $Text)
        [pscustomobject]@{ PSTypeName = 'MWP.UpdateResetStep'; Index = 0; Kind = $Kind; Text = $Text }
    }
    $steps = New-Object -TypeName System.Collections.Generic.List[object]
    $stopNames = foreach ($name in $config.ResetServices) {
        if ($config.OptionalServices -contains $name) { '{0} (opcjonalnie)' -f $name } else { $name }
    }
    $steps.Add((& $step 'Stop' ('Zatrzymanie usług: {0} (limit 60 s na usługę; błąd usługi wymaganej przerywa reset bez zmian w folderach).' -f ($stopNames -join ', '))))
    foreach ($folder in $config.ResetFolders) {
        $path = '%SystemRoot%\{0}' -f $folder.RelativePath
        if ($Restore) {
            $steps.Add((& $step 'Rename' ('{0}: bieżący folder → {1}.{2}, kopia {1}.{3} → {1}.' -f $folder.Name, $path, $ReplacedSuffix, $Suffix)))
        }
        else {
            $steps.Add((& $step 'Rename' ('Zmiana nazwy {0} → {0}.{1} (stary folder zostaje).' -f $path, $Suffix)))
        }
    }
    $steps.Add((& $step 'Start' 'Ponowne uruchomienie usług, które działały przed resetem (Windows Update odtworzy foldery przy następnym wyszukiwaniu).'))
    if (-not $Restore) {
        $steps.Add((& $step 'Undo' ('Cofnięcie: Restore-MwpUpdateComponent -Suffix {0} (wpis w rejestrze cofnięć).' -f $Suffix)))
    }
    foreach ($item in $steps) {
        $index++
        $item.Index = $index
        $item
    }
}
