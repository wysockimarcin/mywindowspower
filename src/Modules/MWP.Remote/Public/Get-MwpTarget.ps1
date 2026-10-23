function Get-MwpTarget {
    <#
    .SYNOPSIS
        Zwraca komputery docelowe z rejestru: zawsze localhost oraz komputery zdalne z ustawień lokalnych.

    .DESCRIPTION
        Rejestr komputerów jest w config\settings.local.json (klucz targets, poza repozytorium; D-019).
        localhost jest zawsze pierwszy i działa bez zdalnego wywołania. Pomijane są (z ostrzeżeniem):
        wpis przykładowy z szablonu (isExample), nazwy oznaczające komputer lokalny, niepoprawne nazwy,
        nieobsługiwany transport lub sposób uwierzytelnienia i duplikaty.

    .PARAMETER Name
        Filtr po nazwie komputera (symbole wieloznaczne dozwolone).

    .EXAMPLE
        Get-MwpTarget | Format-Table Name, DisplayName, IsLocal, Port, Authentication
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name = '*'
    )

    $targets = New-Object -TypeName System.Collections.Generic.List[object]
    $targets.Add((ConvertTo-MwpTarget -Local))

    $entries = @()
    try {
        $entries = @(Get-MwpSetting -Name 'targets')
    }
    catch {
        Write-Warning ("Nie udało się odczytać rejestru komputerów: {0}" -f $_.Exception.Message)
    }

    foreach ($entry in $entries) {
        if ($entry -isnot [Collections.IDictionary]) {
            continue
        }
        if ($entry.Contains('isExample') -and [bool]$entry['isExample']) {
            continue
        }
        $entryName = [string]$entry['name']
        if (-not (Test-MwpTargetName -Name $entryName)) {
            Write-Warning ("Pominięto komputer o niepoprawnej nazwie '{0}' w rejestrze komputerów." -f $entryName)
            continue
        }
        if (Test-MwpLocalTargetName -Name $entryName) {
            Write-Warning ("Pominięto wpis '{0}': komputer lokalny jest zawsze dostępny jako localhost." -f $entryName)
            continue
        }
        $target = ConvertTo-MwpTarget -Entry $entry
        if ($target.Transport -ne 'WinRM' -or $target.Authentication -notin @('Credential', 'CurrentUser')) {
            Write-Warning ("Pominięto komputer '{0}': obsługiwany jest transport WinRM i uwierzytelnienie Credential albo CurrentUser." -f $entryName)
            continue
        }
        if (@($targets | Where-Object { $_.Name -eq $entryName }).Count -gt 0) {
            Write-Warning ("Pominięto powtórzony wpis komputera '{0}'." -f $entryName)
            continue
        }
        $targets.Add($target)
    }

    $targets | Where-Object { $_.Name -like $Name }
}
