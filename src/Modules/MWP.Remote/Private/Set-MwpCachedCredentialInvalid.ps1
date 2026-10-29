function Set-MwpCachedCredentialInvalid {
    <#
    .SYNOPSIS
        Blokada ponowień (D-052): oznacza poświadczenie komputera jako odrzucone w tym uruchomieniu.

    .DESCRIPTION
        Po pierwszej odmowie dostępu (Unauthorized) hasło znika z pamięci, a stan Invalid sprawia, że
        żadna instancja ani widget tego komputera nie spróbuje się zalogować do czasu akcji użytkownika
        (nowe hasło w oknie, „Zapomnij hasło”). Chroni to konto przed blokadą przy odświeżaniu widgetów.
        Wpis w Menedżerze poświadczeń zostaje (decyzja użytkownika: unieważnić, nie usuwać).
        -Generation: numer generacji poświadczenia, które odrzucono; gdy w pamięci jest już nowsze
        (użytkownik podał nowe hasło), nic się nie zmienia. -1 = hasło z magazynu, jeszcze nie w pamięci.
        Zwraca $true, gdy stan się zmienił (wtedy też wpis w logu, bez hasła).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko pamięć procesu; nie zmienia systemu.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [int] $Generation = -1,

        [ValidateSet('Dialog', 'Store', 'Context')]
        [string] $Source = 'Store'
    )

    $cache = Get-MwpCredentialCache
    $changed = $false
    [Threading.Monitor]::Enter($cache.SyncRoot)
    try {
        $entry = $cache.Entries[$ComputerName]
        $current = $null -ne $entry -and $entry['State'] -eq 'Verified' -and [int]$entry['Generation'] -eq $Generation
        $fromStore = $Generation -lt 0 -and ($null -eq $entry -or $entry['State'] -ne 'Verified')
        if ($current -or $fromStore) {
            $generation = [int]$cache['Generation'] + 1
            $cache['Generation'] = $generation
            $cache.Entries[$ComputerName] = @{
                Credential = $null
                State      = 'Invalid'
                Generation = $generation
                UserName   = $(if ($null -ne $entry) { $entry['UserName'] } else { $null })
                Source     = $(if ($current) { $entry['Source'] } else { $Source })
                ChangedAt  = Get-Date
            }
            $changed = $true
        }
    }
    finally {
        [Threading.Monitor]::Exit($cache.SyncRoot)
    }
    if ($changed) {
        Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation 'Remote.CredentialRejected' -ComputerName $ComputerName `
            -Message ("Komputer '{0}' odrzucił poświadczenie; automatyczne ponowienia wszystkich instancji i widgetów tego komputera są wstrzymane do czasu podania hasła przez użytkownika." -f $ComputerName)
    }
    $changed
}
