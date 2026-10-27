function Test-MwpScheduledTaskName {
    <#
    .SYNOPSIS
        Sprawdza folder i nazwę zadania harmonogramu przed użyciem w poleceniach na komputerze docelowym.

    .DESCRIPTION
        Folder (TaskPath): zaczyna się i kończy znakiem \, bez symboli wieloznacznych (* ? [ ]),
        cudzysłowów i znaków niedozwolonych w nazwach plików. Nazwa (TaskName): bez \ / : * ? " < > |
        i znaków sterujących, bez spacji na początku i końcu. Zadanie jest potem wybierane na
        komputerze docelowym przez dokładne porównanie nazwy (nawiasy [ ] w nazwie są dozwolone).

    .EXAMPLE
        Test-MwpScheduledTaskName -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $TaskPath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $TaskName
    )

    if ($TaskPath.Length -gt 260 -or $TaskPath -notmatch '^\\([^\\/:*?"<>|\[\]\x00-\x1F]+\\)*$') {
        return $false
    }
    if ($TaskName.Length -lt 1 -or $TaskName.Length -gt 238 -or $TaskName -match '[\\/:*?"<>|\x00-\x1F]' -or $TaskName -ne $TaskName.Trim()) {
        return $false
    }
    $true
}
