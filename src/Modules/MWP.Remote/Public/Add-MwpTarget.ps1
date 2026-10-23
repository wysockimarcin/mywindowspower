function Add-MwpTarget {
    <#
    .SYNOPSIS
        Dodaje komputer zdalny do rejestru komputerów docelowych (config\settings.local.json).

    .DESCRIPTION
        Operacja klasy Zmiana na konfiguracji aplikacji (komputer lokalny): -WhatIf, -Confirm, log
        i wpis cofnięcia (przez Set-MwpSetting). Nazwa komputera trafia tylko do pliku lokalnego,
        nigdy do repozytorium. Hasło nie jest zapisywane (D-034): przy połączeniu podaje się je
        w Get-Credential; UserName jest tylko podpowiedzią. Funkcja nie zmienia konfiguracji WinRM
        ani TrustedHosts.

    .PARAMETER Name
        Nazwa komputera (NetBIOS/DNS) albo adres IPv4.

    .PARAMETER Authentication
        Credential (domyślnie: poświadczenia podawane przy połączeniu) albo CurrentUser (konto,
        na którym działa aplikacja; zwykle w domenie).

    .PARAMETER UseSsl
        Połączenie WinRM przez HTTPS (domyślnie port 5986 zamiast 5985).

    .EXAMPLE
        Add-MwpTarget -Name 'PC-BIURO' -DisplayName 'Komputer w biurze' -UserName 'PC-BIURO\admin' -WhatIf
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
        [string] $Authentication = 'Credential',

        [AllowEmptyString()]
        [ValidatePattern('^[^:;"/\[\]|=+*?<>]*$')]
        [string] $UserName = '',

        [ValidateRange(1, 65535)]
        [int] $Port,

        [switch] $UseSsl
    )

    $operation = 'Remote.AddTarget'
    $common = @{ Operation = $operation; Target = $Name; ComputerName = 'localhost' }

    if (-not (Test-MwpTargetName -Name $Name)) {
        return New-MwpResult @common -Success $false -Message ("Niepoprawna nazwa komputera '{0}' (dozwolone: nazwa NetBIOS/DNS albo adres IPv4)." -f $Name)
    }
    if (Test-MwpLocalTargetName -Name $Name) {
        return New-MwpResult @common -Success $false -Message ("Komputer lokalny jest zawsze dostępny jako 'localhost'; nie dodaje się go do rejestru.")
    }
    $entries = @(Get-MwpTargetEntry)
    if (@($entries | Where-Object { [string]$_['name'] -eq $Name }).Count -gt 0) {
        return New-MwpResult @common -Success $false -Message ("Komputer '{0}' jest już w rejestrze komputerów docelowych." -f $Name)
    }

    if (-not $PSBoundParameters.ContainsKey('Port')) {
        $Port = if ($UseSsl) { 5986 } else { 5985 }
    }
    $entry = [ordered]@{
        name           = $Name
        displayName    = $(if ($PSBoundParameters.ContainsKey('DisplayName')) { $DisplayName } else { $Name })
        transport      = 'WinRM'
        port           = $Port
        useSsl         = [bool]$UseSsl
        authentication = $Authentication
        userName       = $UserName
    }

    $target = Format-MwpOperationTarget -Target ("rejestr komputerów docelowych (dodanie '{0}', WinRM port {1})" -f $Name, $Port) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Dodanie komputera docelowego')) {
        return New-MwpResult @common -Success $true -IsPreview -After $entry -Message ("Podgląd: komputer '{0}' zostanie dodany do rejestru." -f $Name)
    }

    $change = Set-MwpSetting -Name 'targets' -Value (@($entries) + $entry) -WhatIf:$false -Confirm:$false
    if (-not $change.Success) {
        return New-MwpResult @common -Success $false -Message ("Nie udało się dodać komputera '{0}': {1}" -f $Name, $change.Message) -ErrorMessage $change.ErrorMessage
    }
    $message = "Dodano komputer '{0}' do rejestru komputerów docelowych." -f $Name
    Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $message -Data $entry
    New-MwpResult @common -Success $true -Changed $true -After $entry -UndoId $change.UndoId -Message $message
}
