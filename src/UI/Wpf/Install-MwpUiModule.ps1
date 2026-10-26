function Install-MwpUiModule {
    <#
    .SYNOPSIS
        Instalacja modułu z paczki .mwpmod: wybór pliku, sprawdzenie w tle, potwierdzenie (nazwa, wersja,
        uprawnienia, SHA-256), instalacja w tle.

    .DESCRIPTION
        D-031: logika w MWP.Core (Test-MwpModulePackage, Install-MwpModulePackage); widok tylko
        pokazuje dane i potwierdzenie. Integralność paczki potwierdza użytkownik, porównując sumę
        SHA-256 (paczki nie są podpisywane, D-015). Po instalacji moduł jest odkrywany od razu.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    $dialog = New-Object -TypeName Microsoft.Win32.OpenFileDialog
    $dialog.Title = 'Wybierz paczkę modułu'
    $dialog.Filter = 'Paczka modułu (*.mwpmod)|*.mwpmod|Wszystkie pliki (*.*)|*.*'
    $chosen = if ($null -ne $Owner) { $dialog.ShowDialog($Owner) } else { $dialog.ShowDialog() }
    if (-not $chosen) {
        return
    }
    $path = $dialog.FileName
    if (-not $PSCmdlet.ShouldProcess($path, 'Instalacja modułu z paczki')) {
        return
    }
    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name 'Sprawdzanie paczki' -ArgumentList @(, $path) -State @{ Owner = $Owner } -ScriptBlock {
        param($Progress, $Path)
        $Progress.Message = 'rozpakowanie i walidacja'
        Test-MwpModulePackage -Path $Path
    } -OnCompleted {
        param($Task)
        $ui = $script:MwpUi
        $owner = $Task.State.Owner
        $package = @($Task.Output | Where-Object { $_.PSObject.TypeNames -contains 'MWP.ModulePackage' }) | Select-Object -Last 1
        if ($null -eq $package) {
            Show-MwpMessage -Text ('Nie udało się sprawdzić paczki: {0}' -f $Task.Error) -Kind Error -Owner $owner
            return
        }
        if (-not $package.IsValid) {
            Show-MwpMessage -Text ("Paczka '{0}' została odrzucona:{1}{2}" -f [IO.Path]::GetFileName($package.PackagePath), [Environment]::NewLine, (@($package.Errors) -join [Environment]::NewLine)) -Kind Warning -Owner $owner
            return
        }
        $dependencies = @($package.Dependencies | ForEach-Object { '{0} ≥ {1}' -f $_.Id, $_.MinimumVersion })
        $lines = @(
            'Nazwa: {0}' -f $package.Name
            'Folder i Id: {0} (Id {1})' -f $package.ModuleName, $package.Id
            'Wersja: {0}' -f $package.Version
            'Wymagane uprawnienia: {0}' -f (@($package.RequiredPermissions) -join ', ')
            'Zależności: {0}' -f $(if ($dependencies.Count -gt 0) { $dependencies -join ', ' } else { '(brak)' })
            'Opis: {0}' -f $package.Description
            'SHA-256 paczki: {0}' -f $package.Sha256
            'Plik: {0}' -f $package.PackagePath
            'Miejsce instalacji: {0}' -f (Get-MwpDataLocation).Modules
        )
        $confirmed = Show-MwpConfirmDialog -Header 'Instalacja modułu z paczki' -Target ("Moduł '{0}' wersja {1}" -f $package.Name, $package.Version) `
            -PreviewLine $lines -Class Change -ConfirmText 'Zainstaluj' -Owner $owner `
            -Warning 'Paczki nie są podpisane cyfrowo. Zainstaluj tylko własny moduł i porównaj sumę SHA-256 z sumą paczki, którą utworzyłeś.'
        if (-not $confirmed) {
            return
        }
        $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Instalacja: {0}' -f $package.ModuleName) -ArgumentList @(, $package.PackagePath) -State @{ Owner = $owner } -ScriptBlock {
            param($Progress, $Path)
            $Progress.Message = 'instalacja'
            Install-MwpModulePackage -Path $Path -Confirm:$false
        } -OnCompleted {
            param($Task)
            $result = @($Task.Output | Where-Object { $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
            $text = if ($null -eq $result) { 'Instalacja nie powiodła się: {0}' -f $Task.Error } else { $result.Message }
            Update-MwpModuleCatalog
            Show-MwpMessage -Text $text -Kind $(if ($null -ne $result -and $result.Success) { 'Info' } else { 'Warning' }) -Owner $Task.State.Owner
        }
    }
}
