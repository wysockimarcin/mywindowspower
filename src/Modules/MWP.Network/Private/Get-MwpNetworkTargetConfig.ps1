function Get-MwpNetworkTargetConfig {
    <#
    .SYNOPSIS
        Zwraca stałe modułu sieci: folder i prefiks zadań wycofania, domyślny limit czasu na zatwierdzenie i limit czasu testów.

    .DESCRIPTION
        Jedno miejsce stałych (D-049) — w testach podmieniane mockiem. Zadania wycofania leżą
        w folderze harmonogramu \MyWindowsPower\ z nazwą MWP-NetworkRollback-<identyfikator zmiany>.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    [pscustomobject]@{
        TaskPath               = '\MyWindowsPower\'
        TaskPrefix             = 'MWP-NetworkRollback-'
        DefaultRollbackSeconds = 120
        TestTimeoutMs          = 3000
        NetshPath              = '%SystemRoot%\System32\netsh.exe'
    }
}
