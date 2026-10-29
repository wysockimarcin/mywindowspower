function Get-MwpAppsTargetConfig {
    <#
    .SYNOPSIS
        Zwraca stałe modułu MWP.Apps: źródło winget, limity czasu, wzorce środowisk uruchomieniowych, ścieżkę winget (testy) i ustawienia zadań winget (D-051).

    .DESCRIPTION
        Jedno miejsce stałych (jak Get-MwpNetworkTargetConfig); w testach podmieniane mockiem
        (WingetPath = atrapa winget w TestDrive, ResultRoot w TestDrive, bez ACL). WingetPath pusty =
        wykrycie na komputerze docelowym (alias użytkownika, potem plik z pakietu
        Microsoft.DesktopAppInstaller; dla zadania SYSTEM — pakiet z Get-AppxPackage -AllUsers).
        Źródło pakietów jest stałe: 'winget' (bez msstore, D-050).
        Zadania winget (D-051): folder i prefiks zadań harmonogramu, katalog wyników (pusty =
        %ProgramData%\MyWindowsPower\winget na komputerze docelowym), ACL katalogu (tylko SYSTEM
        i Administratorzy), wiek osieroconych zadań i plików, odstęp odpytywania, czas na start
        zadania i limit długości polecenia zadania. CheckAdministrator = sprawdzenie administratora w bloku
        WingetTask (zawsze w działaniu; testy wyłączają je, bo proces testów zwykle nie ma uprawnień).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    [pscustomobject]@{
        Source                = 'winget'
        WingetPath            = ''
        ReadTimeoutSeconds    = 300
        ChangeTimeoutSeconds  = 1800
        SearchCount           = 50
        RuntimePatterns       = @(
            'Microsoft Visual C++*Redistributable*'
            'Microsoft .NET*Runtime*'
            'Microsoft .NET*Hosting*'
            'Microsoft Windows Desktop Runtime*'
            'Microsoft ASP.NET Core*'
            'Microsoft.VCRedist.*'
            'Microsoft.DotNet.*'
        )
        TaskPath              = '\MyWindowsPower\'
        TaskPrefix            = 'MWP-Winget-'
        ResultRoot            = ''
        ProtectResultRoot     = $true
        OrphanMinutes         = 40
        PollMilliseconds      = 500
        StartGraceSeconds     = 60
        MaxCommandLength      = 16000
        CheckAdministrator    = $true
    }
}
