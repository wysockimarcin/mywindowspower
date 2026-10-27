function Save-MwpPowerReport {
    <#
    .SYNOPSIS
        Zapisuje raport zasilania (z New-MwpPowerReport albo z jego operacji w tle) do pliku HTML w lokalnym folderze.

    .DESCRIPTION
        Zapis na komputerze, na którym działa host (raport z komputera zdalnego przychodzi jako
        treść, D-044). Nazwa pliku: <komputer>-<battery|energy>-report-RRRRMMDD-GGmmss.html.
        Folder domyślny: Get-MwpPowerReportDirectory (<katalog danych>\reports); tworzony, gdy go
        nie ma. Obsługuje -WhatIf. Nie zmienia ustawień systemu, więc nie tworzy wpisu cofnięcia
        (plik można usunąć ręcznie). Zwraca MWP.Result z Data.Path.

    .PARAMETER Report
        MWP.Result z New-MwpPowerReport albo z Wait-MwpOperation (operacja z -AsOperation).

    .PARAMETER Directory
        Folder docelowy.

    .EXAMPLE
        New-MwpPowerReport -Kind Battery | Save-MwpPowerReport -Directory "$env:USERPROFILE\Desktop"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [object] $Report,

        [ValidateNotNullOrEmpty()]
        [string] $Directory
    )

    process {
        $resolved = Resolve-MwpPowerReport -Data $Report
        if (-not $resolved.Success) {
            return $resolved
        }
        $data = @($resolved.Data) | Select-Object -First 1
        $computerName = $data.ComputerName
        $common = @{ Operation = 'Power.SaveReport'; Target = $data.ReportKind; ComputerName = $computerName }
        if (-not $PSBoundParameters.ContainsKey('Directory')) {
            $Directory = Get-MwpPowerReportDirectory
        }
        try {
            $folder = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Directory))
        }
        catch {
            return New-MwpResult @common -Success $false -Message ("Niepoprawny folder raportów '{0}': {1}" -f $Directory, $_.Exception.Message) -ErrorMessage $_.Exception.Message
        }
        $safeName = [regex]::Replace($computerName, '[^A-Za-z0-9._-]', '_')
        $fileName = '{0}-{1}-report-{2}.html' -f $safeName, $data.ReportKind.ToLowerInvariant(), (Get-Date).ToString('yyyyMMdd-HHmmss')
        $path = Join-Path -Path $folder -ChildPath $fileName

        if (-not $PSCmdlet.ShouldProcess($path, ('Zapis raportu ({0}) komputera {1}' -f $data.ReportKind, $computerName))) {
            return New-MwpResult @common -Success $true -IsPreview -After $path -Message ("Podgląd: raport zostanie zapisany do '{0}'." -f $path)
        }
        try {
            if (-not [IO.Directory]::Exists($folder)) {
                $null = [IO.Directory]::CreateDirectory($folder)
            }
            [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($data.Content))
            $message = "Zapisano raport ({0}) komputera '{1}' do '{2}'." -f $data.ReportKind, $computerName, $path
            Write-MwpLog -Level Info -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message -Data @{ Path = $path; Kind = $data.ReportKind }
            New-MwpResult @common -Success $true -Changed $true -After $path -Message $message -Data ([ordered]@{ Path = $path; ReportKind = $data.ReportKind })
        }
        catch {
            $message = "Nie udało się zapisać raportu do '{0}': {1}" -f $path, $_.Exception.Message
            Write-MwpLog -Level Warning -Source 'MWP.Power' -Operation $common.Operation -ComputerName $computerName -Message $message
            New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message
        }
    }
}
