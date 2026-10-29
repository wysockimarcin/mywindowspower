function Connect-MwpUiTargetInstance {
    <#
    .SYNOPSIS
        Łączy w tle instancje komputera, które mogą użyć sprawdzonego hasła z pamięci procesu (bez okna).

    .DESCRIPTION
        Wywoływana po udanym połączeniu instancji albo widgetu z komputerem (D-052): pozostałe instancje
        tego komputera (Get-MwpUiAutoConnectInstance — bez rozłączonych ręcznie) łączą się same, więc ich
        plakietka i przycisk „Połącz” zgadzają się z tym, że operacje modułu już działają. Każda instancja
        łączy się własnym połączeniem w zadaniu w tle (D-019).

    .PARAMETER ComputerName
        Komputer, z którym właśnie się połączono.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    $ui = $script:MwpUi
    if ($null -eq $ui -or $ui.Closing) {
        return
    }
    foreach ($entry in @(Get-MwpUiAutoConnectInstance -Entry @($ui.Instances.Values) -ComputerName $ComputerName)) {
        Connect-MwpUiInstance -Entry $entry -Automatic
    }
}
