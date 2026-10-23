# Moduł MWP.Remote. Funkcje publiczne leżą w Public\, wewnętrzne w Private\.
# Każdy plik zawiera jedną funkcję o nazwie zgodnej z nazwą pliku.

Set-StrictMode -Version Latest

# Rejestry procesu hosta (D-019, D-023). Nie przechowują „bieżącego komputera": każda instancja
# i operacja ma własny kontekst wykonania. Tabele synchronizowane, bo korzystają z nich runspace'y.
# - instancje modułów: Id instancji -> MWP.ModuleInstance,
# - operacje asynchroniczne: Id operacji -> MWP.Operation,
# - pula runspace'ów z limitem równoległości (tworzona przy pierwszej operacji).
$script:MwpInstanceRegistry = [hashtable]::Synchronized(@{})
$script:MwpOperationRegistry = [hashtable]::Synchronized(@{})
$script:MwpOperationPool = $null

$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

foreach ($file in @($private + $public)) {
    . $file.FullName
}

# Usunięcie modułu z sesji anuluje operacje i zamyka pulę runspace'ów.
$ExecutionContext.SessionState.Module.OnRemove = {
    Close-MwpOperationPool
}

Export-ModuleMember -Function ($public | ForEach-Object { $_.BaseName })
