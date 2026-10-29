function Remove-MwpTargetCredential {
    <#
    .SYNOPSIS
        „Zapomnij hasło”: usuwa hasło komputera z Menedżera poświadczeń Windows i z pamięci aplikacji.

    .DESCRIPTION
        Usuwa wpis MWP:<komputer> (D-052) i poświadczenie komputera z pamięci podręcznej procesu (także
        stan „odrzucone”), więc kolejne połączenie zapyta o hasło. Otwarte połączenia, które już mają
        sesję, działają dalej do rozłączenia. Działa także przy wyłączonym zapamiętywaniu haseł i dla
        nazw spoza rejestru (sprzątanie). Klasa Zmiana: -WhatIf, -Confirm, log bez hasła; bez wpisu
        cofnięcia (hasła nie ma czym odtworzyć).

    .EXAMPLE
        Remove-MwpTargetCredential -Name 'PC-BIURO'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $operation = 'Remote.RemoveCredential'
    $common = @{ Operation = $operation; Target = $Name; ComputerName = 'localhost' }
    if (Test-MwpLocalTargetName -Name $Name) {
        return New-MwpResult @common -Success $false -Message 'Komputer lokalny (localhost) nie ma zapisanego hasła.'
    }

    $entry = Get-MwpStoredCredentialName -ComputerName $Name
    $target = Format-MwpOperationTarget -Target ("Menedżer poświadczeń Windows (wpis '{0}') i pamięć aplikacji" -f $entry) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Usunięcie zapisanego hasła komputera zdalnego')) {
        return New-MwpResult @common -Success $true -IsPreview -Data ([ordered]@{ Entry = $entry }) `
            -Message ("Podgląd: zapisane hasło komputera '{0}' (wpis '{1}') zostanie usunięte z Menedżera poświadczeń Windows i z pamięci aplikacji." -f $Name, $entry)
    }

    $inMemory = Remove-MwpCachedCredential -ComputerName $Name
    $remove = Remove-MwpStoredCredential -ComputerName $Name
    $data = [ordered]@{ Entry = $entry; RemovedFromStore = $remove.Removed; RemovedFromMemory = $inMemory }
    if (-not $remove.Success) {
        Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $remove.Message -Data $data
        return New-MwpResult @common -Success $false -Changed $inMemory -Message $remove.Message -Data $data
    }
    $message = if ($remove.Removed) {
        "Zapomniano hasło komputera '{0}': usunięto wpis '{1}' z Menedżera poświadczeń Windows i z pamięci aplikacji." -f $Name, $entry
    }
    else {
        "Komputer '{0}' nie miał hasła w Menedżerze poświadczeń Windows; wyczyszczono pamięć aplikacji." -f $Name
    }
    Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $message -Data $data
    New-MwpResult @common -Success $true -Changed ($remove.Removed -or $inMemory) -Message $message -Data $data
}
