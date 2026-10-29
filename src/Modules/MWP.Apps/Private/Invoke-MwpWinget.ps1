function Invoke-MwpWinget {
    <#
    .SYNOPSIS
        Uruchamia winget na komputerze docelowym w wybranym kontekście (bezpośrednio, zadanie SYSTEM, zadanie użytkownika) i zwraca surowy wynik z opisem błędu.

    .DESCRIPTION
        Argumenty jako tablica (każdy osobno, D-015); zawsze z --disable-interactivity. Sposób
        uruchomienia (D-051, Get-MwpWingetRunPlan): localhost — bezpośrednio na koncie aplikacji
        (blok Winget, bez zmian względem D-050), profil innego użytkownika — zadanie w jego sesji;
        komputer zdalny — zadanie harmonogramu jako SYSTEM, a dla wskazanych profili — zadanie w sesji
        zalogowanego użytkownika (blok WingetTask). Reszta modułu nie zależy od sposobu uruchomienia.
        Wynik: Success (winget znaleziony, zakończony w limicie, kod 0 albo kod z -AllowedExitCode),
        Found, ExitCode, Lines, Message (po polsku), Result (MWP.Result błędu połączenia), RunAs
        (Direct, System, User), UserSid, UserName, Reason, Raw (surowy wynik: MWP.WingetRaw albo
        MWP.WingetRawSet) i Calls (wynik każdego przebiegu). Wynik opisuje pierwszy przebieg.
        Z -AsOperation zwraca uchwyt Start-MwpOperation (wynik czyta Resolve-MwpWingetPackage).

    .PARAMETER UserSid
        Profile użytkowników (SID), w których sesjach uruchomić winget (dodatkowo albo z -UserOnly zamiast
        uruchomienia podstawowego).

    .PARAMETER UserOnly
        Tylko w profilach z -UserSid (bez uruchomienia podstawowego — bezpośredniego albo SYSTEM).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [string[]] $Argument,

        [Parameter(Mandatory)]
        [string] $Operation,

        [int] $TimeoutSeconds = 0,

        [long[]] $AllowedExitCode = @(),

        [ValidatePattern('^S-1-5-21-[0-9-]+$')]
        [string[]] $UserSid = @(),

        [switch] $UserOnly,

        [switch] $AsOperation
    )

    $config = Get-MwpAppsTargetConfig
    if ($TimeoutSeconds -le 0) {
        $TimeoutSeconds = $config.ReadTimeoutSeconds
    }
    $arguments = @($Argument)
    if ($arguments -notcontains '--disable-interactivity') {
        $arguments += '--disable-interactivity'
    }
    $runs = @(Get-MwpWingetRunPlan -Context $Context -UserSid $UserSid -UserOnly:$UserOnly)
    $direct = $runs.Count -eq 1 -and $runs[0].Mode -eq 'Direct'
    $winget = Get-MwpAppsScript -Name Winget
    if ($direct) {
        $block = $winget
        $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
                Arguments      = $arguments
                WingetPath     = [string]$config.WingetPath
                TimeoutSeconds = $TimeoutSeconds
            })
        $limit = $TimeoutSeconds + 60
    }
    else {
        $block = Get-MwpAppsScript -Name WingetTask
        $request = ConvertTo-Json -Compress -Depth 4 -InputObject ([pscustomobject]@{
                Runs              = @($runs)
                Arguments         = $arguments
                WingetPath        = [string]$config.WingetPath
                TimeoutSeconds    = $TimeoutSeconds
                RunScript         = (ConvertTo-MwpAppsPackedText -Text $winget.ToString())
                TaskScript        = (Get-MwpWingetTaskScript)
                TaskPath          = [string]$config.TaskPath
                TaskPrefix        = [string]$config.TaskPrefix
                ResultRoot        = [string]$config.ResultRoot
                ProtectResultRoot = [bool]$config.ProtectResultRoot
                OrphanMinutes     = [int]$config.OrphanMinutes
                PollMilliseconds  = [int]$config.PollMilliseconds
                StartGraceSeconds = [int]$config.StartGraceSeconds
                MaxCommandLength  = [int]$config.MaxCommandLength
                CheckAdministrator = [bool]$config.CheckAdministrator
            })
        $limit = $TimeoutSeconds + [int]$config.StartGraceSeconds + 120
    }
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation -TimeoutSeconds $limit
    }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $Operation -TimeoutSeconds $limit
    if (-not $result.Success) {
        return [pscustomobject]@{
            Success = $false; Found = $false; ExitCode = $null; Lines = @(); Message = $result.Message; ErrorMessage = $result.ErrorMessage; Result = $result
            WingetPath = ''; DurationMs = 0; RunAs = $runs[0].Mode; UserSid = [string]$runs[0].UserSid; UserName = ''; Reason = ''; Raw = $null; Calls = @()
        }
    }
    $raw = ConvertFrom-MwpAppsJson -Data $result -Kind 'MWP.WingetRaw', 'MWP.WingetRawSet'
    $items = if ($null -ne $raw -and $raw.Kind -eq 'MWP.WingetRawSet') { @($raw.Runs) } elseif ($null -ne $raw) { @($raw) } else { @($null) }
    $calls = @(foreach ($item in $items) {
            ConvertTo-MwpWingetCall -Data $item -AllowedExitCode $AllowedExitCode -ComputerName $Context.ComputerName
        })
    $first = $calls[0]
    $first | Add-Member -NotePropertyName Raw -NotePropertyValue $raw -Force
    $first | Add-Member -NotePropertyName Calls -NotePropertyValue $calls -Force
    if ($direct) {
        $first.RunAs = 'Direct'
    }
    $first
}
