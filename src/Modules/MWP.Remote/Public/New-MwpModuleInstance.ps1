function New-MwpModuleInstance {
    <#
    .SYNOPSIS
        Tworzy instancję modułu: konkretne uruchomienie definicji modułu dla jednego komputera docelowego.

    .DESCRIPTION
        Definicja modułu nie jest instancją (D-019, D-024). Instancja ma własny identyfikator,
        własny kontekst wykonania (tworzony tu, nigdy współdzielony), własny stan (State — nowa,
        pusta tabela) i cykl życia: Created -> Initialized (Initialize-MwpModuleInstance) ->
        Closed (Close-MwpModuleInstance: anulowanie operacji, zamknięcie sesji, zwolnienie stanu).
        Fabryką instancji jest host (MWP.Remote); moduł nie musi jej dostarczać (D-035).
        Warunki: definicja istnieje i ma poprawny kontrakt; nie jest modułem bazowym (wyjątek: instancja
        widgetu Dashboardu, -ForWidget, gdy moduł bazowy deklaruje tryb DashboardWidget — D-053); dla
        komputera zdalnego moduł deklaruje możliwość RemoteTarget w Capabilities.
        Instancja trafia do rejestru instancji procesu (Get-MwpModuleInstance).

    .PARAMETER ModuleId
        Id modułu albo nazwa jego folderu (MWP.<Nazwa>).

    .PARAMETER Name
        Nazwa wyświetlana instancji; domyślnie „<nazwa modułu> — <komputer>".

    .PARAMETER ForWidget
        Instancja widgetu Dashboardu (New-MwpWidgetRuntime): moduł musi deklarować tryb DashboardWidget;
        dozwolona także dla modułu bazowego (D-053).

    .EXAMPLE
        $local = New-MwpModuleInstance -ModuleId 'Services'
        $remote = New-MwpModuleInstance -ModuleId 'Services' -ComputerName 'PC-BIURO' -Credential (Get-Credential)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy tylko obiekt w pamięci procesu; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleId,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [AllowNull()]
        [pscredential] $Credential,

        [AllowNull()]
        [Collections.IDictionary] $ModuleParameters,

        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [switch] $ForWidget
    )

    $definition = @(Get-MwpModuleDefinition | Where-Object { $_.Id -eq $ModuleId -or $_.ModuleName -eq $ModuleId }) | Select-Object -First 1
    if ($null -eq $definition) {
        throw ("Nie znaleziono modułu '{0}'." -f $ModuleId)
    }
    if (-not $definition.IsValid) {
        throw ("Moduł '{0}' ma niepoprawny kontrakt: {1}" -f $definition.ModuleName, ($definition.Errors -join ' '))
    }
    $widgetMode = @($definition.SupportedPresentationModes) -contains 'DashboardWidget'
    if ($ForWidget -and -not $widgetMode) {
        throw ("Moduł '{0}' nie udostępnia widgetów (brak trybu DashboardWidget)." -f $definition.ModuleName)
    }
    if ($definition.IsBase -and -not $ForWidget) {
        throw ("Moduł bazowy '{0}' nie tworzy instancji (poza widgetem Dashboardu)." -f $definition.ModuleName)
    }

    $id = [guid]::NewGuid().ToString()
    $contextArguments = @{ ComputerName = $ComputerName; InstanceId = $id; ModuleParameters = $ModuleParameters }
    if ($null -ne $Credential) {
        $contextArguments['Credential'] = $Credential
    }
    $context = New-MwpExecutionContext @contextArguments
    if ($context.Mode -eq 'Remote' -and @($definition.Capabilities) -notcontains 'RemoteTarget') {
        throw ("Moduł '{0}' nie obsługuje komputerów zdalnych (brak RemoteTarget w Capabilities kontraktu)." -f $definition.ModuleName)
    }

    $instance = [pscustomobject]@{
        PSTypeName    = 'MWP.ModuleInstance'
        Id            = $id
        ModuleId      = $definition.Id
        ModuleName    = $definition.ModuleName
        ModuleVersion = $definition.Version
        ManifestPath  = $definition.ManifestPath
        Name          = $(if ($PSBoundParameters.ContainsKey('Name')) { $Name } else { '{0} — {1}' -f $definition.Name, $context.ComputerName })
        Context       = $context
        State         = @{}
        Status        = 'Created'
        CreatedAt     = Get-Date
        InitializedAt = $null
        ClosedAt      = $null
    }
    $script:MwpInstanceRegistry[$id] = $instance
    Write-MwpLog -Level Debug -Source 'MWP.Remote' -Operation 'Instance.Create' -ComputerName $context.ComputerName `
        -Message ("Utworzono instancję '{0}' modułu {1}." -f $instance.Name, $definition.ModuleName) -Data @{ InstanceId = $id }
    $instance
}
