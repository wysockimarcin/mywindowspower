function Get-MwpConfigPath {
    <#
    .SYNOPSIS
        Zwraca ścieżki szablonu ustawień (repozytorium) i ustawień lokalnych (poza repozytorium).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $configDirectory = Join-Path -Path (Get-MwpProjectRoot) -ChildPath 'config'
    [pscustomobject]@{
        Example = Join-Path -Path $configDirectory -ChildPath 'settings.example.json'
        Local   = Join-Path -Path $configDirectory -ChildPath 'settings.local.json'
    }
}
