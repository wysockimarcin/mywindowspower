function Resolve-MwpPowerStatus {
    <#
    .SYNOPSIS
        Zamienia wynik odczytu zasilania (surowe dane powercfg z komputera docelowego albo gotowy stan) na obiekt MWP.PowerStatus.

    .DESCRIPTION
        Operacja klasy Odczyt, bez wywołań systemowych — tylko parsowanie na hoście. Get-MwpPowerStatus
        bez -AsOperation zwraca już stan; operacja w tle (widok, widget) zwraca w Data surowy
        tekst JSON (MWP.PowerRaw), który ta funkcja parsuje po GUID-ach (niezależnie od języka
        systemu, ConvertFrom-MwpPowercfgOutput). Przyjmuje MWP.Result, tekst JSON albo obiekt.
        Zwraca $null, gdy danych nie ma.

        Pola stanu: Kind ('MWP.PowerStatus'), ComputerName, CollectedAt, Plans (Guid, Name, IsActive,
        IsBuiltIn), ActivePlan, Settings (Id, Label, Kind, Available, Ac, Dc, AcText, DcText, MaxIndex),
        Hibernate, FastStartup, HasBattery, IsAdministrator ($null = brak danych), Warnings.

    .EXAMPLE
        Resolve-MwpPowerStatus -Data (Wait-MwpOperation -Operation (Get-MwpPowerStatus -Context $c -AsOperation))
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object] $Data
    )

    $item = ConvertFrom-MwpPowerJson -Data $Data -Kind 'MWP.PowerRaw', 'MWP.PowerStatus'
    if ($null -eq $item) {
        return $null
    }
    if ($item.Kind -eq 'MWP.PowerStatus') {
        return $item
    }

    $catalog = Get-MwpPowerCatalog
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    $list = Get-MwpPowercfgCommand -Raw $item -Id 'list'
    $plans = @()
    if ($list.Found) {
        if (-not $list.Success) {
            $warnings.Add('Lista planów: ' + $list.Message)
        }
        $plans = @(ConvertFrom-MwpPowercfgOutput -Line $list.Output -As List | ForEach-Object {
                [pscustomobject]@{
                    PSTypeName = 'MWP.PowerPlan'
                    Guid       = $_.Guid
                    Name       = $(if ($_.Name) { $_.Name } else { $_.Guid })
                    IsActive   = $_.IsActive
                    IsBuiltIn  = $catalog.BuiltInPlans.Contains($_.Guid)
                }
            })
    }

    $settings = @(foreach ($definition in $catalog.Settings) {
            $command = Get-MwpPowercfgCommand -Raw $item -Id ('q:' + $definition.Id)
            if (-not $command.Found) {
                continue
            }
            $value = ConvertFrom-MwpPowercfgOutput -Line $command.Output -As Query
            [pscustomobject]@{
                PSTypeName = 'MWP.PowerSetting'
                Id         = $definition.Id
                Label      = $definition.Label
                Kind       = $definition.Kind
                MaxIndex   = $definition.MaxIndex
                Available  = $value.Available
                Ac         = $value.Ac
                Dc         = $value.Dc
                AcText     = $(if ($value.Available) { Format-MwpPowerValue -Value $value.Ac -Kind $definition.Kind } else { 'niedostępne' })
                DcText     = $(if ($value.Available) { Format-MwpPowerValue -Value $value.Dc -Kind $definition.Kind } else { 'niedostępne' })
            }
        })

    $system = $null
    if ($null -ne $item.PSObject.Properties['System']) {
        $system = $item.System
    }
    $read = {
        param([string] $Name)
        if ($null -ne $system -and $null -ne $system.PSObject.Properties[$Name]) { $system.$Name }
    }
    foreach ($warning in @(& $read 'Warnings')) {
        if ($warning) {
            $warnings.Add([string]$warning)
        }
    }

    [pscustomobject]@{
        PSTypeName      = 'MWP.PowerStatus'
        Kind            = 'MWP.PowerStatus'
        ComputerName    = [string]$item.ComputerName
        CollectedAt     = [string]$item.CollectedAt
        Plans           = $plans
        ActivePlan      = @($plans | Where-Object { $_.IsActive }) | Select-Object -First 1
        Settings        = $settings
        Hibernate       = & $read 'Hibernate'
        FastStartup     = & $read 'FastStartup'
        HasBattery      = & $read 'HasBattery'
        IsAdministrator = & $read 'IsAdministrator'
        Warnings        = $warnings.ToArray()
    }
}
