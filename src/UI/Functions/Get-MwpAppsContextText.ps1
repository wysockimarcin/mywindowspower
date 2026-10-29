function Get-MwpAppsContextText {
    <#
    .SYNOPSIS
        Tekst widoku Aplikacje: jak uruchamiany jest winget na komputerze instancji (D-051).

    .DESCRIPTION
        Czysta funkcja (bez WPF). localhost — bezpośrednio na koncie aplikacji; komputer zdalny —
        jednorazowe zadania harmonogramu jako SYSTEM (wymaga administratora w połączeniu). Profile
        użytkowników z ostatniej listy (MWP.WingetList.Runs) — w ich sesjach, z powodem, gdy się nie
        udało (np. użytkownik niezalogowany).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [bool] $Remote = $false,

        [AllowNull()]
        [object] $Packages = $null
    )

    $text = if ($Remote) {
        'winget: jednorazowe zadania harmonogramu na komputerze docelowym — programy komputera jako SYSTEM, programy wybranego profilu w sesji zalogowanego użytkownika (wymaga administratora w połączeniu).'
    }
    else {
        'winget: bezpośrednio na koncie aplikacji; programy innego wybranego profilu — zadanie w sesji zalogowanego użytkownika (wymaga uruchomienia jako administrator).'
    }
    if ($null -ne $Packages) {
        foreach ($run in @($Packages.Runs | Where-Object { $_.RunAs -eq 'User' })) {
            $name = if ($run.UserName) { $run.UserName } else { $run.UserSid }
            $text += if ($run.Success) { ' Profil {0}: odczytany w jego sesji.' -f $name } else { ' Profil {0}: {1}' -f $name, $run.Message }
        }
    }
    $text
}
