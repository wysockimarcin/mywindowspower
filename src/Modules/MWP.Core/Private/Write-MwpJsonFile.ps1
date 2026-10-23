function Write-MwpJsonFile {
    <#
    .SYNOPSIS
        Zapisuje obiekt jako JSON (UTF-8 bez BOM) atomowo: plik tymczasowy, potem podmiana.

    .DESCRIPTION
        Przerwanie zapisu (awaria, brak miejsca) nie zostawia uszkodzonego pliku docelowego:
        albo zostaje stara wersja, albo jest nowa. Katalog docelowy jest tworzony w razie potrzeby.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject,

        [ValidateRange(1, 100)]
        [int] $Depth = 10
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }

    $json = ConvertTo-Json -InputObject $InputObject -Depth $Depth
    $temp = '{0}.{1}.tmp' -f $Path, [guid]::NewGuid().ToString('N')
    $encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
    try {
        [IO.File]::WriteAllText($temp, $json, $encoding)
        if (Test-Path -LiteralPath $Path) {
            # $null przekazany do parametru [string] metody .NET staje się pustym tekstem; brak kopii zapasowej to NullString.
            [IO.File]::Replace($temp, $Path, [NullString]::Value)
        }
        else {
            [IO.File]::Move($temp, $Path)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}
