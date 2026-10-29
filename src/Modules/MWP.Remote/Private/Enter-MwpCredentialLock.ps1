function Enter-MwpCredentialLock {
    <#
    .SYNOPSIS
        Zajmuje blokadę poświadczeń komputera (jedno odczytanie magazynu i jedna próba logowania naraz).

    .DESCRIPTION
        Gdy kilka instancji lub widgetów tego samego komputera łączy się równocześnie hasłem z magazynu,
        pierwsza sprawdza hasło, a pozostałe po zwolnieniu blokady biorą wynik z pamięci podręcznej
        (Verified albo Invalid), bez drugiego odczytu i drugiej próby (D-052). Blokada jest wspólna dla
        runspace'ów procesu. Zwraca $true, gdy zajęto ją w limicie czasu (zwalnia Exit-MwpCredentialLock).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [ValidateRange(0, 3600)]
        [int] $TimeoutSeconds = 60
    )

    $cache = Get-MwpCredentialCache
    [Threading.Monitor]::Enter($cache.SyncRoot)
    try {
        $semaphore = $cache.Locks[$ComputerName]
        if ($null -eq $semaphore) {
            $semaphore = New-Object -TypeName Threading.SemaphoreSlim -ArgumentList 1, 1
            $cache.Locks[$ComputerName] = $semaphore
        }
    }
    finally {
        [Threading.Monitor]::Exit($cache.SyncRoot)
    }
    $semaphore.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))
}
