# Moduł MWP.UI — host modułów w oknie WPF (FAZA 4, D-039).
# Functions\: logika prezentacji bez zależności od WPF (testowana w Pester).
# Wpf\: ładowanie XAML, okna, widoki i obsługa zdarzeń (testowane ręcznie na Windows 11).
# Każdy plik zawiera jedną funkcję o nazwie zgodnej z nazwą pliku.
# Moduł nie jest modułem obszaru (nie ma kontraktu PrivateData.MWP) i nie zawiera logiki systemowej
# ani logiki połączeń zdalnych: wywołuje funkcje MWP.Core i MWP.Remote (D-015, D-019).

Set-StrictMode -Version Latest

# Stan powłoki GUI (okno, kontrolki, widoki instancji, zadania w tle). To stan prezentacji, nie
# „bieżący komputer": każda instancja modułu ma własny kontekst wykonania w MWP.Remote (D-019).
$script:MwpUi = $null

$files = @()
foreach ($folder in @('Functions', 'Wpf')) {
    $files += @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath $folder) -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
}
foreach ($file in $files) {
    . $file.FullName
}

Export-ModuleMember -Function ($files | ForEach-Object { $_.BaseName })
