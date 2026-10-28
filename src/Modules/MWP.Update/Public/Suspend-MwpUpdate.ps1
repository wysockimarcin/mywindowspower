function Suspend-MwpUpdate {
    <#
    .SYNOPSIS
        Wstrzymuje aktualizacje Windows na komputerze docelowym na 1–5 tygodni (tak jak przycisk „Wstrzymaj” w Ustawieniach Windows 11).

    .DESCRIPTION
        Operacja klasy Zmiana (D-027, D-048): zapisuje w HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings
        wartości PauseUpdatesStartTime/PauseUpdatesExpiryTime, PauseFeatureUpdatesStartTime/EndTime
        i PauseQualityUpdatesStartTime/EndTime (REG_SZ, ISO 8601 w UTC) — początek teraz, koniec za
        -Weeks tygodni (pauza trwająca zostaje zastąpiona nową). Limit 5 tygodni (35 dni) to limit
        Ustawień Windows 11. Wymaga administratora na komputerze docelowym; podgląd (-WhatIf)
        i potwierdzenie z nazwą komputera; ponowny odczyt sprawdza zapis. Wpis cofnięcia przywraca
        wartości sprzed zmiany (Restore-MwpUpdatePause). Zasady grupy (Policies) mają pierwszeństwo —
        stan je pokazuje, funkcja ich nie zmienia.

    .PARAMETER Weeks
        Liczba tygodni pauzy (1–5).

    .EXAMPLE
        Suspend-MwpUpdate -Weeks 2 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateRange(1, 5)]
        [int] $Weeks = 1,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Update.Pause'
    $common = @{ Operation = $operation; Target = 'Windows Update'; ComputerName = $Context.ComputerName }
    $status = Get-MwpUpdateStatus -Context $Context
    if (-not $status.Success) {
        return New-MwpResult @common -Success $false -Message $status.Message -ErrorMessage $status.ErrorMessage
    }
    $pause = $status.Data.Pause
    $start = (Get-Date).ToUniversalTime()
    $end = $start.AddDays(7 * $Weeks)
    $format = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $startText = $start.ToString($format, $culture)
    $endText = $end.ToString($format, $culture)
    $values = @{
        PauseUpdatesStartTime        = $startText
        PauseUpdatesExpiryTime       = $endText
        PauseFeatureUpdatesStartTime = $startText
        PauseFeatureUpdatesEndTime   = $endText
        PauseQualityUpdatesStartTime = $startText
        PauseQualityUpdatesEndTime   = $endText
    }
    $afterText = 'Aktualizacje wstrzymane do {0:yyyy-MM-dd HH:mm}.' -f $end.ToLocalTime()
    $denied = Test-MwpUpdatePauseAccess -Context $Context -Operation $operation -BeforeText $pause.Text
    if ($null -ne $denied) {
        return $denied
    }
    $action = 'Wstrzymanie aktualizacji na {0} tydz. (do {1:yyyy-MM-dd HH:mm})' -f $Weeks, $end.ToLocalTime()
    $target = Format-MwpOperationTarget -Target 'pauza Windows Update' -ComputerName $Context.ComputerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $pause.Text -After $afterText -Message ('Podgląd: {0}.' -f $action)
    }
    Invoke-MwpUpdatePauseChange -Context $Context -Operation $operation -Before $pause.Values -Values $values -SaveUndo -BeforeText $pause.Text -AfterText $afterText
}
