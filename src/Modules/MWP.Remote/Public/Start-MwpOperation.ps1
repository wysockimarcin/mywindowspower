function Start-MwpOperation {
    <#
    .SYNOPSIS
        Uruchamia blok skryptu na komputerze docelowym asynchronicznie, w puli runspace'ów z limitem równoległości.

    .DESCRIPTION
        Model wykonywania D-023 (dla GUI i Dashboardu): funkcja wraca od razu z uchwytem operacji
        (MWP.Operation); wynik daje Wait-MwpOperation, anulowanie — Stop-MwpOperation. Liczbę
        równoczesnych operacji ogranicza remoteMaxParallelOperations; pozostałe czekają w kolejce.
        Każda operacja ma limit czasu (-TimeoutSeconds albo Policy.OperationTimeoutSeconds
        kontekstu), po którym jest przerywana. Błąd jednej operacji (np. niedostępny komputer)
        nie wpływa na inne.
        Blok skryptu musi być samowystarczalny, jak w Invoke-MwpOnTarget. Zdalnie każda operacja
        otwiera własne, krótkotrwałe połączenie WinRM z poświadczeniami z połączenia kontekstu
        (sesja kontekstu należy do runspace'u, w którym powstała). Bez poświadczenia w kontekście
        używa sprawdzonego hasła komputera ze wspólnej pamięci procesu; gdy komputer je odrzucił
        (D-052), operacja kończy się od razu z ErrorKind = CredentialRequired, bez próby logowania.
        Operacja jest przypisana do instancji modułu (Context.InstanceId), więc
        Close-MwpModuleInstance ją anuluje.
        D-054: połączenie idzie pod adres połączenia (Context.Address), a blok na komputerze docelowym
        najpierw porównuje nazwę komputera ($env:COMPUTERNAME, nazwa hosta) z Context.ComputerName;
        przy niezgodności blok modułu się nie wykonuje, a operacja kończy się z ErrorKind = NameMismatch
        (blokada wszystkich operacji kontekstu, także widgetów). Gdy nazwa w rejestrze jest adresem IP,
        porównania nie ma.

    .EXAMPLE
        $operation = Start-MwpOperation -Context $remote -ScriptBlock { Get-HotFix } -Operation 'Update.GetHotFix'
        $result = Wait-MwpOperation -Operation $operation
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia wykonanie bloku; podgląd i potwierdzenie zmian systemu należą do funkcji obszaru, która go przekazuje.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock] $ScriptBlock,

        [AllowEmptyCollection()]
        [object[]] $ArgumentList = @(),

        [ValidateNotNullOrEmpty()]
        [string] $Operation = 'Remote.Operation',

        [ValidateRange(1, 86400)]
        [int] $TimeoutSeconds
    )

    if (-not $PSBoundParameters.ContainsKey('TimeoutSeconds')) {
        $TimeoutSeconds = $Context.Policy.OperationTimeoutSeconds
    }
    $connection = $Context.Connection
    # D-052: hasło kontekstu albo sprawdzone hasło komputera z pamięci procesu; po odrzuceniu — brak próby.
    $credential = Resolve-MwpConnectionCredential -Context $Context
    $shared = $null -ne $connection.PSObject.Properties['CredentialShared'] -and [bool]$connection.CredentialShared
    $handle = [pscustomobject]@{
        PSTypeName     = 'MWP.Operation'
        Id             = [guid]::NewGuid().ToString()
        Operation      = $Operation
        ComputerName   = $Context.ComputerName
        Address        = $Context.Address
        Port           = $Context.Port
        InstanceId     = $Context.InstanceId
        ContextId      = $Context.Id
        StartedAt      = Get-Date
        CompletedAt    = $null
        TimeoutSeconds = $TimeoutSeconds
        Status         = 'Running'
        Result         = $null
        PowerShell     = $null
        AsyncResult    = $null
        # Generacja poświadczenia ze wspólnej pamięci (-1: własne kontekstu); Wait-MwpOperation unieważnia ją po odmowie.
        CredentialGeneration = $(if ($shared) { [int]$connection.CredentialGeneration } else { -1 })
    }
    $common = @{ Operation = $Operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }

    if ($Context.Mode -eq 'Remote' -and $Context.Identity.Authentication -eq 'Credential' -and $null -eq $credential) {
        $cached = Get-MwpCachedCredential -ComputerName $Context.ComputerName
        $kind = if ($null -ne $cached -and $cached['State'] -eq 'Invalid') { 'CredentialRejected' } else { 'CredentialRequired' }
        $message = Get-MwpRemoteErrorMessage -Kind $kind -Context $Context
        $handle.Status = 'Failed'
        $handle.CompletedAt = Get-Date
        $handle.Result = New-MwpResult @common -Success $false -Message $message -Data ([ordered]@{ ErrorKind = 'CredentialRequired' })
        return $handle
    }

    # Kod wykonywany w runspace puli: tylko polecenia wbudowane, bez modułów MWP i bez stanu hosta.
    $worker = {
        param(
            [string] $Mode,
            [string] $ComputerName,
            [int] $Port,
            [bool] $UseSsl,
            [pscredential] $Credential,
            [string] $ScriptText,
            [object[]] $Arguments,
            [int] $OpenTimeoutSeconds,
            [int] $OperationTimeoutSeconds,
            [string] $ErrorPolicy,
            [string] $ExpectedName,
            [string] $GuardText
        )
        $ErrorActionPreference = $ErrorPolicy
        $code = [scriptblock]::Create($ScriptText)
        if ($Mode -eq 'Local') {
            & $code @Arguments
            return
        }
        # D-054: na komputerze docelowym najpierw sprawdzenie nazwy (Get-MwpNameGuardScript), potem blok modułu.
        $guard = [scriptblock]::Create($GuardText)
        $parameters = @{
            ComputerName  = $ComputerName
            Port          = $Port
            ScriptBlock   = $guard
            # Argumenty modułu na najwyższym poziomie listy (jak przed D-054) — ta sama głębokość serializacji.
            ArgumentList  = @(@($ExpectedName, $ScriptText) + @($Arguments))
            SessionOption = New-PSSessionOption -OpenTimeout ($OpenTimeoutSeconds * 1000) -OperationTimeout ($OperationTimeoutSeconds * 1000)
        }
        if ($UseSsl) {
            $parameters['UseSSL'] = $true
        }
        if ($null -ne $Credential) {
            $parameters['Credential'] = $Credential
        }
        Invoke-Command @parameters
    }

    $powerShell = [powershell]::Create()
    $powerShell.RunspacePool = Get-MwpOperationPool
    $null = $powerShell.AddScript($worker.ToString()).AddParameters(@{
            Mode                    = $Context.Mode
            ComputerName            = $Context.Address
            Port                    = $Context.Port
            UseSsl                  = $Context.UseSsl
            Credential              = $credential
            ScriptText              = $ScriptBlock.ToString()
            Arguments               = $ArgumentList
            OpenTimeoutSeconds      = $Context.Policy.ConnectTimeoutSeconds
            OperationTimeoutSeconds = $TimeoutSeconds
            ErrorPolicy             = $Context.Policy.ErrorPolicy
            ExpectedName            = $(if ($Context.Mode -eq 'Local') { '' } else { Get-MwpExpectedComputerName -Name $Context.ComputerName })
            GuardText               = (Get-MwpNameGuardScript).ToString()
        })
    $handle.PowerShell = $powerShell
    $script:MwpOperationRegistry[$handle.Id] = $handle
    $handle.AsyncResult = $powerShell.BeginInvoke()
    $handle
}
