function Get-MwpTargetStatus {
    <#
    .SYNOPSIS
        Stan komputerów z rejestru: dostępność portu WinRM z tego komputera i stan hasła w pamięci aplikacji (widget „Komputery”).

    .DESCRIPTION
        Funkcja danych widgetu „Komputery” (D-053). Operacja klasy Odczyt na komputerze lokalnym (widget
        ma LocalOnly): rejestr komputerów (Get-MwpTarget) i stan hasła w pamięci procesu
        (Get-MwpTargetCredentialInfo -SkipStore — bez odczytu Menedżera poświadczeń w wątku okna),
        a w bloku w tle próba połączenia TCP z portem WinRM każdego komputera zdalnego (limit 1 s na
        komputer, bez logowania i bez poświadczeń — konto nie może zostać zablokowane). Z -AsOperation
        zwraca uchwyt Start-MwpOperation; bez niego — MWP.Result z danymi (Resolve-MwpTargetStatus).

    .PARAMETER Context
        Kontekst wykonania; musi wskazywać komputer lokalny (próby połączenia wychodzą z komputera aplikacji).

    .PARAMETER NoProbe
        Bez prób połączenia (tylko rejestr i stan hasła).

    .PARAMETER WidgetParameters
        Parametry widgetu: Probe (bool, domyślnie $true).

    .EXAMPLE
        (Get-MwpTargetStatus).Data.Targets | Format-Table Name, Reachable, LatencyMs, CredentialText
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [switch] $NoProbe,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Remote.TargetStatus'
    $common = @{ Operation = $operation; Target = 'rejestr komputerów'; ComputerName = $Context.ComputerName }
    if ($Context.Mode -ne 'Local') {
        $message = "Stan komputerów jest sprawdzany z komputera lokalnego (nie z '{0}')." -f $Context.ComputerName
        if ($AsOperation) {
            throw $message
        }
        return New-MwpResult @common -Success $false -Message $message
    }
    if (-not $NoProbe -and $null -ne $WidgetParameters -and $WidgetParameters.Contains('Probe') -and $null -ne $WidgetParameters['Probe'] -and -not [bool]$WidgetParameters['Probe']) {
        $NoProbe = [switch]$true
    }
    $targets = @(Get-MwpTarget | Where-Object { -not $_.IsLocal })
    $credentials = @{}
    if ($targets.Count -gt 0) {
        foreach ($info in @(Get-MwpTargetCredentialInfo -Name @($targets | ForEach-Object { $_.Name }) -SkipStore)) {
            $credentials[[string]$info.ComputerName] = $info
        }
    }
    $request = ConvertTo-Json -Compress -Depth 4 -InputObject ([pscustomobject]@{
            Probe   = -not $NoProbe
            Targets = @($targets | ForEach-Object {
                    $info = $credentials[[string]$_.Name]
                    [pscustomobject]@{
                        Name        = [string]$_.Name
                        Address     = [string]$_.ConnectionAddress
                        DisplayName = [string]$_.DisplayName
                        Port        = [int]$_.Port
                        Credential  = $(if ($null -eq $info) { 'None' } elseif ($info.Invalid) { 'Invalid' } elseif ($info.Cached) { 'Verified' } else { 'None' })
                    }
                })
        })
    $block = Get-MwpTargetStatusScript
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    if (-not $result.Success) {
        return New-MwpResult @common -Success $false -Message $result.Message -ErrorMessage $result.ErrorMessage
    }
    $status = Resolve-MwpTargetStatus -Data $result
    New-MwpResult @common -Success $true -Message ('Komputery zdalne: {0}.' -f @($status.Targets).Count) -Data $status
}
