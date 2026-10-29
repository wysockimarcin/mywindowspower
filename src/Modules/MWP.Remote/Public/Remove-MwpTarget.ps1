function Remove-MwpTarget {
    <#
    .SYNOPSIS
        Usuwa komputer zdalny z rejestru komputerów docelowych (config\settings.local.json).

    .DESCRIPTION
        Operacja klasy Zmiana na konfiguracji aplikacji: -WhatIf, -Confirm, log i wpis cofnięcia
        (przez Set-MwpSetting). localhost nie może zostać usunięty. Istniejące konteksty i instancje
        dla tego komputera działają dalej (mają własne dane); nowych nie da się utworzyć.
        Usuwa także zapisane hasło komputera (Menedżer poświadczeń Windows i pamięć procesu, D-052);
        cofnięcie przywraca wpis rejestru komputerów, ale nie hasło.

    .EXAMPLE
        Remove-MwpTarget -Name 'PC-BIURO' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $operation = 'Remote.RemoveTarget'
    $common = @{ Operation = $operation; Target = $Name; ComputerName = 'localhost' }

    if (Test-MwpLocalTargetName -Name $Name) {
        return New-MwpResult @common -Success $false -Message 'Komputera lokalnego (localhost) nie można usunąć z rejestru.'
    }
    $entries = @(Get-MwpTargetEntry)
    $existing = @($entries | Where-Object { [string]$_['name'] -eq $Name }) | Select-Object -First 1
    if ($null -eq $existing) {
        return New-MwpResult @common -Success $false -Message ("Komputera '{0}' nie ma w rejestrze komputerów docelowych." -f $Name)
    }

    $target = Format-MwpOperationTarget -Target ("rejestr komputerów docelowych (usunięcie '{0}')" -f $Name) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Usunięcie komputera docelowego')) {
        return New-MwpResult @common -Success $true -IsPreview -Before $existing -Message ("Podgląd: komputer '{0}' zostanie usunięty z rejestru; zapisane hasło (jeśli jest) zostanie usunięte z Menedżera poświadczeń Windows." -f $Name)
    }

    $remaining = @($entries | Where-Object { [string]$_['name'] -ne $Name })
    $change = Set-MwpSetting -Name 'targets' -Value $remaining -WhatIf:$false -Confirm:$false
    if (-not $change.Success) {
        return New-MwpResult @common -Success $false -Message ("Nie udało się usunąć komputera '{0}': {1}" -f $Name, $change.Message) -ErrorMessage $change.ErrorMessage
    }
    $message = "Usunięto komputer '{0}' z rejestru komputerów docelowych." -f $Name
    # D-052: zapisane hasło usuniętego komputera nie zostaje w Menedżerze poświadczeń ani w pamięci.
    $forget = Remove-MwpTargetCredential -Name $Name -Confirm:$false -WhatIf:$false
    if (-not $forget.Success) {
        $message = '{0} Uwaga: {1}' -f $message, $forget.Message
    }
    elseif ($forget.Data['RemovedFromStore']) {
        $message = '{0} Usunięto też zapisane hasło z Menedżera poświadczeń Windows.' -f $message
    }
    Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $message
    New-MwpResult @common -Success $true -Changed $true -Before $existing -UndoId $change.UndoId -Message $message
}
