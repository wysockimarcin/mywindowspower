function Start-MwpWidgetRefresh {
    <#
    .SYNOPSIS
        Uruchamia odświeżenie widgetu w tle: funkcja danych modułu jako operacja na komputerze widgetu.

    .DESCRIPTION
        Wywoływana w wątku okna; nie czeka na wynik. Funkcja danych (DataCommand z kontraktu widgetu,
        D-043) dostaje kontekst wykonania instancji widgetu, -AsOperation i parametry widgetu, i zwraca
        uchwyt Start-MwpOperation; Register-MwpUiOperation odbiera wynik w wątku okna
        (Complete-MwpWidgetRefresh). Operacja należy do instancji widgetu, więc usunięcie widgetu
        (Close-MwpModuleInstance) ją anuluje. Widget komputera zdalnego bez poświadczeń dostaje stan
        NeedsCredential bez uruchamiania operacji (okno poświadczeń otwiera tylko użytkownik).
        Wyjątek funkcji danych zmienia stan tylko tego widgetu (Error); pozostałe działają dalej.
        Zadanie jest ciche (-Quiet): nie zajmuje paska stanu i nie wstrzymuje zamknięcia okna.
        Zwraca $true, gdy operacja wystartowała.

    .PARAMETER Widget
        Widget (tabela z New-MwpWidgetRuntime).

    .PARAMETER Registry
        Lista zadań okna.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt danych widgetu (operacja klasy Odczyt); nie zmienia systemu.')]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Widget,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Collections.Generic.List[object]] $Registry
    )

    if ($Widget.Removed -or $null -ne $Widget.Task) {
        return $false
    }
    $Widget.Pending = $false
    $Widget.Version++
    if ($null -eq $Widget.Instance) {
        return $false
    }
    $context = $Widget.Instance.Context
    $state = Get-MwpConnectionStateInfo -Context $context
    if ($state.NeedsCredential) {
        $Widget.Status = 'NeedsCredential'
        $Widget.Message = 'Komputer {0} wymaga poświadczeń. Kliknij „Połącz”.' -f (Format-MwpTargetLabel -Context $context)
        return $false
    }

    $title = if ([string]$Widget.Config['title']) { [string]$Widget.Config['title'] } else { $Widget.Definition.Name }
    try {
        $command = $Widget.Definition.DataCommand
        $operation = & $command -Context $context -AsOperation -WidgetParameters $Widget.Parameters
        if ($null -eq $operation -or $operation.PSObject.TypeNames -notcontains 'MWP.Operation') {
            throw ("Funkcja danych {0} nie zwróciła operacji (MWP.Operation)." -f $command)
        }
        $Widget.Task = Register-MwpUiOperation -Registry $Registry -Operation $operation -Quiet -Name ('Widget: {0} — {1}' -f $title, (Format-MwpTargetLabel -Context $context)) -State $Widget -OnCompleted {
            param($Task)
            Complete-MwpWidgetRefresh -Widget $Task.State -Task $Task
        }
        $Widget.Status = 'Loading'
        $true
    }
    catch {
        $Widget.Status = 'Error'
        $Widget.Message = 'Nie udało się odświeżyć widgetu: {0}' -f $_.Exception.Message
        $refresh = [int]$Widget.Config['refreshSeconds']
        $Widget.NextRefresh = $(if ($refresh -gt 0) { (Get-Date).AddSeconds($refresh) } else { [datetime]::MaxValue })
        $false
    }
}
