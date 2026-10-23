function Write-MwpLog {
    <#
    .SYNOPSIS
        Zapisuje wpis w dziennym pliku logu aplikacji (JSON Lines) z nazwą komputera docelowego.

    .DESCRIPTION
        Plik: <katalog danych>\logs\mwp-RRRR-MM-DD.log (domyślnie <folder aplikacji>\data\logs,
        ustawienie dataPath, D-032), jeden wpis JSON na linię (UTF-8 bez BOM). Przy tworzeniu pliku nowego dnia starsze pliki są usuwane zgodnie
        z ustawieniem logRetentionDays. Wpisy poniżej poziomu logLevel są pomijane.
        Zapis jest chroniony muteksem, więc wiele runspace'ów i procesów może logować naraz.
        Chwilowa blokada pliku przez inny program (np. synchronizację OneDrive) powoduje kilka
        ponownych prób (łącznie ok. 1,5 s), a nie utratę wpisu. Gdy katalog danych jest
        niezapisywalny, log trafia do katalogu zapasowego, a pierwszy wpis w procesie poprzedza
        ostrzeżenie o tym (operacja DataPath.Fallback).
        Sekrety w -Data są ukrywane. Błąd zapisu logu nie przerywa operacji (tylko ostrzeżenie).

    .PARAMETER ComputerName
        Komputer, którego dotyczy wpis; domyślnie 'localhost' (D-019).

    .EXAMPLE
        Write-MwpLog -Message 'Zmieniono typ uruchomienia usługi' -Level Info -Source 'MWP.Services' -Operation 'Services.SetStartupType' -ComputerName 'localhost' -Data @{ Name = 'Spooler' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Message,

        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string] $Level = 'Info',

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [string] $Source = '',

        [string] $Operation = '',

        [AllowNull()]
        [object] $Data
    )

    $levels = @{ Debug = 0; Info = 1; Warning = 2; Error = 3 }
    try {
        $settings = (Read-MwpSettingsData -NoRepair).Settings
        $minimum = 'Info'
        if ($settings.Contains('logLevel') -and $levels.ContainsKey([string]$settings['logLevel'])) {
            $minimum = [string]$settings['logLevel']
        }
        if ($levels[$Level] -lt $levels[$minimum]) {
            return
        }
        $retentionDays = 30
        if ($settings.Contains('logRetentionDays') -and [int]$settings['logRetentionDays'] -ge 1) {
            $retentionDays = [int]$settings['logRetentionDays']
        }

        $dataPath = Get-MwpDataPath -Kind Logs -Settings $settings -Detailed
        $directory = $dataPath.Path
        $null = [IO.Directory]::CreateDirectory($directory)

        $now = Get-Date
        $path = Join-Path -Path $directory -ChildPath ('mwp-{0:yyyy-MM-dd}.log' -f $now)
        $text = ''
        $fallbackWarning = $null
        if ($dataPath.IsFallback -and -not $script:MwpDataPathWarningLogged.ContainsKey($dataPath.Warning)) {
            $fallbackWarning = $dataPath.Warning
            $warningEntry = [ordered]@{
                timestamp = $now.ToString('o')
                level     = 'Warning'
                computer  = 'localhost'
                source    = 'MWP.Core'
                operation = 'DataPath.Fallback'
                message   = $fallbackWarning
                user      = [Environment]::UserName
                processId = $PID
            }
            $text = (ConvertTo-Json -InputObject $warningEntry -Compress) + [Environment]::NewLine
        }
        $entry = [ordered]@{
            timestamp = $now.ToString('o')
            level     = $Level
            computer  = $ComputerName
            source    = $Source
            operation = $Operation
            message   = $Message
            user      = [Environment]::UserName
            processId = $PID
        }
        if ($PSBoundParameters.ContainsKey('Data')) {
            $entry['data'] = ConvertTo-MwpLogSafeData -InputObject $Data
        }
        $text += (ConvertTo-Json -InputObject $entry -Depth 8 -Compress) + [Environment]::NewLine

        $isNewFile = -not (Test-Path -LiteralPath $path)
        $encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        $mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, 'Local\MyWindowsPower.Log'
        $acquired = $false
        try {
            try {
                $acquired = $mutex.WaitOne(5000)
            }
            catch [System.Threading.AbandonedMutexException] {
                # Poprzedni właściciel zakończył się bez zwolnienia muteksu; muteks jest nasz.
                $acquired = $true
            }
            if (-not $acquired) {
                Write-Warning 'Nie zapisano wpisu w logu: plik logu jest zajęty.'
                return
            }
            $retryDelays = @(50, 100, 200, 400, 800)
            for ($attempt = 0; ; $attempt++) {
                try {
                    [IO.File]::AppendAllText($path, $text, $encoding)
                    break
                }
                catch {
                    $exception = $_.Exception
                    while ($exception -is [Management.Automation.MethodInvocationException] -and $null -ne $exception.InnerException) {
                        $exception = $exception.InnerException
                    }
                    # Ponawiamy tylko blokadę pliku (IOException), nie brak uprawnień ani brak katalogu.
                    $isMissing = $exception -is [IO.DirectoryNotFoundException] -or $exception -is [IO.FileNotFoundException]
                    $isLock = $exception -is [IO.IOException] -and -not $isMissing
                    if (-not $isLock -or $attempt -ge $retryDelays.Count) {
                        throw
                    }
                    Start-Sleep -Milliseconds $retryDelays[$attempt]
                }
            }
        }
        finally {
            if ($acquired) {
                $mutex.ReleaseMutex()
            }
            $mutex.Dispose()
        }

        if ($null -ne $fallbackWarning) {
            $script:MwpDataPathWarningLogged[$fallbackWarning] = $true
            Write-Warning $fallbackWarning
        }
        if ($isNewFile) {
            Invoke-MwpLogRotation -Directory $directory -RetentionDays $retentionDays -Today $now
        }
        Write-Verbose ("[{0}] [{1}] {2}" -f $Level, $ComputerName, $Message)
    }
    catch {
        Write-Warning ("Nie zapisano wpisu w logu: {0}" -f $_.Exception.Message)
    }
}
