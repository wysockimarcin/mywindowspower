function Remove-MwpWidgetRuntime {
    <#
    .SYNOPSIS
        Usuwa widget z okna: anuluje jego odświeżanie i zamyka jego instancję modułu (zwalnia zasoby).

    .DESCRIPTION
        Izolacja widgetów (D-043): anulowane jest tylko zadanie tego widgetu (Stop-MwpUiTask), a jego
        instancja jest zamykana przez Close-MwpModuleInstance (anulowanie operacji instancji,
        zamknięcie sesji, usunięcie poświadczeń z pamięci). Inne widgety, także dla tego samego
        komputera, działają dalej. Wynik anulowanego zadania, który dotrze później, jest pomijany
        (Removed). Konfigurację zapisuje wywołujący. Błąd zamykania instancji nie przerywa usuwania.

    .PARAMETER Widget
        Widget (tabela z New-MwpWidgetRuntime).
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Widget
    )

    if ($Widget.Removed -or -not $PSCmdlet.ShouldProcess(('widget {0}' -f $Widget.Id), 'Usunięcie widgetu z Dashboardu')) {
        return
    }
    $Widget.Removed = $true
    if ($null -ne $Widget.Task) {
        try {
            Stop-MwpUiTask -Task $Widget.Task -Confirm:$false
        }
        catch {
            Write-Warning ("Anulowanie odświeżania widgetu {0}: {1}" -f $Widget.Id, $_.Exception.Message)
        }
    }
    if ($null -ne $Widget.Instance) {
        try {
            $null = Close-MwpModuleInstance -Instance $Widget.Instance
        }
        catch {
            Write-Warning ("Zamykanie instancji widgetu {0}: {1}" -f $Widget.Id, $_.Exception.Message)
        }
        $Widget.Instance = $null
    }
    $Widget.View = $null
    $Widget.Data = $null
}
