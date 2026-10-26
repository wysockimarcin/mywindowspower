function Invoke-MwpUiSafe {
    <#
    .SYNOPSIS
        Wykonuje obsługę zdarzenia okna tak, żeby wyjątek nie zamknął aplikacji.

    .DESCRIPTION
        Nieobsłużony wyjątek w zdarzeniu WPF przerwałby pętlę komunikatów okna. Każda obsługa
        zdarzenia w MWP.UI jest opakowana tą funkcją: błąd trafia do logu (z nazwą akcji) i do okna
        komunikatu, a okno działa dalej. Błędy przewidziane (MWP.Result z Success = $false)
        obsługuje kod akcji; tu trafiają tylko nieprzewidziane.

    .PARAMETER Action
        Blok obsługi zdarzenia.

    .PARAMETER Name
        Nazwa akcji do komunikatu i logu.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock] $Action,

        [ValidateNotNullOrEmpty()]
        [string] $Name = 'UI.Action'
    )

    try {
        & $Action
    }
    catch {
        $message = "Nieoczekiwany błąd ({0}): {1}" -f $Name, $_.Exception.Message
        try {
            Write-MwpLog -Level Error -Source 'MWP.UI' -Operation $Name -Message $message -Data @{ Position = $_.InvocationInfo.PositionMessage }
        }
        catch {
            Write-Warning $message
        }
        Show-MwpMessage -Text $message -Kind Error
    }
}
