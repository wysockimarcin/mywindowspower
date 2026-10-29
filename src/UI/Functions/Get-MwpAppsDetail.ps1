function Get-MwpAppsDetail {
    <#
    .SYNOPSIS
        Tytuł i opis zaznaczonej aplikacji dla panelu szczegółów widoku Aplikacje.

    .DESCRIPTION
        Czysta funkcja (bez WPF): wersja i aktualizacja, wydawca, źródło i zakres, identyfikatory winget,
        lokalizacja, sposób odinstalowania, ochrona z powodem i ostrzeżenie.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $App
    )

    if ($null -eq $App) {
        return [pscustomobject]@{ Title = 'Wybierz aplikację z listy.'; Text = '' }
    }
    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    $lines.Add(('Wersja: {0}{1}' -f $(if ($App.Version) { $App.Version } else { 'nieznana' }), $(if ($App.Available) { ' · dostępna aktualizacja: {0}' -f $App.Available } else { '' })))
    if ($App.Publisher) { $lines.Add(('Wydawca: {0}' -f $App.Publisher)) }
    $lines.Add(('Źródło: {0} · {1}{2}' -f $App.SourceText, $App.ScopeText, $(if ($App.Architecture) { ' · ' + $App.Architecture } else { '' })))
    if ($null -ne $App.InstallDate) { $lines.Add(('Zainstalowano: {0}' -f ([datetime]$App.InstallDate).ToString('yyyy-MM-dd'))) }
    if ($App.SizeText) { $lines.Add(('Rozmiar (wg instalatora): {0}' -f $App.SizeText)) }
    if ($App.WingetId) { $lines.Add(('winget: {0}' -f $App.WingetId)) }
    if ($App.WingetLocalId) { $lines.Add(('Identyfikator lokalny winget: {0}' -f $App.WingetLocalId)) }
    if ($App.PackageFullName) { $lines.Add(('Pakiet: {0}' -f $App.PackageFullName)) }
    if ($App.InstallLocation) { $lines.Add(('Lokalizacja: {0}' -f $App.InstallLocation)) }
    $method = if ($App.UninstallMethod -eq 'Appx') { 'Remove-AppxPackage (konto sesji)' } elseif ($App.Scope -eq 'User' -and $App.UserName) { 'winget uninstall (identyfikator lokalny) w sesji użytkownika {0}' -f $App.UserName } else { 'winget uninstall (identyfikator lokalny)' }
    $lines.Add(('Odinstalowanie: {0}{1}' -f $method, $(if ($App.WingetId) { ' · cofnięcie przez ponowną instalację z winget' } else { ' · bez cofnięcia' })))
    if ($App.IsProtected) { $lines.Add(('Chroniona — nie można odinstalować z aplikacji: {0}' -f $App.ProtectedReason)) }
    if ($App.Warning) { $lines.Add(('Uwaga: {0}' -f $App.Warning)) }
    [pscustomobject]@{
        Title = '{0}{1}' -f $App.Name, $(if ($App.IsProtected) { ' (chroniona)' } else { '' })
        Text  = $lines -join [Environment]::NewLine
    }
}
