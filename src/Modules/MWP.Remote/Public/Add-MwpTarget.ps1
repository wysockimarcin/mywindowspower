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
        Faktyczna nazwa komputera (NetBIOS/DNS) — identyfikator w aplikacji (D-054). Po połączeniu
        aplikacja sprawdza, że komputer zgłasza tę nazwę (NameMismatch). Adres IPv4 jako nazwa jest
        dopuszczalny (zgodność ze starszymi wpisami), ale wtedy nazwy nie da się zweryfikować.

    .PARAMETER Address
        Opcjonalny adres połączenia (IPv4 albo nazwa DNS), np. gdy nazwa nie rozwiązuje się w sieci.
        Pusty: połączenie po nazwie. Przy HTTPS (-UseSsl) adres jest pomijany (łączenie po nazwie,
        bo certyfikat jest wystawiony na nazwę). Mapowanie nazwa → adres jest tylko w ustawieniach
        aplikacji (bez pliku hosts i DNS).

    .PARAMETER Authentication
        Credential (domyślnie: poświadczenia podawane przy połączeniu) albo CurrentUser (konto,
        na którym działa aplikacja; zwykle w domenie).

    .PARAMETER UseSsl
        Połączenie WinRM przez HTTPS (domyślnie port 5986 zamiast 5985).

    .EXAMPLE
        Add-MwpTarget -Name 'PC-BIURO' -DisplayName 'Komputer w biurze' -UserName 'PC-BIURO\admin' -WhatIf

    .EXAMPLE
        Add-MwpTarget -Name 'PC-BIURO' -Address '192.0.2.10' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [AllowEmptyString()]
        [string] $Address = '',

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
    if ($Address -eq $Name) {
        $Address = ''
    }
    if ($Address -ne '' -and -not (Test-MwpTargetName -Name $Address)) {
        return New-MwpResult @common -Success $false -Message ("Niepoprawny adres połączenia '{0}' (dozwolone: adres IPv4 albo nazwa DNS)." -f $Address)
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
    if ($Address -ne '') {
        $entry.Insert(1, 'address', $Address)
    }

    # D-054: ostrzeżenia bez blokady — ten komputer jako zdalny, adres pomijany przy HTTPS.
    $notes = New-Object -TypeName System.Collections.Generic.List[string]
    $self = Test-MwpTargetIsLocalComputer -Name $Name -Address $Address
    if ($self.IsLocalComputer) {
        $notes.Add($self.Message)
    }
    if ($Address -ne '' -and $UseSsl) {
        $notes.Add(("Przy HTTPS połączenie idzie po nazwie '{0}' (certyfikat), adres '{1}' jest pomijany." -f $Name, $Address))
    }
    $noteText = if ($notes.Count -gt 0) { ' Uwaga: {0}' -f ($notes -join ' ') } else { '' }

    $via = if ($Address -ne '') { ', adres {0}' -f $Address } else { '' }
    $target = Format-MwpOperationTarget -Target ("rejestr komputerów docelowych (dodanie '{0}'{1}, WinRM port {2})" -f $Name, $via, $Port) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Dodanie komputera docelowego')) {
        return New-MwpResult @common -Success $true -IsPreview -After $entry -Message ("Podgląd: komputer '{0}' zostanie dodany do rejestru.{1}" -f $Name, $noteText)
    }

    $change = Set-MwpSetting -Name 'targets' -Value (@($entries) + $entry) -WhatIf:$false -Confirm:$false
    if (-not $change.Success) {
        return New-MwpResult @common -Success $false -Message ("Nie udało się dodać komputera '{0}': {1}" -f $Name, $change.Message) -ErrorMessage $change.ErrorMessage
    }
    $message = "Dodano komputer '{0}' do rejestru komputerów docelowych.{1}" -f $Name, $noteText
    Write-MwpLog -Level Info -Source 'MWP.Remote' -Operation $operation -ComputerName 'localhost' -Message $message -Data $entry
    New-MwpResult @common -Success $true -Changed $true -After $entry -UndoId $change.UndoId -Message $message
}
