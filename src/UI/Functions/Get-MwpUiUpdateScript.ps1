function Get-MwpUiUpdateScript {
    <#
    .SYNOPSIS
        Zwraca blok zadania GUI widoku Windows Update, który instaluje zaznaczone aktualizacje (Install-MwpUpdate -Confirm:$false z tabelą postępu).

    .DESCRIPTION
        Używany przez Start-MwpUiUpdateInstall (Start-MwpUiTask; blok jest odtwarzany z tekstu
        w runspace puli GUI, dane przychodzą w parametrach, pierwszy parametr to tabela postępu).
        Moduł MWP.Update jest importowany z podanej ścieżki manifestu. Install-MwpUpdate ustawia
        Percent i Message, a CancelRequested przerywa pracę między aktualizacjami. Wywoływany dopiero
        po oknie potwierdzenia. Kod widoku nie wywołuje poleceń systemowych (D-015, D-039).
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    {
        param($Progress, [string] $ModulePath, $Context, [string[]] $UpdateId)
        Import-Module -Name $ModulePath
        Install-MwpUpdate -UpdateId $UpdateId -Context $Context -Progress $Progress -Confirm:$false
    }
}
