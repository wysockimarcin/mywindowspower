function Save-MwpTargetCredential {
    <#
    .SYNOPSIS
        Zapamiętuje konto i hasło komputera zdalnego w Menedżerze poświadczeń Windows (wpis MWP:<komputer>).

    .DESCRIPTION
        Zapis tylko na jawne żądanie użytkownika (D-052): w oknie poświadczeń pole „Zapamiętaj” jest
        domyślnie wyłączone, a Connect-MwpTarget -SaveCredential zapisuje dopiero po udanym połączeniu.
        Jedno poświadczenie na komputer; istniejący wpis jest zastępowany. Wpis typu generic, trwałość
        lokalna (bez roamingu). Klasa Zmiana na komputerze lokalnym: -WhatIf, -Confirm, log z nazwą
        wpisu i kontem — bez hasła. Bez wpisu cofnięcia (rejestr cofnięć nie przechowuje sekretów);
        cofnięcie to Remove-MwpTargetCredential. Wymaga komputera w rejestrze i włączonego ustawienia
        remoteCredentialStore. Każdy program działający na tym samym koncie Windows może odczytać
        zapisane hasło (ten sam model co zapisane hasła RDP).

    .EXAMPLE
        Save-MwpTargetCredential -Name 'PC-BIURO' -Credential (Get-Credential) -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    $operation = 'Remote.SaveCredential'
    $common = @{ Operation = $operation; Target = $Name; ComputerName = 'localhost' }

    if (Test-MwpLocalTargetName -Name $Name) {
        return New-MwpResult @common -Success $false -Message 'Komputer lokalny (localhost) nie potrzebuje zapisanego hasła.'
    }
    if ($null -eq (@(Get-MwpTargetEntry | Where-Object { [string]$_['name'] -eq $Name }) | Select-Object -First 1)) {
        return New-MwpResult @common -Success $false -Message ("Komputera '{0}' nie ma w rejestrze komputerów docelowych." -f $Name)
    }
    if (-not (Test-MwpCredentialStoreEnabled)) {
        return New-MwpResult @common -Success $false -Message 'Zapamiętywanie haseł jest wyłączone w Ustawieniach (remoteCredentialStore = false).'
    }
    if ([string]::IsNullOrWhiteSpace($Credential.UserName) -or $Credential.Password.Length -eq 0) {
        return New-MwpResult @common -Success $false -Message 'Nie zapisano hasła: podaj konto i hasło.'
    }

    $entry = Get-MwpStoredCredentialName -ComputerName $Name
    $data = [ordered]@{ Entry = $entry; UserName = $Credential.UserName }
    $target = Format-MwpOperationTarget -Target ("Menedżer poświadczeń Windows (wpis '{0}', konto '{1}')" -f $entry, $Credential.UserName) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Zapamiętanie hasła komputera zdalnego')) {
        return New-MwpResult @common -Success $true -IsPreview -Data $data `
            -Message ("Podgląd: hasło konta '{0}' dla komputera '{1}' zostanie zapisane w Menedżerze poświadczeń Windows (wpis '{2}')." -f $Credential.UserName, $Name, $entry)
    }

    $write = Set-MwpStoredCredential -ComputerName $Name -Credential $Credential
    if (-not $write.Success) {
        Write-MwpLog -Level Warning -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $write.Message -Data $data
        return New-MwpResult @common -Success $false -Message $write.Message -Data $data
    }
    $message = "Zapisano hasło konta '{0}' dla komputera '{1}' w Menedżerze poświadczeń Windows (wpis '{2}')." -f $Credential.UserName, $Name, $entry
    Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $message -Data $data
    New-MwpResult @common -Success $true -Changed $true -Message $message -Data $data
}
