# Moduł MWP.Security. Funkcje publiczne leżą w Public\, wewnętrzne w Private\.
# Każdy plik zawiera jedną funkcję o nazwie zgodnej z nazwą pliku.

Set-StrictMode -Version Latest

$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

foreach ($file in @($private + $public)) {
    . $file.FullName
}

Export-ModuleMember -Function ($public | ForEach-Object { $_.BaseName })