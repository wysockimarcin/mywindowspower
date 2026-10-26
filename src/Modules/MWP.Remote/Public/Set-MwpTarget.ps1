function Set-MwpTarget {
    <#
    .SYNOPSIS
        Zmienia dane komputera zdalnego w rejestrze komputerów docelowych (config\settings.local.json).

    .DESCRIPTION
        Operacja klasy Zmiana na konfiguracji aplikacji (komputer lokalny): -WhatIf, -Confirm, log
        i wpis cofnięcia (przez Set-MwpSetting). Zmienia tylko podane pola: nazwę wyświetlaną,
        sposób uwierzytelnienia, podpowiedź konta, port i HTTPS. Nazwy komputera się nie zmienia
        (inny komputer = Remove-MwpTarget i Add-MwpTarget). Hasło nie jest zapisywane (D-034).
        Otwarte instancje mają własne, niezmienne konteksty: zmiana obowiązuje dla nowych instancji.
        Funkcja nie zmienia konfiguracji WinRM ani TrustedHosts.

    .PARAMETER Name
        Nazwa komputera w rejestrze.

    .EXAMPLE
        Set-MwpTarget -Name 'PC-BIURO' -UserName 'PC-BIURO\admin2' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateNotNullOrEmpty()]
        [string] $DisplayName,

        [ValidateSet('Credential', 'CurrentUser')]
        [string] $Authentication,

        [AllowEmptyString()]
        [ValidatePattern('^[^:;"/\[\]|=+*?<>]*$')]
        [string] $UserName,

        [ValidateRange(1, 65535)]
        [int] $Port,

        [bool] $UseSsl
    )

    $operation = 'Remote.SetTarget'
    $common = @{ Operation = $operation; Target = $Name; ComputerName = 'localhost' }

    $entries = @(Get-MwpTargetEntry)
    $existing = @($entries | Where-Object { [string]$_['name'] -eq $Name }) | Select-Object -First 1
    if ($null -eq $existing) {
        return New-MwpResult @common -Success $false -Message ("Komputera '{0}' nie ma w rejestrze komputerów docelowych." -f $Name)
    }

    $before = [ordered]@{}
    foreach ($key in $existing.Keys) {
        $before[$key] = $existing[$key]
    }
    $after = [ordered]@{}
    foreach ($key in $before.Keys) {
        $after[$key] = $before[$key]
    }
    $map = [ordered]@{ DisplayName = 'displayName'; Authentication = 'authentication'; UserName = 'userName'; Port = 'port'; UseSsl = 'useSsl' }
    foreach ($parameter in $map.Keys) {
        if ($PSBoundParameters.ContainsKey($parameter)) {
            $after[$map[$parameter]] = $PSBoundParameters[$parameter]
        }
    }
    # Zmiana HTTPS bez jawnego portu przestawia port domyślny (5985/5986).
    if ($PSBoundParameters.ContainsKey('UseSsl') -and -not $PSBoundParameters.ContainsKey('Port') -and [int]$before['port'] -in @(5985, 5986)) {
        $after['port'] = $(if ($UseSsl) { 5986 } else { 5985 })
    }

    $changes = @(foreach ($key in $after.Keys) {
            if ([string]$before[$key] -ne [string]$after[$key]) {
                "{0}: '{1}' -> '{2}'" -f $key, $before[$key], $after[$key]
            }
        })
    if ($changes.Count -eq 0) {
        return New-MwpResult @common -Success $true -Before $before -After $after -Message ("Komputer '{0}': bez zmian." -f $Name)
    }

    $target = Format-MwpOperationTarget -Target ("rejestr komputerów docelowych (zmiana '{0}': {1})" -f $Name, ($changes -join ', ')) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Zmiana komputera docelowego')) {
        return New-MwpResult @common -Success $true -IsPreview -Before $before -After $after `
            -Message ("Podgląd: komputer '{0}' — {1}." -f $Name, ($changes -join ', '))
    }

    $updated = @(foreach ($entry in $entries) {
            if ([string]$entry['name'] -eq $Name) { $after } else { $entry }
        })
    $change = Set-MwpSetting -Name 'targets' -Value $updated -WhatIf:$false -Confirm:$false
    if (-not $change.Success) {
        return New-MwpResult @common -Success $false -Before $before -Message ("Nie udało się zmienić komputera '{0}': {1}" -f $Name, $change.Message) -ErrorMessage $change.ErrorMessage
    }
    $message = "Zmieniono komputer '{0}' w rejestrze komputerów docelowych ({1})." -f $Name, ($changes -join ', ')
    Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $message -Data $after
    New-MwpResult @common -Success $true -Changed $true -Before $before -After $after -UndoId $change.UndoId -Message $message
}
