function Write-MwpUndoStatus {
    <#
    .SYNOPSIS
        Zapisuje w pliku wpisu cofnięcia wynik próby cofnięcia (status, data, ostatni błąd).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateSet('Pending', 'Undone')]
        [string] $Status,

        [AllowNull()]
        [string] $ErrorMessage
    )

    $data = ConvertTo-MwpHashtable -InputObject (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
    $data['status'] = $Status
    if ($Status -eq 'Undone') {
        $data['undoneAt'] = (Get-Date).ToString('o')
        $data['lastError'] = $null
    }
    else {
        $data['lastError'] = $ErrorMessage
    }
    Write-MwpJsonFile -Path $Path -InputObject $data
}
