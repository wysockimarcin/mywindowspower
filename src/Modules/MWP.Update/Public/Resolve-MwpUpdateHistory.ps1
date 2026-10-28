function Resolve-MwpUpdateHistory {
    <#
    .SYNOPSIS
        Zamienia surowy wynik odczytu historii (Get-MwpUpdateHistory -AsOperation, blok History) na obiekt MWP.UpdateHistory z wpisami MWP.UpdateHistoryEntry.

    .DESCRIPTION
        Czysta funkcja: tekst JSON, MWP.Result z operacji w tle albo obiekt surowy; gotowy
        MWP.UpdateHistory jest zwracany bez zmian. Daty w czasie lokalnym, opisy operacji i wyników
        po polsku, KB z tytułu, opis kodu błędu (HRESULT). Wpisy od najnowszego. Zwraca $null, gdy
        danych nie ma.

    .PARAMETER ComputerName
        Nazwa komputera w komunikacie (z kontekstu); domyślnie nazwa zwrócona przez komputer docelowy.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data,

        [AllowEmptyString()]
        [string] $ComputerName = ''
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.UpdateHistory') {
        return $Data
    }
    $raw = ConvertFrom-MwpUpdateJson -Data $Data -Kind 'MWP.UpdateHistoryRaw'
    if ($null -eq $raw) {
        return $null
    }
    $entries = @(foreach ($item in @($raw.Entries | Where-Object { $null -ne $_ })) {
            $date = ConvertFrom-MwpUpdateDate -Value $item.Date
            $title = [string]$item.Title
            $kb = @([regex]::Matches($title, 'KB\d{6,8}') | ForEach-Object { $_.Value } | Select-Object -Unique)
            $hresult = [string]$item.HResult
            $code = [int]$item.ResultCode
            [pscustomobject]@{
                PSTypeName          = 'MWP.UpdateHistoryEntry'
                Date                = $date
                DateText            = $(if ($null -ne $date) { $date.ToString('yyyy-MM-dd HH:mm') } else { '' })
                Operation           = [int]$item.Operation
                OperationText       = Get-MwpUpdateText -Kind Operation -Value $item.Operation
                ResultCode          = $code
                ResultText          = Get-MwpUpdateText -Kind ResultCode -Value $code
                IsFailure           = $code -eq 4 -or $code -eq 5
                HResult             = $(if ($hresult -eq '0x00000000') { '' } else { $hresult })
                HResultText         = Get-MwpUpdateText -Kind HResult -Value $hresult
                Title               = $title
                KB                  = $kb
                KBText              = ($kb -join ', ')
                Description         = [string]$item.Description
                ClientApplicationId = [string]$item.ClientApplicationId
                SupportUrl          = [string]$item.SupportUrl
                UpdateId            = [string]$item.UpdateId
            }
        })
    $errorText = $null
    if ($raw.Error) {
        $hint = Get-MwpUpdateText -Kind HResult -Value $raw.HResult
        $errorText = if ($hint) { '{0} ({1}: {2})' -f $raw.Error, $raw.HResult, $hint } else { '{0} ({1})' -f $raw.Error, $raw.HResult }
    }
    $computer = if ($ComputerName) { $ComputerName } else { [string]$raw.ComputerName }
    $failed = @($entries | Where-Object { $_.IsFailure }).Count
    $message = if ($null -ne $errorText) {
        "Nie udało się odczytać historii aktualizacji komputera '{0}': {1}" -f $computer, $errorText
    }
    else {
        "Historia aktualizacji komputera '{0}': {1} z {2} wpisów (niepowodzenia: {3})." -f $computer, $entries.Count, [int]$raw.TotalCount, $failed
    }
    [pscustomobject]@{
        PSTypeName   = 'MWP.UpdateHistory'
        Kind         = 'MWP.UpdateHistory'
        ComputerName = $computer
        CollectedAt  = ConvertFrom-MwpUpdateDate -Value $raw.CollectedAt
        TotalCount   = [int]$raw.TotalCount
        Entries      = @($entries | Sort-Object -Property @{ Expression = { if ($null -ne $_.Date) { $_.Date } else { [datetime]::MinValue } } } -Descending)
        FailedCount  = $failed
        Success      = $null -eq $errorText
        ErrorText    = $errorText
        Message      = $message
    }
}
