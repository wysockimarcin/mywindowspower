function Export-MwpSystemReport {
    <#
    .SYNOPSIS
        Zapisuje raport informacji o systemie do pliku JSON albo tekstowego.

    .DESCRIPTION
        Funkcja eksportu z kontraktu widgetu (D-043). Nie zmienia systemu: zapisuje tylko plik
        wskazany przez użytkownika (komputer lokalny, także dla danych komputera zdalnego).
        Format wynika z -Format albo z rozszerzenia (.json — JSON, inne — tekst). JSON jest
        zapisywany w UTF-8 bez BOM, tekst w UTF-8 z BOM (Notatnik i 5.1 czytają polskie znaki).
        Istniejący plik jest nadpisywany (okno zapisu w GUI pyta o to wcześniej). Zwraca MWP.Result;
        błąd zapisu jako Success = $false.

    .PARAMETER Data
        Dane z Get-MwpSystemInfo (obiekt, tekst JSON albo MWP.Result).

    .PARAMETER Path
        Ścieżka pliku raportu.

    .EXAMPLE
        Export-MwpSystemReport -Data (Get-MwpSystemInfo -Context (New-MwpExecutionContext)) -Path "$env:TEMP\raport.txt"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Data,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [ValidateSet('Json', 'Text')]
        [string] $Format
    )

    $operation = 'Dashboard.Export'
    if (-not $PSBoundParameters.ContainsKey('Format')) {
        $Format = if ([IO.Path]::GetExtension($Path) -eq '.json') { 'Json' } else { 'Text' }
    }
    $info = Resolve-MwpSystemInfoData -Data $Data
    $common = @{ Operation = $operation; Target = $Path; ComputerName = 'localhost' }
    if ($null -eq $info) {
        return New-MwpResult @common -Success $false -Message 'Brak informacji o systemie do eksportu; odśwież widget i spróbuj ponownie.'
    }
    if (-not $PSCmdlet.ShouldProcess($Path, ('Zapis raportu ({0}) komputera {1}' -f $Format, $info.ComputerName))) {
        return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd: raport komputera {0} zostanie zapisany do '{1}'." -f $info.ComputerName, $Path)
    }
    try {
        $content = ConvertTo-MwpSystemReport -Data $info -Format $Format
        $encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList ($Format -eq 'Text')
        $full = [IO.Path]::GetFullPath($Path)
        $folder = [IO.Path]::GetDirectoryName($full)
        if (-not [IO.Directory]::Exists($folder)) {
            $null = [IO.Directory]::CreateDirectory($folder)
        }
        [IO.File]::WriteAllText($full, $content, $encoding)
        $message = "Zapisano raport komputera {0} do '{1}'." -f $info.ComputerName, $full
        Write-MwpLog -Level Info -Source 'MWP.Dashboard' -Operation $operation -ComputerName $info.ComputerName -Message $message -Data @{ Path = $full; Format = $Format }
        New-MwpResult @common -Success $true -Changed $true -Message $message -Data ([ordered]@{ Path = $full; Format = $Format })
    }
    catch {
        $message = "Nie udało się zapisać raportu do '{0}': {1}" -f $Path, $_.Exception.Message
        Write-MwpLog -Level Warning -Source 'MWP.Dashboard' -Operation $operation -Message $message
        New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message
    }
}
