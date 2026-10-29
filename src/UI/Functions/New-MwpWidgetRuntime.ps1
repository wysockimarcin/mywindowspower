function New-MwpWidgetRuntime {
    <#
    .SYNOPSIS
        Tworzy widget Dashboardu w oknie: wpis konfiguracji + definicja widgetu + własna instancja modułu.

    .DESCRIPTION
        Kontrakt widgetu (D-043): widget ma własną konfigurację (wpis dashboardWidgets), jawne
        powiązanie z modułem i komputerem docelowym oraz własną instancję modułu (New-MwpModuleInstance)
        z własnym kontekstem wykonania. Dzięki temu dwa widgety tego samego komputera nie dzielą
        połączenia ani zadań, a usunięcie widgetu zamyka jego instancję (Remove-MwpWidgetRuntime).
        Błąd utworzenia instancji (np. komputer usunięty z rejestru, moduł bez RemoteTarget) nie jest
        wyjątkiem: widget dostaje stan Error z komunikatem i nie wpływa na pozostałe.
        Zwraca tabelę stanu widgetu (Id, Config, Definition, Parameters, Instance, Status, Message, View,
        Data, LastRefresh, NextRefresh, Task, Pending, Removed, Version).

    .PARAMETER Configuration
        Wpis konfiguracji widgetu (słownik: id, moduleId, widgetId, computerName, title, refreshSeconds, size, parameters).

    .PARAMETER Definition
        Definicja widgetu (MWP.WidgetDefinition z Get-MwpWidgetDefinition).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy obiekty w pamięci procesu (widget i instancję modułu); nie zmienia systemu.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary] $Configuration,

        [Parameter(Mandatory)]
        [PSTypeName('MWP.WidgetDefinition')]
        [object] $Definition
    )

    $parameters = Get-MwpWidgetParameterSet -Configuration $Configuration -Definition $Definition
    $widget = @{
        Id          = [string]$Configuration['id']
        Config      = $Configuration
        Definition  = $Definition
        Parameters  = $parameters
        Instance    = $null
        Status      = 'Idle'
        Message     = $null
        View        = $null
        Data        = $null
        LastRefresh = $null
        LastAttempt = $null
        NextRefresh = [datetime]::MinValue
        Task        = $null
        Pending     = $true
        Removed     = $false
        Version     = 1
    }
    $computerName = [string]$Configuration['computerName']
    try {
        $name = 'Widget: {0} — {1}' -f $Definition.Name, $computerName
        $instance = New-MwpModuleInstance -ModuleId $Definition.ModuleId -ComputerName $computerName -Name $name -ForWidget
        $initialization = Initialize-MwpModuleInstance -Instance $instance
        if (-not $initialization.Success) {
            $null = Close-MwpModuleInstance -Instance $instance
            throw $initialization.Message
        }
        $widget.Instance = $instance
    }
    catch {
        $widget.Status = 'Error'
        $widget.Message = 'Nie udało się przygotować widgetu dla komputera {0}: {1}' -f $computerName, $_.Exception.Message
        $widget.Pending = $false
        $widget.NextRefresh = [datetime]::MaxValue
    }
    $widget
}
