function ConvertTo-MwpSystemInfoView {
    <#
    .SYNOPSIS
        Zamienia informacje o systemie na widok widgetu (MWP.WidgetView): sekcje z wierszami etykieta–wartość.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043): czysta, bez WPF i bez dostępu do systemu. Host
        renderuje wynik ogólnym szablonem kafelka. Wiersz: Label, Value, Percent (0–100 albo -1,
        gdy bez paska) i Tone (Neutral, Success, Warning, Danger — kolor paska). Zajętość dysku
        od 90% i pamięci od 90% ma ton Danger, od 80% — Warning. Braki danych są opisane w wierszu
        („brak danych”, „brak baterii”), a ostrzeżenia odczytu — w polu Warnings.
        Tej samej funkcji używa raport tekstowy (ConvertTo-MwpSystemReport).

    .PARAMETER Data
        Dane z Get-MwpSystemInfo (obiekt, tekst JSON albo MWP.Result).

    .PARAMETER WidgetParameters
        Parametry widgetu; klucz Sections ogranicza pokazywane sekcje.

    .EXAMPLE
        ConvertTo-MwpSystemInfoView -Data (Get-MwpSystemInfo -Context (New-MwpExecutionContext))
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    $info = Resolve-MwpSystemInfoData -Data $Data
    if ($null -eq $info) {
        return $null
    }
    $get = {
        param($Object, [string] $Name)
        if ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]) {
            $Object.$Name
        }
    }
    $list = {
        param($Object, [string] $Name)
        @(& $get $Object $Name) | Where-Object { $null -ne $_ }
    }
    $text = {
        param($Value)
        if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { 'brak danych' } else { [string]$Value }
    }
    $tone = {
        param($Percent, [double] $Warning = 80, [double] $Danger = 90)
        if ($null -eq $Percent) { 'Neutral' } elseif ([double]$Percent -ge $Danger) { 'Danger' } elseif ([double]$Percent -ge $Warning) { 'Warning' } else { 'Success' }
    }
    $row = {
        param([string] $Label, $Value, $Percent = $null, [string] $Tone = 'Neutral')
        [pscustomobject]@{
            Label   = $Label
            Value   = & $text $Value
            Percent = $(if ($null -ne $Percent) { [double]$Percent } else { -1 })
            Tone    = $Tone
        }
    }

    $all = @('System', 'Cpu', 'Memory', 'Gpu', 'Disks', 'Board', 'Battery', 'Network')
    $shown = $all
    if ($null -ne $WidgetParameters -and $WidgetParameters.Contains('Sections') -and @($WidgetParameters['Sections']).Count -gt 0) {
        $shown = @($all | Where-Object { @($WidgetParameters['Sections']) -contains $_ })
    }
    $collected = @(& $list $info 'Sections')
    $sections = New-Object -TypeName System.Collections.Generic.List[object]
    $add = {
        param([string] $Title, [object[]] $Items)
        $sections.Add([pscustomobject]@{ Title = $Title; Items = @($Items) })
    }

    foreach ($name in $shown) {
        if ($collected.Count -gt 0 -and $collected -notcontains $name) {
            continue
        }
        $section = & $get $info $name
        switch ($name) {
            'System' {
                $build = & $get $section 'BuildNumber'
                $ubr = & $get $section 'Ubr'
                & $add 'System' @(
                    & $row 'Wersja' (& $get $section 'Caption')
                    & $row 'Wydanie' (& $get $section 'DisplayVersion')
                    & $row 'Kompilacja' $(if ($build) { if ($null -ne $ubr) { '{0}.{1}' -f $build, $ubr } else { $build } })
                    & $row 'Data instalacji' (& $get $section 'InstallDate')
                    & $row 'Czas pracy' $(if ($null -ne (& $get $section 'UptimeSeconds')) { Format-MwpDuration -Seconds (& $get $section 'UptimeSeconds') })
                    & $row 'Komputer' (@((& $get $section 'Manufacturer'), (& $get $section 'Model')) -join ' ').Trim()
                )
            }
            'Cpu' {
                $load = & $get $section 'LoadPercent'
                $items = @(& $row 'Obciążenie' $(if ($null -ne $load) { '{0}%' -f $load }) $load (& $tone $load))
                foreach ($processor in @(& $list $section 'Processors')) {
                    $items += & $row 'Procesor' (& $get $processor 'Name')
                    $items += & $row 'Rdzenie / wątki' ('{0} / {1}' -f (& $text (& $get $processor 'Cores')), (& $text (& $get $processor 'LogicalProcessors')))
                }
                & $add 'Procesor' $items
            }
            'Memory' {
                $used = & $get $section 'UsedPercent'
                $usage = $null
                if ($null -ne (& $get $section 'TotalBytes')) {
                    $usage = '{0} z {1} ({2}%)' -f (Format-MwpByteSize (& $get $section 'UsedBytes')), (Format-MwpByteSize (& $get $section 'TotalBytes')), $used
                }
                $items = @(& $row 'Użycie' $usage $used (& $tone $used))
                if ($null -ne (& $get $section 'InstalledBytes')) {
                    $items += & $row 'Zainstalowana' ('{0} ({1} moduł/y{2})' -f (Format-MwpByteSize (& $get $section 'InstalledBytes')), (& $get $section 'ModuleCount'),
                        $(if (& $get $section 'SpeedMHz') { ', {0} MHz' -f (& $get $section 'SpeedMHz') } else { '' }))
                }
                & $add 'Pamięć RAM' $items
            }
            'Gpu' {
                $items = @(foreach ($gpu in @(& $list $info 'Gpu')) {
                        & $row 'Karta' ('{0}{1}' -f (& $text (& $get $gpu 'Name')), $(if (& $get $gpu 'Resolution') { ' · {0}' -f (& $get $gpu 'Resolution') } else { '' }))
                    })
                if ($items.Count -eq 0) {
                    $items = @(& $row 'Karta' $null)
                }
                & $add 'Grafika' $items
            }
            'Disks' {
                $items = @(foreach ($volume in @(& $list $section 'Volumes')) {
                        $percent = & $get $volume 'UsedPercent'
                        $label = 'Dysk {0}{1}' -f (& $get $volume 'Drive'), $(if (& $get $volume 'Label') { ' ({0})' -f (& $get $volume 'Label') } else { '' })
                        $media = if (& $get $volume 'MediaType') { ' · {0}' -f (& $get $volume 'MediaType') } else { '' }
                        $value = 'wolne {0} z {1}{2}' -f (Format-MwpByteSize (& $get $volume 'FreeBytes')), (Format-MwpByteSize (& $get $volume 'SizeBytes')), $media
                        & $row $label $value $percent (& $tone $percent)
                    })
                if ($items.Count -eq 0) {
                    $items = @(& $row 'Woluminy' $null)
                }
                & $add 'Dyski' $items
            }
            'Board' {
                & $add 'Płyta główna i BIOS' @(
                    & $row 'Płyta główna' (@((& $get $section 'Manufacturer'), (& $get $section 'Product')) -join ' ').Trim()
                    & $row 'BIOS' (@((& $get $section 'BiosVendor'), (& $get $section 'BiosVersion'), (& $get $section 'BiosReleaseDate')) -join ' ').Trim()
                )
            }
            'Battery' {
                $batteries = @(& $list $section 'Batteries')
                if ($null -ne $section -and -not (& $get $section 'Present')) {
                    & $add 'Bateria' @(& $row 'Bateria' 'brak baterii')
                }
                elseif ($batteries.Count -eq 0) {
                    & $add 'Bateria' @(& $row 'Bateria' $null)
                }
                else {
                    & $add 'Bateria' @(foreach ($battery in $batteries) {
                            $charge = & $get $battery 'ChargePercent'
                            $value = '{0}{1}' -f $(if ($null -ne $charge) { '{0}%' -f $charge } else { 'brak danych' }), $(if (& $get $battery 'Status') { ' · {0}' -f (& $get $battery 'Status') } else { '' })
                            $batteryTone = if ($null -eq $charge) { 'Neutral' } elseif ([double]$charge -le 10) { 'Danger' } elseif ([double]$charge -le 20) { 'Warning' } else { 'Success' }
                            & $row (& $text (& $get $battery 'Name')) $value $charge $batteryTone
                        })
                }
            }
            'Network' {
                $items = @(foreach ($adapter in @(& $list $info 'Network')) {
                        $addresses = @(@(& $list $adapter 'IPv4') + @(& $list $adapter 'IPv6') | Where-Object { $_ })
                        $gateways = @(& $list $adapter 'Gateway')
                        $address = if ($addresses.Count -gt 0) { $addresses[0] } else { 'bez adresu' }
                        $gateway = if ($gateways.Count -gt 0) { ' · brama {0}' -f $gateways[0] } else { '' }
                        $dhcp = if (& $get $adapter 'Dhcp') { ' · DHCP' } else { '' }
                        $value = '{0}{1}{2}' -f $address, $gateway, $dhcp
                        & $row (& $text (& $get $adapter 'Name')) $value
                    })
                if ($items.Count -eq 0) {
                    $items = @(& $row 'Karty sieciowe' 'brak aktywnych kart z adresem IP')
                }
                & $add 'Sieć' $items
            }
        }
    }

    $system = & $get $info 'System'
    $summary = '{0}{1}' -f (& $get $info 'ComputerName'), $(if (& $get $system 'Caption') { ' · {0}' -f (& $get $system 'Caption') } else { '' })
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = $summary
        CollectedAt = & $get $info 'CollectedAt'
        Sections    = $sections.ToArray()
        Warnings    = @(& $list $info 'Warnings')
    }
}
