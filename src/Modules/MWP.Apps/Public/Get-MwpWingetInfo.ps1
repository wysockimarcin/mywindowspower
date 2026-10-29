function Get-MwpWingetInfo {
    <#
    .SYNOPSIS
        Sprawdza, czy winget jest dostępny na komputerze docelowym dla konta sesji (wersja i ścieżka).

    .DESCRIPTION
        Operacja klasy Odczyt (D-050): winget --version. Szukany jest alias użytkownika
        (%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe), a bez niego plik z pakietu
        Microsoft.DesktopAppInstaller zarejestrowanego dla konta. Wynik: MWP.Result z Data
        (MWP.WingetInfo: Available, Version, Path); brak winget — Success = $true, Available = $false.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Apps.WingetInfo'
    $common = @{ Operation = $operation; Target = 'winget'; ComputerName = $Context.ComputerName }
    $call = Invoke-MwpWinget -Context $Context -Argument @('--version') -Operation $operation -TimeoutSeconds 60
    if ($null -ne $call.Result) {
        return New-MwpResult @common -Success $false -Message $call.Message -ErrorMessage $call.ErrorMessage
    }
    $version = @($call.Lines | Where-Object { $_ -match '^\s*v?\d+(\.\d+)+' }) | Select-Object -First 1
    $info = [pscustomobject]@{
        PSTypeName = 'MWP.WingetInfo'
        Available  = [bool]($call.Success -and $version)
        Version    = $(if ($version) { ([string]$version).Trim().TrimStart('v') } else { '' })
        Path       = [string]$call.WingetPath
        Message    = $(if ($call.Success) { '' } else { [string]$call.Message })
    }
    $message = if ($info.Available) { "winget {0} jest dostępny na komputerze '{1}'." -f $info.Version, $Context.ComputerName } else { $call.Message }
    New-MwpResult @common -Success $true -Message $message -Data $info
}
