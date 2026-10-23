function Get-MwpUndoEntry {
    <#
    .SYNOPSIS
        Zwraca wpisy rejestru cofnięć, od najnowszego.

    .DESCRIPTION
        Uszkodzony plik wpisu jest pomijany z ostrzeżeniem. Daty są zwracane jako [datetime]
        w 5.1 i 7.x.

    .PARAMETER Id
        Identyfikator wpisu (GUID).

    .PARAMETER ComputerName
        Tylko wpisy dotyczące tego komputera.

    .PARAMETER Status
        Pending (do cofnięcia) albo Undone (cofnięte).

    .EXAMPLE
        Get-MwpUndoEntry -Status Pending -ComputerName localhost
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [ValidateSet('Pending', 'Undone')]
        [string] $Status
    )

    # Id trafia do nazwy pliku, więc musi być GUID-em (bez ścieżek typu ..\).
    $guid = [guid]::Empty
    if ($PSBoundParameters.ContainsKey('Id') -and -not [guid]::TryParse($Id, [ref]$guid)) {
        throw ("Niepoprawny identyfikator wpisu cofnięcia: '{0}'." -f $Id)
    }

    $directory = Get-MwpDataPath -Kind Undo
    if (-not (Test-Path -LiteralPath $directory)) {
        return
    }

    if ($PSBoundParameters.ContainsKey('Id')) {
        $files = @(Get-ChildItem -LiteralPath $directory -Filter ($guid.ToString() + '.json') -File)
    }
    else {
        $files = @(Get-ChildItem -LiteralPath $directory -Filter '*.json' -File)
    }

    $entries = foreach ($file in $files) {
        try {
            $data = ConvertTo-MwpHashtable -InputObject (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
            ConvertTo-MwpUndoEntry -Data $data -Path $file.FullName
        }
        catch {
            Write-Warning ("Pominięto uszkodzony wpis cofnięcia {0}: {1}" -f $file.Name, $_.Exception.Message)
        }
    }

    # $PSBoundParameters wewnątrz bloku Where-Object dotyczyłby bloku, nie funkcji.
    $byComputer = $PSBoundParameters.ContainsKey('ComputerName')
    $byStatus = $PSBoundParameters.ContainsKey('Status')
    $entries |
        Where-Object { -not $byComputer -or $_.ComputerName -eq $ComputerName } |
        Where-Object { -not $byStatus -or $_.Status -eq $Status } |
        Sort-Object -Property CreatedAt -Descending
}
