function Initialize-MwpWpf {
    <#
    .SYNOPSIS
        Ładuje biblioteki WPF i przygotowuje obiekt aplikacji WPF z zasobami motywu i stylów.

    .DESCRIPTION
        PowerShell 5.1 (.NET Framework) i 7.x (.NET, Microsoft.WindowsDesktop.App) ładują te same
        biblioteki: PresentationFramework, PresentationCore, WindowsBase (różnica wersji obsługiwana
        przez Add-Type -AssemblyName). Wymagany wątek STA (sprawdza launcher). W procesie może istnieć
        tylko jeden obiekt System.Windows.Application, więc ponowne uruchomienie GUI w tej samej sesji
        używa istniejącego. Zasoby: [0] motyw (Themes\Light.xaml albo Dark.xaml), [1] Themes\Styles.xaml
        — wspólne dla okna głównego, osobnych okien instancji i okien dialogowych.

    .PARAMETER UiRoot
        Folder src\UI.

    .PARAMETER Theme
        Light albo Dark.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $UiRoot,

        [ValidateSet('Light', 'Dark')]
        [string] $Theme = 'Light'
    )

    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
        throw 'Okno WPF wymaga wątku STA (uruchom aplikację przez Start-MyWindowsPower.ps1).'
    }
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    $applicationType = 'System.Windows.Application' -as [type]
    $application = $applicationType::Current
    if ($null -eq $application) {
        $application = New-Object -TypeName System.Windows.Application
    }
    # Okno główne zamyka aplikację jawnie (Start-MwpUi), a nie zamknięcie ostatniego okna.
    $application.ShutdownMode = 'OnExplicitShutdown'

    $dictionaries = $application.Resources.MergedDictionaries
    $dictionaries.Clear()
    $dictionaries.Add((Import-MwpXaml -Path (Join-Path -Path $UiRoot -ChildPath ('Themes\{0}.xaml' -f $Theme))).Root)
    $dictionaries.Add((Import-MwpXaml -Path (Join-Path -Path $UiRoot -ChildPath 'Themes\Styles.xaml')).Root)
    $application
}
