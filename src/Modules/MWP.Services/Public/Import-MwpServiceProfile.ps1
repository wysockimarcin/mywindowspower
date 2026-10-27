function Import-MwpServiceProfile {
    <#
    .SYNOPSIS
        Stosuje profil usług na komputerze docelowym: zmienia typy uruchomienia różniące się od profilu.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027). Najpierw różnice (Compare-MwpServiceProfile); podgląd (-WhatIf)
        wymienia zmiany, potwierdzenie zawiera nazwę komputera i liczbę zmian. Każda zmiana to
        Set-MwpServiceStartupType (lista ochronna, uprawnienia, log i osobny wpis cofnięcia dla każdej
        usługi). Usługi chronione, brakujące i bez zmian są pomijane; stan usług (działa/zatrzymana)
        nie jest zmieniany (D-045). Wynik: MWP.Result z listą wyników pojedynczych zmian w Data;
        Success = $true, gdy wszystkie zmiany się udały.

    .PARAMETER Path
        Plik profilu.

    .PARAMETER ProfileData
        Profil (MWP.ServiceProfile albo wynik Read-MwpServiceProfile).

    .PARAMETER Name
        Tylko te usługi z profilu.

    .EXAMPLE
        Import-MwpServiceProfile -Path .\uslugi.json -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Path')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'Profile')]
        [object] $ProfileData,

        [ValidateScript({ Test-MwpServiceName -Name $_ })]
        [string[]] $Name = @(),

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $operation = 'Services.ImportProfile'
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $ProfileData = Read-MwpServiceProfile -Path $Path
    }
    $compare = Compare-MwpServiceProfile -ProfileData $ProfileData -Context $Context
    if (-not $compare.Success) {
        return $compare
    }
    $common = @{ Operation = $operation; Target = $compare.Target; ComputerName = $computerName }
    $changes = @($compare.Data | Where-Object { $_.Action -eq 'Change' -and ($Name.Count -eq 0 -or $Name -contains $_.Name) })
    if ($changes.Count -eq 0) {
        return New-MwpResult @common -Success $true -Message ("Profil jest zgodny z komputerem '{0}' — brak zmian typu uruchomienia." -f $computerName) -Data @()
    }
    $list = @($changes | ForEach-Object { '{0}: {1} → {2}' -f $_.Name, $_.CurrentText, $_.WantedText }) -join '; '
    $target = Format-MwpOperationTarget -Target ('profil usług ({0} zmian)' -f $changes.Count) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Zmiana typów uruchomienia: {0}' -f $list))) {
        return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd importu profilu na komputerze '{0}': {1}." -f $computerName, $list) -Data $changes
    }
    $results = @(foreach ($row in $changes) {
            Set-MwpServiceStartupType -Name $row.Name -StartupType $row.Wanted -Context $Context -Confirm:$false
        })
    $failed = @($results | Where-Object { -not $_.Success })
    $changed = @($results | Where-Object { $_.Changed }).Count
    $message = "Import profilu na komputerze '{0}': zmieniono {1} z {2} typów uruchomienia (każda zmiana ma własny wpis cofnięcia)." -f $computerName, $changed, $changes.Count
    if ($failed.Count -gt 0) {
        $message = '{0} Błędy: {1}' -f $message, (@($failed | ForEach-Object { $_.Message }) -join ' ')
    }
    Write-MwpLog -Level $(if ($failed.Count -gt 0) { 'Warning' } else { 'Info' }) -Source 'MWP.Services' -Operation $operation -ComputerName $computerName -Message $message
    New-MwpResult @common -Success ($failed.Count -eq 0) -Changed ($changed -gt 0) -Message $message -Data $results
}
