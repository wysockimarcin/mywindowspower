function Read-MwpServiceProfile {
    <#
    .SYNOPSIS
        Wczytuje i sprawdza profil usług z pliku JSON (Export-MwpServiceProfile).

    .DESCRIPTION
        Odczyt pliku lokalnego (bez zmian systemu). Sprawdza rodzaj i wersję profilu oraz każdą
        pozycję: nazwa usługi (Test-MwpServiceName) i typ uruchomienia (Get-MwpServiceStartupTypeList);
        niepoprawne pozycje są pomijane z ostrzeżeniem, powtórzone — też. Zwraca MWP.Result
        z obiektem MWP.ServiceProfile w Data (Services: Name, DisplayName, StartupType, Status).

    .PARAMETER Path
        Plik profilu.

    .EXAMPLE
        (Read-MwpServiceProfile -Path .\uslugi.json).Data.Services | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $operation = 'Services.ReadProfile'
    $common = @{ Operation = $operation; Target = $Path }
    try {
        $fullPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))
        $text = [IO.File]::ReadAllText($fullPath, [Text.Encoding]::UTF8)
        $data = ConvertFrom-Json -InputObject $text -ErrorAction Stop
    }
    catch {
        return New-MwpResult @common -Success $false -Message ("Nie udało się wczytać profilu usług '{0}': {1}" -f $Path, $_.Exception.Message) -ErrorMessage $_.Exception.Message
    }
    $property = { param($Object, [string] $Key) if ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Key]) { $Object.$Key } else { $null } }
    if ((& $property $data 'kind') -ne 'MWP.ServiceProfile') {
        return New-MwpResult @common -Success $false -Message ("Plik '{0}' nie jest profilem usług MyWindowsPower." -f $fullPath)
    }
    $version = & $property $data 'schemaVersion'
    if (($version -as [int]) -ne 1) {
        return New-MwpResult @common -Success $false -Message ("Nieobsługiwana wersja profilu usług: {0} (obsługiwana: 1)." -f $version)
    }
    $types = @(Get-MwpServiceStartupTypeList | ForEach-Object { $_.Id })
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    $seen = @{}
    $services = @(foreach ($item in @(& $property $data 'services')) {
            if ($null -eq $item) {
                continue
            }
            $name = [string](& $property $item 'name')
            $type = [string](& $property $item 'startupType')
            if (-not (Test-MwpServiceName -Name $name)) {
                $warnings.Add(("Pominięto pozycję z niepoprawną nazwą usługi '{0}'." -f $name))
                continue
            }
            if ($types -notcontains $type) {
                $warnings.Add(("Pominięto usługę '{0}': nieznany typ uruchomienia '{1}'." -f $name, $type))
                continue
            }
            if ($seen.ContainsKey($name.ToLowerInvariant())) {
                $warnings.Add(("Pominięto powtórzoną usługę '{0}'." -f $name))
                continue
            }
            $seen[$name.ToLowerInvariant()] = $true
            $displayName = [string](& $property $item 'displayName')
            [pscustomobject]@{
                Name        = $name
                DisplayName = $(if ($displayName) { $displayName } else { $name })
                StartupType = $type
                Status      = [string](& $property $item 'status')
            }
        })
    $result = [pscustomobject]@{
        PSTypeName   = 'MWP.ServiceProfile'
        Path         = $fullPath
        ComputerName = [string](& $property $data 'computerName')
        CreatedAt    = [string](& $property $data 'createdAt')
        Services     = $services
        Warnings     = $warnings.ToArray()
    }
    New-MwpResult @common -Success $true -Message ("Wczytano profil {0} usług z '{1}' (komputer źródłowy: {2})." -f $services.Count, $fullPath, $result.ComputerName) -Data $result
}
