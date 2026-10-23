function Get-MwpLatestRestorePoint {
    <#
    .SYNOPSIS
        Zwraca najnowszy punkt przywracania systemu (CIM root/default:SystemRestore) albo $null.

    .DESCRIPTION
        Używa CIM, bo Checkpoint-Computer i Get-ComputerRestorePoint istnieją tylko w 5.1.
        Wymaga uprawnień administratora.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $points = @(Get-CimInstance -Namespace 'root/default' -ClassName 'SystemRestore' -ErrorAction Stop)
    if ($points.Count -eq 0) {
        return $null
    }

    $latest = $points | Sort-Object -Property SequenceNumber -Descending | Select-Object -First 1
    [pscustomobject]@{
        SequenceNumber = [long]$latest.SequenceNumber
        Description    = [string]$latest.Description
        CreationTime   = [string]$latest.CreationTime
    }
}
