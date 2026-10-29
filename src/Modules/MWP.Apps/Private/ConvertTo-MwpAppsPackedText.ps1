function ConvertTo-MwpAppsPackedText {
    <#
    .SYNOPSIS
        Pakuje tekst (UTF-8, GZip) do Base64 — blok Winget w żądaniu zadania harmonogramu (D-051).

    .DESCRIPTION
        Polecenie zadania (powershell.exe -EncodedCommand) ma ograniczoną długość, a blok Winget jest
        przekazywany w całości, żeby zadanie wykonywało ten sam kod co uruchomienie bezpośrednie.
        Rozpakowuje skrypt zadania (Get-MwpWingetTaskScript).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Text
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $buffer = New-Object -TypeName IO.MemoryStream
    $gzip = New-Object -TypeName IO.Compression.GZipStream -ArgumentList $buffer, ([IO.Compression.CompressionMode]::Compress)
    $gzip.Write($bytes, 0, $bytes.Length)
    $gzip.Close()
    [Convert]::ToBase64String($buffer.ToArray())
}
