function Get-MwpUpdateStatus {
    <#
    .SYNOPSIS
        Odczytuje stan Windows Update na komputerze docelowym: usługi, wymagany restart, ostatnie wyszukiwanie i instalację, pauzę, zasady i kopie folderów z resetu.

    .DESCRIPTION
        Operacja klasy Odczyt (nic nie zmienia, bez łączenia z serwerem aktualizacji). Jedno wywołanie
        na komputerze kontekstu (localhost albo zdalnym, D-019): Win32_Service (wuauserv, bits,
        cryptsvc, usosvc), Microsoft.Update.SystemInfo i Microsoft.Update.AutoUpdate (COM), klucze
        restartu, wartości pauzy z HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings i zasad
        z HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate.
        Bez -AsOperation zwraca MWP.Result z MWP.UpdateStatus w Data. Z -AsOperation startuje w puli
        runspace'ów (Start-MwpOperation) i zwraca uchwyt MWP.Operation — wynik zamienia
        Resolve-MwpUpdateStatus.

    .PARAMETER WidgetParameters
        Parametry widgetu „Windows Update” (kontrakt D-043); dane są zawsze pełne, sekcje wybiera ConvertTo-MwpUpdateStatusView.

    .EXAMPLE
        (Get-MwpUpdateStatus).Data | Format-List RebootRequired, PauseText, LastSearchText
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043, D-053); sekcje wybiera funkcja widoku.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Update.Status'
    $config = Get-MwpUpdateTargetConfig
    $request = ConvertTo-Json -Compress -Depth 5 -InputObject ([pscustomobject]@{
            Services     = @($config.Services)
            RebootKeys   = @($config.RebootKeys)
            PauseKey     = $config.PauseKey
            PauseValues  = @($config.PauseValues)
            PolicyKey    = $config.PolicyKey
            PolicyValues = @($config.PolicyValues)
            WindowsRoot  = $config.WindowsRoot
            ResetFolders = @($config.ResetFolders)
        })
    $block = Get-MwpUpdateScript -Name Status
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    $status = Resolve-MwpUpdateStatus -Data $result
    if ($null -eq $status) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' nie zwrócił stanu Windows Update." -f $Context.ComputerName) -ErrorMessage $result.ErrorMessage
    }
    New-MwpResult @common -Success $true -RestartRequired:([bool]$status.RebootRequired) -Message ("Odczytano stan Windows Update komputera '{0}'." -f $Context.ComputerName) -Data $status
}
