function Get-MwpTargetCredentialInfo {
    <#
    .SYNOPSIS
        Zwraca metadane poświadczeń komputerów zdalnych: czy hasło jest zapisane i czy jest w pamięci — nigdy hasło.

    .DESCRIPTION
        Dla wskaźnika „hasło zapisane / niezapisane” i decyzji warstwy UI (D-052). Pola:
        ComputerName, Entry (nazwa wpisu MWP:<komputer>), StoreEnabled (ustawienie remoteCredentialStore),
        Stored (wpis istnieje w Menedżerze poświadczeń), StoredUserName, LastWritten, StoreError
        (komunikat, gdy wpisu nie da się odczytać), Cached (sprawdzone hasło w pamięci tego uruchomienia),
        Invalid (komputer odrzucił hasło — automatyczne ponowienia wstrzymane), CachedUserName.
        -SkipStore czyta tylko pamięć procesu (bez magazynu i bez pliku ustawień; StoreEnabled, Stored
        = $null) — do częstego odświeżania stanu w oknie. Bez -Name: komputery zdalne z rejestru.

    .EXAMPLE
        Get-MwpTargetCredentialInfo -Name 'PC-BIURO'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [switch] $SkipStore
    )

    if (-not $PSBoundParameters.ContainsKey('Name')) {
        $Name = @(Get-MwpTarget | Where-Object { -not $_.IsLocal } | ForEach-Object { $_.Name })
    }
    $enabled = $null
    if (-not $SkipStore) {
        $enabled = Test-MwpCredentialStoreEnabled
    }
    foreach ($computer in @($Name)) {
        $isLocal = Test-MwpLocalTargetName -Name $computer
        $cached = $null
        if (-not $isLocal) {
            $cached = Get-MwpCachedCredential -ComputerName $computer
        }
        $stored = $null
        if (-not $SkipStore -and -not $isLocal) {
            $stored = Test-MwpStoredCredential -ComputerName $computer
        }
        [pscustomobject]@{
            PSTypeName     = 'MWP.TargetCredentialInfo'
            ComputerName   = $computer
            Entry          = $(if ($isLocal) { $null } else { Get-MwpStoredCredentialName -ComputerName $computer })
            StoreEnabled   = $enabled
            Stored         = $(if ($SkipStore) { $null } else { $null -ne $stored -and $stored.Status -eq 'Found' })
            StoredUserName = $(if ($null -ne $stored) { $stored.UserName } else { $null })
            LastWritten    = $(if ($null -ne $stored) { $stored.LastWritten } else { $null })
            StoreError     = $(if ($null -ne $stored -and $stored.Status -in @('Error', 'InvalidFormat')) { $stored.Message } else { $null })
            Cached         = $null -ne $cached -and $cached['State'] -eq 'Verified'
            Invalid        = $null -ne $cached -and $cached['State'] -eq 'Invalid'
            CachedUserName = $(if ($null -ne $cached) { $cached['UserName'] } else { $null })
        }
    }
}
