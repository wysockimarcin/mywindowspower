function Test-MwpRemoteNameMatch {
    <#
    .SYNOPSIS
        Porównuje nazwę komputera z rejestru z nazwami zgłoszonymi przez komputer zdalny (D-054).

    .DESCRIPTION
        Zwraca $true (zgodna), $false (niezgodna — NameMismatch) albo $null (bez weryfikacji: nazwa
        w rejestrze jest adresem IPv4 albo komputer nie zgłosił żadnej nazwy). RemoteNames to zwykle
        $env:COMPUTERNAME (NetBIOS, najwyżej 15 znaków) i [Net.Dns]::GetHostName() (pełna nazwa hosta);
        wystarczy zgodność z jedną z nich. Porównanie: pierwszy człon przed kropką, bez wielkości liter.
        Ta sama reguła działa w bloku operacji w tle (Start-MwpOperation), który nie widzi funkcji modułu.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Name,

        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]] $RemoteNames
    )

    $expected = Get-MwpExpectedComputerName -Name $Name
    $reported = @($RemoteNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($expected -eq '' -or $reported.Count -eq 0) {
        return $null
    }
    foreach ($remote in $reported) {
        if ([string]::Equals($remote.Trim().Split('.')[0], $expected, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    $false
}
