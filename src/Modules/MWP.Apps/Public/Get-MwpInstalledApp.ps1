function Get-MwpInstalledApp {
    <#
    .SYNOPSIS
        Odczytuje zainstalowane programy komputera docelowego: rejestr Uninstall (64/32 bit, komputer i użytkownik) oraz pakiety Appx.

    .DESCRIPTION
        Operacja klasy Odczyt. Jedno wywołanie na komputerze kontekstu (localhost albo zdalnym, D-019):
        klucze HKLM\…\Uninstall i WOW6432Node\…\Uninstall, programy użytkownika i pakiety Appx konta
        sesji. Programy użytkownika (D-050): lokalnie — bieżące konto (HKCU); zdalnie — tylko profile
        wskazane w -UserSid (załadowane w HKEY_USERS, czyli zalogowanych użytkowników; lista profili
        jest w wyniku). Bez -AsOperation zwraca MWP.Result z MWP.AppInventory w Data (składniki
        systemowe są w danych, oznaczone IsSystem — filtruje Select-MwpInstalledApp). Z -AsOperation
        startuje w puli runspace'ów (Start-MwpOperation) i zwraca uchwyt MWP.Operation — wynik zamienia
        Resolve-MwpInstalledApp.

    .PARAMETER UserSid
        Profile użytkowników (SID), których programy odczytać z HKEY_USERS.

    .PARAMETER NoCurrentUser
        Bez programów bieżącego konta (domyślnie lokalnie są, zdalnie nie).

    .PARAMETER NoAppx
        Bez pakietów Appx.

    .PARAMETER WidgetParameters
        Parametry widgetu „Programy” (kontrakt D-043); dane są zawsze pełne, sekcje wybiera ConvertTo-MwpAppsSummaryView.

    .EXAMPLE
        (Get-MwpInstalledApp).Data.Apps | Select-MwpInstalledApp -Search 'git' | Format-Table Name, Version, Publisher, ScopeText
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043, D-053); sekcje i liczbę pozycji wybiera funkcja widoku.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidatePattern('^S-1-5-21-[0-9-]+$')]
        [string[]] $UserSid = @(),

        [switch] $NoCurrentUser,

        [switch] $NoAppx,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Apps.Inventory'
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            CurrentUser = $Context.Mode -eq 'Local' -and -not $NoCurrentUser
            UserSids    = @($UserSid)
            IncludeAppx = -not $NoAppx
        })
    $block = Get-MwpAppsScript -Name Inventory
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    $inventory = Resolve-MwpInstalledApp -Data $result
    if ($null -eq $inventory) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił listy programów." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
    }
    if ($inventory.Error) {
        return New-MwpResult @common -Success $false -Message ("Odczyt programów na komputerze '{0}' nie powiódł się: {1}" -f $Context.ComputerName, $inventory.Error) -ErrorMessage $inventory.Error -Data $inventory
    }
    New-MwpResult @common -Success $true -Message ("Odczytano programy komputera '{0}' ({1} pozycji)." -f $Context.ComputerName, @($inventory.Apps).Count) -Data $inventory
}
