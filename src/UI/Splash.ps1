<#
    Okno startowe (splash) launchera (korekta D-042; wdrożone, bo mediana czasu do okna > 2000 ms).

    Skrypt jest dołączany kropką (dot-source) przez Start-MyWindowsPower.ps1 przed importem modułów,
    więc nie korzysta z MWP.Core ani MWP.UI (poza dwiema funkcjami motywu z Functions\). Okno działa
    w tym samym wątku STA co launcher, bez drugiego wątku WPF i bez pętli komunikatów: po każdym kroku
    Update-MwpSplash opróżnia kolejkę dyspozytora (Dispatcher.Invoke z priorytetem Background), żeby
    okno się odrysowało. Gdy krok blokuje wątek (np. budowa XAML okna głównego), okno stoi, dlatego
    pasek jest krokowy (wartość = liczba ukończonych kroków), a nie animowany.
    Okno zamyka MWP.UI po pierwszym wyświetleniu okna głównego (ContentRendered, Close-MwpUiSplash)
    albo launcher przy błędzie. Błąd okna startowego nie blokuje startu aplikacji (launcher zapisuje
    ostrzeżenie w logu). Nie jest pokazywane z -NoGui (testy).
#>

. (Join-Path -Path $PSScriptRoot -ChildPath 'Functions\Get-MwpSystemTheme.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'Functions\Resolve-MwpThemeName.ps1')

function Get-MwpSplashTheme {
    <#
    .SYNOPSIS
        Motyw okna startowego (Light albo Dark) z ustawienia theme, odczytanego bez MWP.Core.

    .DESCRIPTION
        Czyta tylko klucz theme z config\settings.local.json, a gdy tego pliku nie ma — z pliku w katalogu
        zapasowym (%LOCALAPPDATA%\MyWindowsPower\settings.local.json, D-032). Brak pliku, uszkodzony
        plik lub brak klucza = System (motyw Windows). Tylko odczyt.

    .PARAMETER AppRoot
        Folder aplikacji.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AppRoot
    )

    $setting = 'System'
    $candidates = @(Join-Path -Path $AppRoot -ChildPath 'config\settings.local.json')
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates += Join-Path -Path $env:LOCALAPPDATA -ChildPath 'MyWindowsPower\settings.local.json'
    }
    foreach ($path in $candidates) {
        if (-not [IO.File]::Exists($path)) {
            continue
        }
        try {
            $settings = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)) -ErrorAction Stop
            if ($null -ne $settings -and $null -ne $settings.PSObject.Properties['theme']) {
                $setting = [string]$settings.theme
            }
        }
        catch {
            Write-Verbose ("Nie odczytano motywu z {0}: {1}" -f $path, $_.Exception.Message)
        }
        break
    }
    Resolve-MwpThemeName -Setting $setting -SystemTheme (Get-MwpSystemTheme)
}

function Show-MwpSplash {
    <#
    .SYNOPSIS
        Pokazuje okno startowe i zwraca obiekt do Update-MwpSplash i Close-MwpSplash.

    .PARAMETER UiRoot
        Folder src\UI (Splash.xaml, Themes\).

    .PARAMETER Theme
        Light albo Dark.

    .PARAMETER Version
        Wersja hosta (MWP.Core) do wyświetlenia.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $UiRoot,

        [ValidateSet('Light', 'Dark')]
        [string] $Theme = 'Light',

        [string] $Version = ''
    )

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $window = [System.Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path -Path $UiRoot -ChildPath 'Splash.xaml'), [Text.Encoding]::UTF8))
    $themePath = Join-Path -Path $UiRoot -ChildPath ('Themes\{0}.xaml' -f $Theme)
    $window.Resources.MergedDictionaries.Add([System.Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText($themePath, [Text.Encoding]::UTF8)))
    $window.FindName('SplashVersion').Text = $(if ($Version -ne '') { 'wersja {0}' -f $Version } else { '' })
    $splash = @{
        Window   = $window
        Progress = $window.FindName('SplashProgress')
        Status   = $window.FindName('SplashStatus')
        Closed   = $false
    }
    $window.Show()
    Update-MwpSplash -Splash $splash -Step 0 -Total 1 -Status 'Uruchamianie…'
    $splash
}

function Update-MwpSplash {
    <#
    .SYNOPSIS
        Ustawia krok paska i linię statusu okna startowego, po czym pozwala oknu się odrysować.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko okno startowe.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Splash,

        [int] $Step = 0,

        [int] $Total = 1,

        [string] $Status = ''
    )

    if ($Splash.Closed) {
        return
    }
    $maximum = [Math]::Max(1, $Total)
    $Splash.Progress.Maximum = $maximum
    $Splash.Progress.Value = [Math]::Min([Math]::Max(0, $Step), $maximum)
    $Splash.Status.Text = $Status
    # Opróżnienie kolejki dyspozytora: układ i odrysowanie mają wyższy priorytet niż Background.
    $Splash.Window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
}

function Close-MwpSplash {
    <#
    .SYNOPSIS
        Zamyka okno startowe (wielokrotne wywołanie jest bezpieczne).
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [hashtable] $Splash
    )

    if ($null -eq $Splash -or $Splash.Closed) {
        return
    }
    $Splash.Closed = $true
    $Splash.Window.Close()
}
