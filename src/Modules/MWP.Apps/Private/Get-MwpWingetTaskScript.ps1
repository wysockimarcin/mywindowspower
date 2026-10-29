function Get-MwpWingetTaskScript {
    <#
    .SYNOPSIS
        Zwraca stały tekst skryptu uruchamianego przez jednorazowe zadanie harmonogramu winget na komputerze docelowym (D-051).

    .DESCRIPTION
        Skrypt działa w Windows PowerShell 5.1 (powershell.exe -EncodedCommand) jako SYSTEM albo
        w sesji zalogowanego użytkownika. Żądanie (JSON w Base64) wstawia blok WingetTask w miejsce
        znacznika __MWP_REQUEST__ — Base64 nie zawiera znaków, które zmieniłyby kod (wzorzec
        Get-MwpNetworkRollbackScript, D-049). Żądanie niesie blok Winget modułu (ten sam kod co przy
        uruchomieniu bezpośrednim, spakowany GZip) i jego argumenty. Skrypt zapisuje swój PID (do
        zatrzymania drzewa procesów po przekroczeniu limitu), uruchamia blok i zapisuje jego wynik
        (MWP.WingetRaw, UTF-8) do pliku wyniku: najpierw plik tymczasowy, potem zamiana nazwy, więc
        plik wyniku jest zawsze kompletny.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    @'
$ErrorActionPreference = 'Stop'
$request = ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__MWP_REQUEST__')))
$output = $null
try {
    [IO.File]::WriteAllText([string]$request.PidFile, [string]$PID)
    $packed = New-Object -TypeName IO.MemoryStream -ArgumentList (, [Convert]::FromBase64String([string]$request.RunScript))
    $gzip = New-Object -TypeName IO.Compression.GZipStream -ArgumentList $packed, ([IO.Compression.CompressionMode]::Decompress)
    $reader = New-Object -TypeName IO.StreamReader -ArgumentList $gzip, ([Text.Encoding]::UTF8)
    $run = [scriptblock]::Create($reader.ReadToEnd())
    $reader.Close()
    $output = [string](@(& $run ([string]$request.RunRequest)) | Select-Object -Last 1)
}
catch {
    $output = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ Kind = 'MWP.WingetRaw'; Found = $false; WingetPath = ''; ExitCode = $null; TimedOut = $false; Lines = @(); Error = $_.Exception.Message; DurationMs = 0 })
}
finally {
    $temporary = [string]$request.ResultFile + '.tmp'
    [IO.File]::WriteAllText($temporary, [string]$output, (New-Object -TypeName Text.UTF8Encoding -ArgumentList $false))
    Move-Item -LiteralPath $temporary -Destination ([string]$request.ResultFile) -Force
}
'@
}
