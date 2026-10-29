function Test-MwpCredentialStoreEnabled {
    <#
    .SYNOPSIS
        Czy wolno zapamiętywać i czytać hasła w Menedżerze poświadczeń Windows (ustawienie remoteCredentialStore).

    .DESCRIPTION
        Przełącznik globalny D-052, domyślnie włączony (szablon ustawień). Wyłączony: aplikacja nie
        czyta i nie zapisuje magazynu; usuwanie wpisów („Zapomnij hasło”, Remove-MwpTarget) działa dalej.
        Brak klucza albo błąd odczytu ustawień = wartość domyślna ($true).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $value = Get-MwpSetting -Name 'remoteCredentialStore' -WarningAction SilentlyContinue
    }
    catch {
        Write-Verbose ('Brak ustawienia remoteCredentialStore: {0}' -f $_.Exception.Message)
        return $true
    }
    -not ($value -is [bool] -and -not $value)
}
