function Get-MwpPowerScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu wykonywany na komputerze docelowym (Invoke-MwpOnTarget / Start-MwpOperation).

    .DESCRIPTION
        Bloki są samowystarczalne i zgodne z Windows PowerShell 5.1 (D-036): dane przychodzą przez
        parametry, wynik wraca jako tekst JSON (serializacja WinRM spłaszcza głębsze obiekty).
        Bloki nie interpretują tekstu powercfg — zwracają surowe linie i kod wyjścia, a parsowanie
        (po GUID, niezależnie od języka systemu) odbywa się na hoście. Argumenty powercfg są
        przekazywane jako osobne elementy tablicy (bez sklejania polecenia z tekstu, D-015).
        - Powercfg: wykonuje listę poleceń { Id; Arguments }, opcjonalnie zatrzymuje się na pierwszym
          błędzie, opcjonalnie dołącza stan systemu (hibernacja i szybkie uruchamianie z rejestru,
          bateria z CIM, administrator).
        - FastStartup: zapis HiberbootEnabled (DWORD) w HKLM.
        - ExportPlan / ImportPlan: plik .pow w katalogu tymczasowym komputera docelowego, treść
          w Base64 (kopia planu przed usunięciem i jej przywrócenie).
        - Report: powercfg /batteryreport albo /energy do katalogu tymczasowego komputera
          docelowego; treść HTML wraca w Base64, katalog jest usuwany.

    .PARAMETER Name
        Nazwa bloku.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Powercfg', 'FastStartup', 'ExportPlan', 'ImportPlan', 'Report')]
        [string] $Name
    )

    switch ($Name) {
        'Powercfg' {
            {
                param([string] $RequestJson)
                $ErrorActionPreference = 'Continue'
                $request = ConvertFrom-Json -InputObject $RequestJson
                $commands = @()
                foreach ($command in @($request.Commands)) {
                    $arguments = @(@($command.Arguments) | ForEach-Object { [string]$_ })
                    $lines = @(& powercfg.exe @arguments 2>&1 | ForEach-Object { [string]$_ })
                    $code = [int]$LASTEXITCODE
                    $commands += [pscustomobject]@{ Id = [string]$command.Id; ExitCode = $code; Output = $lines }
                    if ($request.StopOnError -and $code -ne 0) {
                        break
                    }
                }
                $system = $null
                if ($request.IncludeSystem) {
                    $warnings = @()
                    $hibernate = $null
                    $fastStartup = $null
                    $hasBattery = $null
                    try {
                        $item = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -ErrorAction Stop
                        foreach ($valueName in 'HibernateEnabled', 'HibernateEnabledDefault') {
                            if ($null -ne $item.PSObject.Properties[$valueName]) {
                                $hibernate = [int]$item.$valueName -ne 0
                                break
                            }
                        }
                    }
                    catch {
                        $warnings += 'Hibernacja: ' + $_.Exception.Message
                    }
                    try {
                        $item = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -ErrorAction Stop
                        if ($null -ne $item.PSObject.Properties['HiberbootEnabled']) {
                            $fastStartup = [int]$item.HiberbootEnabled -ne 0
                        }
                    }
                    catch {
                        $warnings += 'Szybkie uruchamianie: ' + $_.Exception.Message
                    }
                    try {
                        $hasBattery = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop).Count -gt 0
                    }
                    catch {
                        $warnings += 'Bateria: ' + $_.Exception.Message
                    }
                    $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                    $system = [pscustomobject]@{
                        Hibernate       = $hibernate
                        FastStartup     = $fastStartup
                        HasBattery      = $hasBattery
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        Warnings        = $warnings
                    }
                }
                ConvertTo-Json -Depth 6 -Compress -InputObject ([pscustomobject]@{
                        Kind         = 'MWP.PowerRaw'
                        ComputerName = $env:COMPUTERNAME
                        CollectedAt  = (Get-Date).ToString('o')
                        Commands     = $commands
                        System       = $system
                    })
            }
        }
        'FastStartup' {
            {
                param([int] $Value)
                $null = New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value $Value -PropertyType DWord -Force -ErrorAction Stop
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Kind = 'MWP.PowerChange'; Value = $Value })
            }
        }
        'ExportPlan' {
            {
                param([string] $Guid)
                $ErrorActionPreference = 'Continue'
                $path = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ('mwp-plan-{0}.pow' -f [guid]::NewGuid())
                $lines = @(& powercfg.exe '/export' $path $Guid 2>&1 | ForEach-Object { [string]$_ })
                $code = [int]$LASTEXITCODE
                $content = $null
                if ([IO.File]::Exists($path)) {
                    if ($code -eq 0) {
                        $content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
                    }
                    [IO.File]::Delete($path)
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Kind = 'MWP.PowerFile'; ExitCode = $code; Output = $lines; Content = $content })
            }
        }
        'ImportPlan' {
            {
                param([string] $Guid, [string] $Content)
                $ErrorActionPreference = 'Continue'
                $path = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ('mwp-plan-{0}.pow' -f [guid]::NewGuid())
                [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($Content))
                try {
                    $lines = @(& powercfg.exe '/import' $path $Guid 2>&1 | ForEach-Object { [string]$_ })
                    $code = [int]$LASTEXITCODE
                }
                finally {
                    [IO.File]::Delete($path)
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Kind = 'MWP.PowerFile'; ExitCode = $code; Output = $lines; Content = $null })
            }
        }
        'Report' {
            {
                param([string] $ReportKind, [int] $DurationSeconds)
                $ErrorActionPreference = 'Continue'
                $folder = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ('mwp-report-{0}' -f [guid]::NewGuid())
                $null = [IO.Directory]::CreateDirectory($folder)
                $content = $null
                try {
                    if ($ReportKind -eq 'Battery') {
                        $file = Join-Path -Path $folder -ChildPath 'battery-report.html'
                        $arguments = @('/batteryreport', '/output', $file)
                    }
                    else {
                        $file = Join-Path -Path $folder -ChildPath 'energy-report.html'
                        $arguments = @('/energy', '/output', $file, '/duration', [string]$DurationSeconds)
                    }
                    $lines = @(& powercfg.exe @arguments 2>&1 | ForEach-Object { [string]$_ })
                    $code = [int]$LASTEXITCODE
                    if ([IO.File]::Exists($file)) {
                        $content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
                    }
                }
                finally {
                    [IO.Directory]::Delete($folder, $true)
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind         = 'MWP.PowerReportRaw'
                        ReportKind   = $ReportKind
                        ComputerName = $env:COMPUTERNAME
                        CreatedAt    = (Get-Date).ToString('o')
                        ExitCode     = $code
                        Output       = $lines
                        Content      = $content
                    })
            }
        }
    }
}
