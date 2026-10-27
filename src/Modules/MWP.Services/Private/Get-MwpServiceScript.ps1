function Get-MwpServiceScript {
    <#
    .SYNOPSIS
        Zwraca blok skryptu wykonywany na komputerze docelowym (Invoke-MwpOnTarget / Start-MwpOperation).

    .DESCRIPTION
        Bloki są samowystarczalne i zgodne z Windows PowerShell 5.1 (D-036): dane przychodzą przez
        parametry, wynik wraca jako tekst JSON (serializacja WinRM spłaszcza głębsze obiekty).
        Nazwy usług są walidowane na hoście przed wysłaniem (bez symboli wieloznacznych), a bloki
        nie sklejają poleceń z tekstu (D-015).
        - List: Win32_Service (stan, typ uruchomienia z opóźnionym startem, konto, ścieżka, opis),
          opcjonalnie graf zależności (Win32_DependentService) i uprawnienia administratora.
        - Control: kolejne kroki Start/Stop przez ServiceController z limitem czasu na usługę;
          po pierwszym błędzie uruchamia ponownie usługi z listy Recover (zatrzymane w tej operacji)
          i zwraca stan końcowy wszystkich usług operacji.
        - StartupType: sc.exe config <nazwa> start= <tryb> (argumenty jako tablica; jedyny sposób
          ustawienia opóźnionego startu w 5.1), potem ponowny odczyt typu z Win32_Service.

    .PARAMETER Name
        Nazwa bloku.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('List', 'Control', 'StartupType')]
        [string] $Name
    )

    switch ($Name) {
        'List' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $names = @(@($request.Names) | Where-Object { $_ } | ForEach-Object { [string]$_ })
                $warnings = @()
                $services = @()
                $dependencies = @()
                $errorText = $null
                try {
                    $all = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)
                    foreach ($item in $all) {
                        if ($names.Count -gt 0 -and $names -notcontains [string]$item.Name) {
                            continue
                        }
                        $delayed = $false
                        if ([string]$item.StartMode -eq 'Auto') {
                            if ($null -ne $item.PSObject.Properties['DelayedAutoStart'] -and $null -ne $item.DelayedAutoStart) {
                                $delayed = [bool]$item.DelayedAutoStart
                            }
                            else {
                                try {
                                    $key = Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $item.Name) -ErrorAction Stop
                                    if ($null -ne $key.PSObject.Properties['DelayedAutostart']) {
                                        $delayed = [int]$key.DelayedAutostart -ne 0
                                    }
                                }
                                catch {
                                    $warnings += ('{0}: nie odczytano opóźnionego startu ({1})' -f $item.Name, $_.Exception.Message)
                                }
                            }
                        }
                        $services += [pscustomobject]@{
                            Name        = [string]$item.Name
                            DisplayName = [string]$item.DisplayName
                            State       = [string]$item.State
                            StartMode   = [string]$item.StartMode
                            Delayed     = $delayed
                            StartName   = [string]$item.StartName
                            PathName    = [string]$item.PathName
                            Description = [string]$item.Description
                            ProcessId   = [int]$item.ProcessId
                            AcceptStop  = [bool]$item.AcceptStop
                            ServiceType = [string]$item.ServiceType
                        }
                    }
                    if ($request.IncludeGraph) {
                        $known = @{}
                        foreach ($item in $all) {
                            $known[[string]$item.Name] = $true
                        }
                        try {
                            foreach ($link in @(Get-CimInstance -ClassName Win32_DependentService -ErrorAction Stop)) {
                                $service = [string]$link.Dependent.Name
                                $dependsOn = [string]$link.Antecedent.Name
                                if ($known.ContainsKey($service) -and $known.ContainsKey($dependsOn)) {
                                    $dependencies += [pscustomobject]@{ Service = $service; DependsOn = $dependsOn }
                                }
                            }
                        }
                        catch {
                            $warnings += ('Zależności usług: ' + $_.Exception.Message)
                        }
                    }
                }
                catch {
                    $errorText = $_.Exception.Message
                }
                $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
                ConvertTo-Json -Depth 5 -Compress -InputObject ([pscustomobject]@{
                        Kind            = 'MWP.ServiceRaw'
                        ComputerName    = $env:COMPUTERNAME
                        CollectedAt     = (Get-Date).ToString('o')
                        IsAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                        HasGraph        = [bool]$request.IncludeGraph
                        Services        = $services
                        Dependencies    = $dependencies
                        Warnings        = $warnings
                        Error           = $errorText
                    })
            }
        }
        'Control' {
            {
                param([string] $RequestJson)
                $request = ConvertFrom-Json -InputObject $RequestJson
                $timeout = [TimeSpan]::FromSeconds([int]$request.TimeoutSeconds)
                $done = @()
                $failure = $null
                foreach ($step in @($request.Steps)) {
                    $stepName = [string]$step.Name
                    $action = [string]$step.Action
                    try {
                        $controller = Get-Service -Name $stepName -ErrorAction Stop
                        if ($action -eq 'Stop') {
                            if ([string]$controller.Status -ne 'Stopped') {
                                $controller.Stop()
                            }
                            $controller.WaitForStatus('Stopped', $timeout)
                        }
                        else {
                            if ([string]$controller.Status -ne 'Running') {
                                $controller.Start()
                            }
                            $controller.WaitForStatus('Running', $timeout)
                        }
                        $done += [pscustomobject]@{ Name = $stepName; Action = $action }
                    }
                    catch {
                        $text = $_.Exception.Message
                        if ($null -ne $_.Exception.InnerException) {
                            $text = '{0} {1}' -f $text, $_.Exception.InnerException.Message
                        }
                        $failure = [pscustomobject]@{ Name = $stepName; Action = $action; Message = $text }
                        break
                    }
                }
                $recovered = @()
                if ($null -ne $failure) {
                    foreach ($recoverName in @(@($request.Recover) | Where-Object { $_ })) {
                        try {
                            $controller = Get-Service -Name ([string]$recoverName) -ErrorAction Stop
                            if ([string]$controller.Status -eq 'Stopped') {
                                $controller.Start()
                                $controller.WaitForStatus('Running', $timeout)
                                $recovered += [string]$recoverName
                            }
                        }
                        catch {
                            $failure.Message = '{0} Nie udało się ponownie uruchomić {1}: {2}' -f $failure.Message, $recoverName, $_.Exception.Message
                        }
                    }
                }
                $final = @()
                foreach ($finalName in @(@($request.Steps) | ForEach-Object { [string]$_.Name } | Select-Object -Unique)) {
                    $status = 'Unknown'
                    try {
                        $status = [string](Get-Service -Name $finalName -ErrorAction Stop).Status
                    }
                    catch {
                        $status = 'Unknown'
                    }
                    $final += [pscustomobject]@{ Name = $finalName; Status = $status }
                }
                ConvertTo-Json -Depth 4 -Compress -InputObject ([pscustomobject]@{
                        Kind      = 'MWP.ServiceControl'
                        Done      = $done
                        Failure   = $failure
                        Recovered = $recovered
                        Final     = $final
                    })
            }
        }
        'StartupType' {
            {
                param([string] $ServiceName, [string] $Mode)
                $ErrorActionPreference = 'Continue'
                $arguments = @('config', $ServiceName, 'start=', $Mode)
                $lines = @(& sc.exe @arguments 2>&1 | ForEach-Object { [string]$_ })
                $code = [int]$LASTEXITCODE
                $startMode = $null
                $delayed = $null
                try {
                    $item = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | Where-Object { [string]$_.Name -eq $ServiceName }) | Select-Object -First 1
                    if ($null -ne $item) {
                        $startMode = [string]$item.StartMode
                        $delayed = $false
                        if ($null -ne $item.PSObject.Properties['DelayedAutoStart'] -and $null -ne $item.DelayedAutoStart) {
                            $delayed = [bool]$item.DelayedAutoStart
                        }
                        elseif ($startMode -eq 'Auto') {
                            $key = Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $ServiceName) -ErrorAction Stop
                            if ($null -ne $key.PSObject.Properties['DelayedAutostart']) {
                                $delayed = [int]$key.DelayedAutostart -ne 0
                            }
                        }
                    }
                }
                catch {
                    $lines += $_.Exception.Message
                }
                ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                        Kind      = 'MWP.ServiceStartupChange'
                        ExitCode  = $code
                        Output    = $lines
                        StartMode = $startMode
                        Delayed   = $delayed
                    })
            }
        }
    }
}
