function Resolve-MwpScheduledTaskList {
    <#
    .SYNOPSIS
        Zamienia surowy wynik odczytu zadań harmonogramu (Get-MwpScheduledTask -AsOperation, blok TaskList) na listę MWP.ScheduledTaskList z oznaczeniem listy ochronnej.

    .DESCRIPTION
        Czysta funkcja (bez wywołań na komputerze docelowym): przyjmuje tekst JSON, MWP.Result
        z operacji w tle albo obiekt MWP.ScheduledTaskRaw; gotowa lista jest zwracana bez zmian.
        Lista ochronna (D-046): kategoria Task — zadanie krytyczne, nie wolno go wyłączyć ani
        usunąć (IsProtected); kategoria TaskRemoval — nie wolno usunąć (CanRemove = $false;
        wbudowany wzorzec \Microsoft\*). Wzorce dotyczą pełnej ścieżki zadania (folder + nazwa).
        Gdy listy ochronnej nie da się odczytać, wszystkie zadania są chronione (z ostrzeżeniem).
        Zwraca $null, gdy danych nie ma.

    .PARAMETER ProtectedItem
        Elementy listy ochronnej kategorii Task i TaskRemoval (domyślnie z Get-MwpProtectedItem).

    .EXAMPLE
        Resolve-MwpScheduledTaskList -Data (Wait-MwpOperation -Operation (Get-MwpScheduledTask -AsOperation))
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $ProtectedItem
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.ScheduledTaskList') {
        return $Data
    }
    $raw = ConvertFrom-MwpStartupJson -Data $Data -Kind 'MWP.ScheduledTaskRaw'
    if ($null -eq $raw -or $raw.Error) {
        return $null
    }
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    foreach ($warning in @($raw.Warnings | Where-Object { $_ })) {
        $warnings.Add([string]$warning)
    }
    $protectionKnown = $true
    if (-not $PSBoundParameters.ContainsKey('ProtectedItem') -or $null -eq $ProtectedItem) {
        try {
            $ProtectedItem = @(Get-MwpProtectedItem -Category Task) + @(Get-MwpProtectedItem -Category TaskRemoval)
        }
        catch {
            $protectionKnown = $false
            $ProtectedItem = @()
            $warnings.Add(('Lista ochronna jest nieczytelna — wszystkie zadania są traktowane jako chronione: {0}' -f $_.Exception.Message))
        }
    }
    $critical = @($ProtectedItem | Where-Object { $null -ne $_ -and $_.Category -eq 'Task' })
    $removal = @($ProtectedItem | Where-Object { $null -ne $_ -and $_.Category -eq 'TaskRemoval' })
    $results = @{
        '0'          = 'Sukces'
        '267008'     = 'Gotowe do uruchomienia'
        '267009'     = 'Zadanie jest uruchomione'
        '267011'     = 'Zadanie nie było jeszcze uruchamiane'
        '267012'     = 'Brak kolejnych zaplanowanych uruchomień'
        '267014'     = 'Zakończone przez użytkownika'
        '2147750687' = 'Instancja zadania już działa'
        '2147942402' = 'Nie znaleziono pliku'
        '2147942405' = 'Odmowa dostępu'
    }

    $tasks = @(foreach ($item in @($raw.Tasks | Where-Object { $null -ne $_ })) {
            $path = [string]$item.TaskPath + [string]$item.TaskName
            $state = if ($item.State) { [string]$item.State } else { 'Unknown' }
            $protection = $null
            foreach ($pattern in $critical) {
                if ($path -like $pattern.Name) {
                    $protection = $pattern
                    break
                }
            }
            $removalRule = $null
            foreach ($pattern in $removal) {
                if ($path -like $pattern.Name) {
                    $removalRule = $pattern
                    break
                }
            }
            $isProtected = (-not $protectionKnown) -or $null -ne $protection
            $risk = Get-MwpSignatureRisk -SignatureStatus ([string]$item.SignatureStatus) -SignerSubject ([string]$item.SignerSubject)
            $actions = @(foreach ($action in @($item.Actions | Where-Object { $null -ne $_ })) {
                    if ($action.Kind -eq 'Exec') { ('{0} {1}' -f $action.Execute, $action.Arguments).Trim() } else { '(akcja inna niż uruchomienie programu)' }
                })
            $triggers = @(@($item.Triggers | Where-Object { $_ }) | ForEach-Object { Get-MwpStartupText -Trigger ([string]$_) } | Select-Object -Unique)
            $lastResult = $null
            $lastResultText = ''
            if ($null -ne $item.LastTaskResult) {
                $lastResult = [long]$item.LastTaskResult
                $code = if ($lastResult -lt 0) { $lastResult + 4294967296 } else { $lastResult }
                $lastResultText = if ($results.ContainsKey([string]$code)) { '{0} (0x{1:X})' -f $results[[string]$code], [long]$code } else { '0x{0:X}' -f [long]$code }
            }
            $account = if ($item.UserId) { [string]$item.UserId } elseif ($item.GroupId) { 'grupa ' + [string]$item.GroupId } else { '' }
            [pscustomobject]@{
                PSTypeName        = 'MWP.ScheduledTask'
                Path              = $path
                TaskPath          = [string]$item.TaskPath
                TaskName          = [string]$item.TaskName
                State             = $state
                StateText         = Get-MwpStartupText -TaskState $state
                Enabled           = $state -ne 'Disabled'
                Author            = [string]$item.Author
                Description       = [string]$item.Description
                Account           = $account
                LogonType         = [string]$item.LogonType
                RunLevel          = [string]$item.RunLevel
                HasStoredPassword = [string]$item.LogonType -eq 'Password'
                Actions           = $actions
                ActionText        = $actions -join '; '
                Triggers          = $triggers
                TriggerText       = $triggers -join ', '
                FilePath          = [string]$item.FilePath
                FileExists        = [bool]$item.FileExists
                SignatureStatus   = [string]$item.SignatureStatus
                Publisher         = $risk.Publisher
                Risk              = $risk.Risk
                RiskText          = $risk.RiskText
                LastRunTime       = $(if ($item.LastRunTime) { try { [datetime]$item.LastRunTime } catch { $null } } else { $null })
                NextRunTime       = $(if ($item.NextRunTime) { try { [datetime]$item.NextRunTime } catch { $null } } else { $null })
                LastTaskResult    = $lastResult
                LastResultText    = $lastResultText
                IsMicrosoft       = [string]$item.TaskPath -like '\Microsoft\*'
                IsProtected       = $isProtected
                ProtectionReason  = $(if ($null -ne $protection) { $protection.Reason } elseif (-not $protectionKnown) { 'Lista ochronna jest nieczytelna.' } else { $null })
                CanRemove         = -not $isProtected -and $null -eq $removalRule
                RemovalReason     = $(if ($null -ne $removalRule) { $removalRule.Reason } else { $null })
            }
        })

    [pscustomobject]@{
        PSTypeName      = 'MWP.ScheduledTaskList'
        Kind            = 'MWP.ScheduledTaskList'
        ComputerName    = [string]$raw.ComputerName
        CollectedAt     = [string]$raw.CollectedAt
        IsAdministrator = $raw.IsAdministrator
        Tasks           = @($tasks | Sort-Object -Property Path)
        Warnings        = $warnings.ToArray()
    }
}
