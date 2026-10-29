function Get-MwpAppsTargetOption {
    <#
    .SYNOPSIS
        Pozycje list profili widoku Aplikacje: profil do odczytu programów (Profile) i miejsce instalacji (Install) — D-051.

    .DESCRIPTION
        Czysta funkcja (bez WPF). Profile pochodzą z inwentarza (załadowane profile HKEY_USERS).
        Profile: komputer zdalny — wszystkie profile (konto połączenia oznaczone), localhost — profile
        innych użytkowników (konto aplikacji jest zawsze na liście). Install: pierwsza pozycja to
        domyślny kontekst (komputer zdalny — SYSTEM, dla wszystkich użytkowników; localhost — konto
        aplikacji), dalej profile, w których sesji można zainstalować pakiet (użytkownik musi być
        zalogowany). Value = SID albo '' (kontekst domyślny).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Profile', 'Install')]
        [string] $Kind,

        [AllowNull()]
        [object] $Inventory,

        [bool] $Remote = $false
    )

    $first = switch ($Kind) {
        'Profile' { if ($Remote) { '(bez programów użytkowników)' } else { '(tylko konto aplikacji)' } }
        'Install' { if ($Remote) { 'Komputer — wszyscy użytkownicy (SYSTEM)' } else { 'Konto aplikacji' } }
    }
    [pscustomobject]@{ PSTypeName = 'MWP.UiOption'; Label = $first; Value = '' }
    if ($null -eq $Inventory) {
        return
    }
    foreach ($userProfile in @($Inventory.Profiles | Where-Object { $null -ne $_ })) {
        if (-not $Remote -and $userProfile.IsCurrent) {
            continue
        }
        $label = if ($Kind -eq 'Install') { 'Użytkownik {0} (w jego sesji)' -f $userProfile.Name } elseif ($userProfile.IsCurrent) { '{0} (konto połączenia)' -f $userProfile.Name } else { [string]$userProfile.Name }
        [pscustomobject]@{ PSTypeName = 'MWP.UiOption'; Label = $label; Value = [string]$userProfile.Sid }
    }
}
