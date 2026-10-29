function Get-MwpAppsTargetConfig {
    <#
    .SYNOPSIS
        Zwraca stałe modułu MWP.Apps: źródło winget, limity czasu, wzorce środowisk uruchomieniowych i ścieżkę winget (testy).

    .DESCRIPTION
        Jedno miejsce stałych (jak Get-MwpNetworkTargetConfig); w testach podmieniane mockiem
        (WingetPath = atrapa winget w TestDrive). WingetPath pusty = wykrycie na komputerze docelowym
        (alias użytkownika, potem plik z pakietu Microsoft.DesktopAppInstaller). Źródło pakietów jest
        stałe: 'winget' (bez msstore, D-050).
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
    }
}
