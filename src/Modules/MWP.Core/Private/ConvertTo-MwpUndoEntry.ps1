function ConvertTo-MwpUndoEntry {
    <#
    .SYNOPSIS
        Zamienia dane wpisu cofnięcia (słownik z pliku JSON) na obiekt MWP.UndoEntry.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary] $Data,

        [string] $Path = ''
    )

    $parameters = @{}
    if ($Data['undoParameters'] -is [Collections.IDictionary]) {
        foreach ($key in $Data['undoParameters'].Keys) {
            $parameters[[string]$key] = $Data['undoParameters'][$key]
        }
    }

    [pscustomobject]@{
        PSTypeName     = 'MWP.UndoEntry'
        Id             = [string]$Data['id']
        CreatedAt      = ConvertTo-MwpDateTime -Value $Data['createdAt']
        Module         = [string]$Data['module']
        Operation      = [string]$Data['operation']
        Target         = [string]$Data['target']
        ComputerName   = [string]$Data['computerName']
        Description    = [string]$Data['description']
        Before         = $Data['before']
        After          = $Data['after']
        UndoCommand    = [string]$Data['undoCommand']
        UndoParameters = $parameters
        Status         = [string]$Data['status']
        UndoneAt       = ConvertTo-MwpDateTime -Value $Data['undoneAt']
        LastError      = $Data['lastError']
        Path           = $Path
    }
}
