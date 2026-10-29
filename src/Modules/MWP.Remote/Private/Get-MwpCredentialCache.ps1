function Get-MwpCredentialCache {
    <#
    .SYNOPSIS
        Zwraca pamięć podręczną poświadczeń procesu: jedną, wspólną dla wszystkich runspace'ów (D-052).

    .DESCRIPTION
        Instancje i widgety jednego uruchomienia mają własne konteksty (D-035, D-043), a zadania okna
        działają w osobnych runspace'ach z własną kopią modułu, więc zmienna modułu ($script:) nie byłaby
        wspólna. Pamięć leży w danych domeny aplikacji (AppDomain), jedna na proces, i znika z nim.
        Nie przechowuje „bieżącego komputera”: wpisy są kluczowane nazwą komputera, a kontekst sam pyta
        o swój. Zawartość (tabele synchronizowane, zmiany złożone pod blokadą SyncRoot):
        - Entries: komputer -> @{ Credential; State (Verified | Invalid); Generation; UserName; Source; ChangedAt },
        - Locks: komputer -> SemaphoreSlim (jedno odczytanie magazynu i jedna próba logowania naraz),
        - Generation: licznik zmian (numer generacji poświadczenia).
        Dostęp do tej pamięci mają tylko funkcje *-MwpCachedCredential i *-MwpCredentialLock (test
        architektoniczny).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $key = 'MyWindowsPower.Remote.CredentialCache.v1'
    $domain = [AppDomain]::CurrentDomain
    $cache = $domain.GetData($key)
    if ($null -ne $cache) {
        return $cache
    }
    [Threading.Monitor]::Enter($domain)
    try {
        $cache = $domain.GetData($key)
        if ($null -eq $cache) {
            $cache = [hashtable]::Synchronized(@{
                    Entries    = [hashtable]::Synchronized(@{})
                    Locks      = [hashtable]::Synchronized(@{})
                    Generation = 0
                })
            $domain.SetData($key, $cache)
        }
    }
    finally {
        [Threading.Monitor]::Exit($domain)
    }
    $cache
}
