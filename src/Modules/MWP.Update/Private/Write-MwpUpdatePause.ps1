function Write-MwpUpdatePause {
    <#
    .SYNOPSIS
        Zapisuje (albo usuwa — wartość $null) wartości pauzy Windows Update na komputerze docelowym i sprawdza je ponownym odczytem.

    .DESCRIPTION
        Blok PauseWrite (REG_SZ w kluczu pauzy z Get-MwpUpdateTargetConfig). Wynik: Success, After
        (tabela wartości po zapisie, w postaci tekstowej), Result (MWP.Result błędu, gotowy do
        zwrócenia — bez logu; log zapisuje funkcja publiczna). Niezgodność odczytu z zapisem jest
        błędem.

    .PARAMETER Values
        Nazwa wartości → tekst ISO 8601 w UTC albo $null (usunięcie).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Funkcja wewnętrzna; podgląd i potwierdzenie zapewnia funkcja publiczna (Suspend-, Resume-, Restore-MwpUpdatePause).')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [Parameter(Mandatory)]
        [Collections.IDictionary] $Values
    )

    $config = Get-MwpUpdateTargetConfig
    $ordered = [ordered]@{}
    foreach ($name in $config.PauseValues) {
        if ($Values.Contains($name)) {
            $ordered[$name] = $Values[$name]
        }
    }
    $request = ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{ Key = $config.PauseKey; Values = [pscustomobject]$ordered })
    $common = @{ Operation = $Operation; Target = 'Windows Update'; ComputerName = $Context.ComputerName }
    $change = Invoke-MwpOnTarget -Context $Context -Operation $Operation -ScriptBlock (Get-MwpUpdateScript -Name PauseWrite) -ArgumentList @($request)
    if (-not $change.Success) {
        return [pscustomobject]@{ Success = $false; After = $null; Result = (New-MwpResult @common -Success $false -Message $change.Message -ErrorMessage $change.ErrorMessage) }
    }
    $raw = ConvertFrom-MwpUpdateJson -Data $change -Kind 'MWP.UpdatePauseWrite'
    if ($null -eq $raw) {
        return [pscustomobject]@{ Success = $false; After = $null; Result = (New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił wyniku zapisu pauzy." -f $Context.ComputerName)) }
    }
    $after = @{}
    foreach ($property in @($raw.After.PSObject.Properties)) {
        $after[$property.Name] = ConvertTo-MwpUpdatePauseText -Value $property.Value
    }
    $failure = $null
    if ($raw.Error) {
        $failure = [string]$raw.Error
    }
    else {
        foreach ($name in $ordered.Keys) {
            $wanted = ConvertTo-MwpUpdatePauseText -Value $ordered[$name]
            $actualDate = ConvertFrom-MwpUpdateDate -Value $after[$name]
            $wantedDate = ConvertFrom-MwpUpdateDate -Value $wanted
            $same = if ($null -eq $wanted) { $null -eq $after[$name] } else { $null -ne $actualDate -and $null -ne $wantedDate -and $actualDate -eq $wantedDate }
            if (-not $same) {
                $failure = 'po zapisie wartość {0} to {1} zamiast {2}' -f $name, $(if ($null -ne $after[$name]) { $after[$name] } else { '(brak)' }), $(if ($null -ne $wanted) { $wanted } else { '(brak)' })
                break
            }
        }
    }
    if ($null -ne $failure) {
        return [pscustomobject]@{ Success = $false; After = $after; Result = (New-MwpResult @common -Success $false -Message ("Nie udało się zapisać pauzy Windows Update na komputerze '{0}': {1}" -f $Context.ComputerName, $failure) -ErrorMessage $failure) }
    }
    [pscustomobject]@{ Success = $true; After = $after; Result = $null }
}
