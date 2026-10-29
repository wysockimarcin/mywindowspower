function Test-MwpWingetId {
    <#
    .SYNOPSIS
        Sprawdza identyfikator pakietu winget przed przekazaniem go do winget.exe (D-015).

    .DESCRIPTION
        Identyfikator źródła (np. Git.Git, Microsoft.VCRedist.2015+.x64): litery, cyfry, . _ + -
        bez spacji, do 128 znaków. Z -AllowLocal także identyfikatory lokalne winget: ARP\Machine|User\X64|X86\<klucz>
        (klucz rejestru Uninstall, może mieć spacje) i MSIX\<pełna nazwa pakietu>. Bez cudzysłowów,
        znaków sterujących i ukośnika na końcu, więc argument nie może się „rozlać” na inne.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Id,

        [switch] $AllowLocal
    )

    if ([string]::IsNullOrWhiteSpace($Id) -or $Id.Length -gt 300 -or $Id -match '["\x00-\x1F]' -or $Id.EndsWith('\')) {
        return $false
    }
    if ($Id -match '^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$') {
        return $true
    }
    if ($AllowLocal) {
        return ($Id -match '^ARP\\(Machine|User)\\(X64|X86|Arm64|Arm)\\[^\\]{1,250}$' -and $Id -notmatch '\s{2,}' -and $Id -eq $Id.Trim()) -or
        ($Id -match '^MSIX\\[A-Za-z0-9][A-Za-z0-9._~-]{1,250}$')
    }
    $false
}
