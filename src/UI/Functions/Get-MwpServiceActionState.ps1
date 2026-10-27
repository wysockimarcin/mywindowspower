function Get-MwpServiceActionState {
    <#
    .SYNOPSIS
        Wylicza dostępność przycisków widoku Usługi dla wybranej usługi (blokada usług z listy ochronnej w GUI).

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Usługa z listy ochronnej (D-045): „Zatrzymaj”
        i „Uruchom ponownie” są wyłączone, a lista typów uruchomienia ma tylko typy automatyczne
        (Get-MwpServiceViewOption). To blokada w GUI; funkcje MWP.Services odmawiają tych zmian
        niezależnie (także w CLI i na komputerze zdalnym). Wynik: CanStart, CanStop, CanRestart,
        CanSetStartupType, ProtectionText (tekst baneru albo $null).

    .PARAMETER Service
        Wybrana usługa (MWP.Service) albo $null.

    .PARAMETER Ready
        Instancja połączona, odczyt jest i nic nie trwa.

    .PARAMETER StartupType
        Typ uruchomienia wybrany na liście (porównywany z bieżącym).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Service,

        [bool] $Ready,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $StartupType
    )

    if ($null -eq $Service -or -not $Ready) {
        return [pscustomobject]@{
            CanStart          = $false
            CanStop           = $false
            CanRestart        = $false
            CanSetStartupType = $false
            ProtectionText    = $(if ($null -ne $Service -and $Service.IsProtected) { 'Usługa chroniona: {0}' -f $Service.ProtectionReason } else { $null })
        }
    }
    $protected = [bool]$Service.IsProtected
    [pscustomobject]@{
        CanStart          = $Service.Status -ne 'Running' -and $Service.StartupType -ne 'Disabled'
        CanStop           = -not $protected -and $Service.Status -ne 'Stopped' -and [bool]$Service.CanStop
        CanRestart        = -not $protected -and $Service.Status -eq 'Running' -and [bool]$Service.CanStop
        CanSetStartupType = $Service.StartupType -ne 'Unknown' -and -not [string]::IsNullOrEmpty($StartupType) -and $StartupType -ne $Service.StartupType
        ProtectionText    = $(if ($protected) {
                'Usługa chroniona — można ją uruchomić i ustawić na typ automatyczny; zatrzymanie, ponowne uruchomienie oraz typ ręczny i wyłączony są zablokowane. Powód: {0}' -f $Service.ProtectionReason
            }
            else { $null })
    }
}
