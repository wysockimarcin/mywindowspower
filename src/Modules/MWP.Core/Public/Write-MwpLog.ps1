function Write-MwpLog {
    <#
    .SYNOPSIS
        Zapisuje wpis w dziennym pliku logu aplikacji (JSON Lines) z nazwą komputera docelowego.

    .DESCRIPTION
        Plik: %LOCALAPPDATA%\MyWindowsPower\logs\mwp-RRRR-MM-DD.log, jeden wpis JSON na linię
        (UTF-8 bez BOM). Przy tworzeniu pliku nowego dnia starsze pliki są usuwane zgodnie
        z ustawieniem logRetentionDays. Wpisy poniżej poziomu logLevel są pomijane.
        Zapis jest chroniony muteksem, więc wiele runspace'ów i procesów może logować naraz.
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

        $directory = Get-MwpDataPath -Kind Logs
        if (-not (Test-Path -LiteralPath $directory)) {
            $null = New-Item -ItemType Directory -Path $directory -Force
        }

        $now = Get-Date
        $path = Join-Path -Path $directory -ChildPath ('mwp-{0:yyyy-MM-dd}.log' -f $now)
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
        $line = (ConvertTo-Json -InputObject $entry -Depth 8 -Compress) + [Environment]::NewLine

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
            [IO.File]::AppendAllText($path, $line, $encoding)
        }
        finally {
            if ($acquired) {
                $mutex.ReleaseMutex()
            }
            $mutex.Dispose()
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
