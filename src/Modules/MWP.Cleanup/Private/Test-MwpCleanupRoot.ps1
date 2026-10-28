function Test-MwpCleanupRoot {
    <#
    .SYNOPSIS
        Sprawdza na hoście, czy rozwinięta ścieżka katalogu głównego kategorii jest dozwolona do czyszczenia (D-047).

    .DESCRIPTION
        Czysta funkcja (druga linia obrony obok walidacji definicji i kontroli w bloku Process).
        Ścieżka musi być pełna i kanoniczna (bez „..”, symboli wieloznacznych i nadmiarowych
        separatorów), co najmniej dwa poziomy pod katalogiem głównym dysku i leżeć wewnątrz jednej
        z dozwolonych baz: <Windows>\Temp, <Windows>\SoftwareDistribution\Download,
        <Windows>\ServiceProfiles, <Windows>\Logs, <ProgramData>\Microsoft\Windows\WER,
        <profil>\AppData\(Local|Roaming|LocalLow)\… (wewnątrz, nie sam folder) albo
        <dysk lokalny>\$Recycle.Bin\<SID>. Nie może być lokalizacją chronioną użytkownika (pulpit,
        dokumenty, pobrane, obrazy, muzyka, wideo, ulubione, OneDrive) ani leżeć wewnątrz niej.
        Wynik: IsValid i Reason (po polsku).

    .PARAMETER Environment
        MWP.CleanupEnvironment komputera docelowego (Get-MwpCleanupEnvironment).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Path,

        [Parameter(Mandatory)]
        [object] $Environment
    )

    $reject = { param([string] $Reason) [pscustomobject]@{ IsValid = $false; Reason = $Reason } }
    $ignoreCase = [StringComparison]::OrdinalIgnoreCase
    $isUnder = {
        param([string] $Child, [string] $Base, [bool] $AllowEqual)
        $c = $Child.TrimEnd('\')
        $b = $Base.TrimEnd('\')
        ($AllowEqual -and $c.Equals($b, $ignoreCase)) -or $c.StartsWith($b + '\', $ignoreCase)
    }

    $candidate = $Path.TrimEnd('\')
    if ([string]::IsNullOrWhiteSpace($candidate) -or $candidate.IndexOfAny([char[]]'*?"<>|') -ge 0 -or $candidate -match '(^|\\)\.{1,2}(\\|$)' -or $candidate -match '.\\\\') {
        return & $reject ("Niepoprawna ścieżka: '{0}'." -f $Path)
    }
    if ($candidate -notmatch '^[A-Za-z]:\\') {
        return & $reject ("Ścieżka nie jest pełną ścieżką na dysku: '{0}'." -f $Path)
    }
    try {
        $full = [IO.Path]::GetFullPath($candidate).TrimEnd('\')
    }
    catch {
        return & $reject ("Niepoprawna ścieżka: '{0}' ({1})." -f $Path, $_.Exception.Message)
    }
    if (-not $full.Equals($candidate, $ignoreCase)) {
        return & $reject ("Ścieżka nie jest kanoniczna: '{0}'." -f $Path)
    }
    if (@($candidate.Substring(3).Split('\') | Where-Object { $_ }).Count -lt 2) {
        return & $reject ("Ścieżka jest zbyt ogólna (za blisko katalogu głównego dysku): '{0}'." -f $Path)
    }

    $bases = New-Object -TypeName System.Collections.Generic.List[object]
    $systemRoot = [string]$Environment.SystemRoot
    if ($systemRoot) {
        foreach ($name in 'Temp', 'SoftwareDistribution\Download', 'ServiceProfiles', 'Logs') {
            $bases.Add(@((Join-Path -Path $systemRoot -ChildPath $name), $true))
        }
    }
    if ($Environment.ProgramData) {
        $bases.Add(@((Join-Path -Path ([string]$Environment.ProgramData) -ChildPath 'Microsoft\Windows\WER'), $true))
    }
    foreach ($userProfile in @($Environment.Profiles | Where-Object { $null -ne $_ -and $_.Path })) {
        foreach ($name in 'AppData\Local', 'AppData\Roaming', 'AppData\LocalLow') {
            $bases.Add(@((Join-Path -Path ([string]$userProfile.Path) -ChildPath $name), $false))
        }
    }
    foreach ($drive in @($Environment.FixedDrives | Where-Object { $_ })) {
        $bases.Add(@((Join-Path -Path ([string]$drive) -ChildPath '$Recycle.Bin'), $false))
    }
    $allowed = $false
    foreach ($base in $bases) {
        if (& $isUnder $candidate $base[0] $base[1]) {
            $allowed = $true
            break
        }
    }
    if (-not $allowed) {
        return & $reject ("Ścieżka leży poza dozwolonymi lokalizacjami czyszczenia: '{0}'." -f $Path)
    }
    foreach ($protected in @($Environment.Protected | Where-Object { $_ })) {
        if (& $isUnder $candidate ([string]$protected) $true) {
            return & $reject ("Ścieżka jest lokalizacją chronioną użytkownika albo leży w niej: '{0}' ({1})." -f $Path, $protected)
        }
    }
    [pscustomobject]@{ IsValid = $true; Reason = '' }
}
