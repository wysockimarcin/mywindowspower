# Moduł MWP.Przyklad (przykład paczki .mwpmod). Funkcje publiczne leżą w Public\.
# Każdy plik zawiera jedną funkcję o nazwie zgodnej z nazwą pliku.

Set-StrictMode -Version Latest

$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($file in $public) {
    . $file.FullName
}

Export-ModuleMember -Function ($public | ForEach-Object { $_.BaseName })
