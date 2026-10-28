function Invoke-MwpUpdatePauseChange {
    <#
    .SYNOPSIS
        Wspólne wykonanie zmiany pauzy Windows Update po potwierdzeniu: zapis, wpis cofnięcia, log i wynik.

    .DESCRIPTION
        Używana przez Suspend-MwpUpdate, Resume-MwpUpdate i Restore-MwpUpdatePause po ich
        sprawdzeniu uprawnień (Test-MwpUpdatePauseAccess) i ShouldProcess (wzorzec funkcji zmieniającej
        system, ARCHITEKTURA.md). Wpis cofnięcia (z -SaveUndo) przywraca wartości sprzed zmiany
        (Restore-MwpUpdatePause -StateJson) — zapisywany, gdy którakolwiek wartość się zmieniła (także
        po częściowo nieudanym zapisie).

    .PARAMETER Before
        Wartości pauzy przed zmianą (nazwy z Get-MwpUpdateTargetConfig).

    .PARAMETER Values
        Wartości do zapisania ($null = usunięcie).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Funkcja wewnętrzna wywoływana po ShouldProcess funkcji publicznej.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [Parameter(Mandatory)]
        [hashtable] $Before,

        [Parameter(Mandatory)]
        [hashtable] $Values,

        [Parameter(Mandatory)]
        [string] $BeforeText,

        [Parameter(Mandatory)]
        [string] $AfterText,

        [switch] $SaveUndo
    )

    $computerName = $Context.ComputerName
    $common = @{ Operation = $Operation; Target = 'Windows Update'; ComputerName = $computerName }
    $write = Write-MwpUpdatePause -Context $Context -Operation $Operation -Values $Values
    $changed = $false
    if ($null -ne $write.After) {
        foreach ($name in $Values.Keys) {
            if ((ConvertTo-MwpUpdatePauseText -Value $Before[$name]) -ne $write.After[$name]) {
                $changed = $true
            }
        }
    }
    $undoId = $null
    if ($SaveUndo -and $changed) {
        $state = [ordered]@{}
        foreach ($name in (Get-MwpUpdateTargetConfig).PauseValues) {
            $state[$name] = ConvertTo-MwpUpdatePauseText -Value $Before[$name]
        }
        $undo = Save-MwpUndoEntry -Module 'MWP.Update' -Operation $Operation -Target 'Windows Update' -ComputerName $computerName `
            -Description ('Pauza Windows Update: {0} → {1}' -f $BeforeText, $AfterText) -Before $BeforeText -After $AfterText `
            -UndoCommand 'Restore-MwpUpdatePause' -UndoParameters @{ StateJson = (ConvertTo-Json -Compress -InputObject ([pscustomobject]$state)) }
        $undoId = $undo.Id
    }
    if (-not $write.Success) {
        Write-MwpLog -Level Error -Source 'MWP.Update' -Operation $Operation -ComputerName $computerName -Message $write.Result.Message -Data @{ Values = $Values }
        return New-MwpResult @common -Success $false -Changed $changed -Before $BeforeText -UndoId $undoId -Message $write.Result.Message -ErrorMessage $write.Result.ErrorMessage
    }
    $message = "{0} na komputerze '{1}'." -f $AfterText.TrimEnd('.'), $computerName
    Write-MwpLog -Level Info -Source 'MWP.Update' -Operation $Operation -ComputerName $computerName -Message $message -Data @{ Before = $Before; After = $write.After }
    New-MwpResult @common -Success $true -Changed $changed -Before $BeforeText -After $AfterText -UndoId $undoId -Message $message
}
