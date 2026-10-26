function Import-MwpXaml {
    <#
    .SYNOPSIS
        Wczytuje plik XAML (okno, widok, słownik zasobów) i mapuje kontrolki nazwane przez x:Name.

    .DESCRIPTION
        Plik jest czytany jawnie jako UTF-8 i parsowany przez System.Windows.Markup.XamlReader.
        Pliki XAML projektu nie mają x:Class ani zdarzeń (zdarzenia podpina kod MWP.UI). Zwraca obiekt
        z polami Root (element główny) i Controls (tabela: nazwa -> kontrolka, FindName w zakresie
        nazw elementu głównego). Brak kontrolki o nazwie z pliku jest błędem pliku.

    .PARAMETER Path
        Ścieżka pliku .xaml.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    $reader = 'System.Windows.Markup.XamlReader' -as [type]
    try {
        $root = $reader::Parse($text)
    }
    catch {
        $exception = $_.Exception
        while ($null -ne $exception.InnerException) {
            $exception = $exception.InnerException
        }
        throw ("Nie udało się wczytać pliku XAML '{0}': {1}" -f [IO.Path]::GetFileName($Path), $exception.Message)
    }

    $controls = @{}
    foreach ($match in [regex]::Matches($text, 'x:Name="([A-Za-z_][A-Za-z0-9_]*)"')) {
        $name = $match.Groups[1].Value
        if ($controls.ContainsKey($name)) {
            continue
        }
        $control = $null
        if ($root -is [System.Windows.FrameworkElement]) {
            $control = $root.FindName($name)
        }
        if ($null -ne $control) {
            $controls[$name] = $control
        }
    }
    [pscustomobject]@{
        Path     = $Path
        Root     = $root
        Controls = $controls
    }
}
