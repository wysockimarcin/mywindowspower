function Reset-MwpNetworkStack {
    <#
    .SYNOPSIS
        Resetuje katalog Winsock (netsh winsock reset) albo stos TCP/IP (netsh int ip reset) na komputerze docelowym; wymaga ponownego uruchomienia.

    .DESCRIPTION
        Operacja klasy Destrukcyjna (D-027, D-049): ConfirmImpact High — bez -Confirm:$false funkcja
        zawsze pyta; nie da się jej cofnąć (bez wpisu cofnięcia). Wymaga administratora na komputerze
        docelowym (sprawdzane przed podglądem). Zmiana działa po ponownym uruchomieniu komputera
        (RestartRequired) — aplikacja go nie wykonuje. Reset stosu IP przywraca ustawienia TCP/IP do
        domyślnych, także statyczne adresy IP: podgląd wymienia adaptery z adresem statycznym i ostrzega,
        że komputer zdalny może po restarcie stracić łączność. Argumenty netsh są stałe (D-015).

    .PARAMETER Component
        Winsock albo IP.

    .EXAMPLE
        Reset-MwpNetworkStack -Component Winsock -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Winsock', 'IP')]
        [string] $Component,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Network.Reset' + $Component
    $computerName = $Context.ComputerName
    $label = if ($Component -eq 'Winsock') { 'katalog Winsock (netsh winsock reset)' } else { 'stos TCP/IP (netsh int ip reset)' }
    $common = @{ Operation = $operation; Target = $label; ComputerName = $computerName }
    $read = Get-MwpNetworkStatus -Context $Context
    if (-not $read.Success) {
        return New-MwpResult @common -Success $false -Message $read.Message -ErrorMessage $read.ErrorMessage
    }
    $admin = Test-MwpNetworkAdmin -Context $Context
    if (-not $admin.Success) {
        return New-MwpResult @common -Success $false -Message $admin.Result.Message -ErrorMessage $admin.Result.ErrorMessage
    }
    if (-not $admin.IsAdministrator) {
        return New-MwpResult @common -Success $false -Message ("Reset ustawień sieci wymaga uprawnień administratora na komputerze '{0}'." -f $computerName)
    }
    $notes = @('Nie można cofnąć. Zmiana działa po ponownym uruchomieniu komputera (aplikacja go nie wykonuje).')
    if ($Component -eq 'IP') {
        $static = @($read.Data.Adapters | Where-Object { -not $_.DhcpEnabled -and -not $_.Virtual -and $_.IPv4.Count -gt 0 })
        if ($static.Count -gt 0) {
            $notes += ('Adaptery z adresem statycznym stracą go po restarcie: {0}.' -f (@($static | ForEach-Object { '{0} ({1})' -f $_.Name, $_.IPv4Text }) -join '; '))
        }
        $notes += 'Statyczne DNS i inne ustawienia TCP/IP wrócą do domyślnych.'
    }
    else {
        $notes += 'Usunięte zostaną dodatki Winsock (LSP) instalowane przez programy; niektóre programy (VPN, zabezpieczenia) mogą wymagać ponownej instalacji.'
    }
    if ($Context.Mode -eq 'Remote') {
        $notes += 'Komputer zdalny może po restarcie stracić łączność z aplikacją.'
    }
    $action = 'Reset: {0}. {1}' -f $label, ($notes -join ' ')
    $target = Format-MwpOperationTarget -Target $label -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -RestartRequired -Message ('Podgląd: {0}' -f $action)
    }
    Write-MwpLog -Level Info -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message ('Reset: {0} — start.' -f $label)
    $result = Invoke-MwpOnTarget -Context $Context -Operation $operation -ScriptBlock (Get-MwpNetworkScript -Name ResetStack) -ArgumentList @($Component, (Get-MwpNetworkTargetConfig).NetshPath) -TimeoutSeconds 120
    $raw = if ($result.Success) { ConvertFrom-MwpNetworkJson -Data $result -Kind 'MWP.NetworkResetRaw' } else { $null }
    $lines = if ($null -ne $raw) { @($raw.Lines | Where-Object { $_ } | ForEach-Object { [string]$_ }) } else { @() }
    $failure = if ($null -eq $raw) { $result.Message } elseif ($raw.Error) { [string]$raw.Error } elseif ([int]$raw.ExitCode -ne 0) { 'kod wyjścia netsh {0}: {1}' -f $raw.ExitCode, ($lines -join ' ') } else { $null }
    if ($failure) {
        $message = "Reset ({0}) na komputerze '{1}' nie powiódł się: {2}" -f $label, $computerName, $failure
        Write-MwpLog -Level Error -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $failure -Data $lines
    }
    $message = "Wykonano reset ({0}) na komputerze '{1}'. Uruchom komputer ponownie, aby zakończyć." -f $label, $computerName
    Write-MwpLog -Level Warning -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Output = ($lines -join [Environment]::NewLine) }
    New-MwpResult @common -Success $true -Changed $true -RestartRequired -Message $message -Data $lines
}
