function Start-MwpUi {
    <#
    .SYNOPSIS
        Uruchamia okno główne hosta modułów i czeka na jego zamknięcie; zwraca kod wyjścia.

    .DESCRIPTION
        Kolejność: motyw (ustawienie theme + motyw systemu) → WPF i zasoby → okno główne i jego
        zdarzenia → pula zadań w tle (MWP.Core i MWP.Remote w każdym runspace) → zegar okna
        (DispatcherTimer: obsługa zadań w tle, stan połączeń, panel logu) → ShowDialog. Po zamknięciu
        okna: zatrzymanie zadań, zamknięcie instancji modułów i ich osobnych okien.
        Wymaga zaimportowanych MWP.Core i MWP.Remote (launcher).

    .PARAMETER AppRoot
        Folder aplikacji (katalog z Start-MyWindowsPower.ps1).

    .PARAMETER StartView
        Widok startowy (klucz nawigacji), domyślnie Pulpit.

    .PARAMETER StartupTiming
        Pomiar startu z launchera (Stopwatch, Stages, ProcessStart). Po pierwszym wyświetleniu okna
        (ContentRendered) trafia do wpisu Startup.Window (Write-MwpUiStartupEntry, D-042).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia okno aplikacji; zmiany systemu wykonują funkcje logiki z własnym potwierdzeniem.')]
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AppRoot,

        [ValidateNotNullOrEmpty()]
        [string] $StartView = 'dashboard',

        [AllowNull()]
        [hashtable] $StartupTiming
    )

    $startup = @{ Timing = $StartupTiming; UiStartMs = $null; Rendered = $false }
    if ($null -ne $StartupTiming -and $null -ne $StartupTiming['Stopwatch']) {
        $startup.UiStartMs = $StartupTiming['Stopwatch'].ElapsedMilliseconds
    }

    $uiRoot = Join-Path -Path $AppRoot -ChildPath 'src\UI'
    $themeSetting = 'System'
    try {
        $themeSetting = [string](Get-MwpSetting -Name 'theme')
    }
    catch {
        Write-Warning ("Nie udało się odczytać ustawienia motywu: {0}" -f $_.Exception.Message)
    }
    $theme = Resolve-MwpThemeName -Setting $themeSetting -SystemTheme (Get-MwpSystemTheme)
    $application = Initialize-MwpWpf -UiRoot $uiRoot -Theme $theme

    $modulePaths = @(
        Join-Path -Path $AppRoot -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1'
        Join-Path -Path $AppRoot -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1'
    )
    $main = Import-MwpXaml -Path (Join-Path -Path $uiRoot -ChildPath 'MainWindow.xaml')
    $script:MwpUi = @{
        AppRoot       = $AppRoot
        UiRoot        = $uiRoot
        Application   = $application
        Environment   = Get-MwpEnvironment
        Window        = $main.Root
        Controls      = $main.Controls
        Theme         = $theme
        ThemeSetting  = $themeSetting
        Tasks         = New-Object -TypeName System.Collections.Generic.List[object]
        Pool          = $null
        Definitions   = @(Get-MwpModuleDefinition)
        Views         = @{}
        Instances     = @{}
        CurrentKey    = $null
        Navigating    = $false
        LogVisible    = $false
        LastLogRead   = [datetime]::MinValue
        Ticks         = 0
        Timer         = $null
        DemoTask      = $null
        Closing       = $false
        Startup       = $startup
    }

    $exitCode = 0
    try {
        $script:MwpUi.Pool = New-MwpUiTaskPool -ModulePath $modulePaths
        Initialize-MwpMainWindow
        Set-MwpUiTheme -Theme $theme
        Show-MwpView -Key $StartView
        $script:MwpUi.Window.Add_ContentRendered({ Invoke-MwpUiSafe -Name 'Startup.Window' -Action { Close-MwpUiSplash; Write-MwpUiStartupEntry } })
        Write-MwpLog -Level Info -Source 'MWP.UI' -Operation 'UI.Start' -Message ("Uruchomiono okno aplikacji (motyw {0})." -f $theme)
        $null = $script:MwpUi.Window.ShowDialog()
    }
    catch {
        $exitCode = 1
        $message = "Błąd okna aplikacji: {0}" -f $_.Exception.Message
        # Błąd przed pierwszym wyświetleniem okna to błąd startu (Startup.Window, D-042).
        $operation = if ($startup.Rendered) { 'UI.Start' } else { 'Startup.Window' }
        Write-MwpLog -Level Error -Source 'MWP.UI' -Operation $operation -Message $message -Data @{ Position = $_.InvocationInfo.PositionMessage }
        Write-Error -Message $message -ErrorAction Continue
    }
    finally {
        Close-MwpUiSplash
        Close-MwpUiSession
    }
    $exitCode
}
