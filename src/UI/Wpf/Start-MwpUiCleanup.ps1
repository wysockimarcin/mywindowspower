function Start-MwpUiCleanup {
    <#
    .SYNOPSIS
        Czyści w tle potwierdzone kategorie na komputerze instancji, potem pokazuje raport i skanuje ponownie.

    .DESCRIPTION
        Wywoływana dopiero po oknie potwierdzenia (Invoke-MwpCleanupViewAction). Zadanie GUI wywołuje
        Clear-MwpCleanupCategory -Confirm:$false dla każdej kategorii z kontekstem instancji i tabelą
        postępu; log zapisuje funkcja logiki. Anulowanie z widoku ustawia CancelRequested — praca kończy
        się po bieżącym pliku (lokalnie) albo przed następną kategorią, a wyniki dotąd zebrane
        (Progress.Results) trafiają do raportu (ConvertTo-MwpCleanupReport). Zadanie nie jest anulowane
        przyciskiem paska stanu (przerwanie w połowie kategorii zgubiłoby jej wynik).

    .PARAMETER Category
        Identyfikatory kategorii do wyczyszczenia.

    .PARAMETER IncludeUserProfiles
        Profile wszystkich użytkowników — jak w skanie, z którego pochodzi podgląd.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Wywoływana po oknie potwierdzenia; podgląd i potwierdzenie zapewnia widok i Clear-MwpCleanupCategory.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [Parameter(Mandatory)]
        [string[]] $Category,

        [bool] $IncludeUserProfiles = $false
    )

    $ui = $script:MwpUi
    $context = $Entry.Instance.Context
    $view = $Entry.Cleanup
    if ($null -ne $view.Task) {
        return
    }
    $module = @(Get-Module -Name $Entry.Instance.ModuleName) | Select-Object -First 1
    $view.TaskKind = 'Clear'
    $view.Task = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Czyszczenie dysku ({0})' -f $context.ComputerName) -State @{ InstanceId = $Entry.Id } `
        -ArgumentList $(if ($null -ne $module) { $module.Path } else { '' }), $context, $Category, $IncludeUserProfiles -ScriptBlock (Get-MwpUiCleanupScript -Name Clear) -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Cleanup.Task = $null
        $entry.Cleanup.TaskKind = $null
        $results = if ($null -ne $Task.Progress['Results']) { @($Task.Progress['Results'].ToArray()) } else { @($Task.Output) }
        $cancelled = [bool]$Task.Progress['CancelRequested'] -or $Task.Status -eq 'Cancelled'
        $report = ConvertTo-MwpCleanupReport -Result $results -Cancelled:$cancelled
        if ($Task.Status -eq 'Failed') {
            $report.Text = '{0}{1}Zadanie czyszczenia zakończyło się błędem: {2}' -f $report.Text, [Environment]::NewLine, $Task.Error
        }
        $entry.Cleanup.Report = $report
        Start-MwpUiCleanupScan -Entry $entry
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpCleanupView -Entry $Entry
}
