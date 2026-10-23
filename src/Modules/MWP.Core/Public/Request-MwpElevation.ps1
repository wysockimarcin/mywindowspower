function Request-MwpElevation {
    <#
    .SYNOPSIS
        Uruchamia skrypt ponownie z uprawnieniami administratora (monit UAC), na życzenie.

    .DESCRIPTION
        Gdy bieżący proces ma już uprawnienia administratora, nic nie robi. W przeciwnym razie
        uruchamia nowy proces tego samego PowerShella (Start-Process -Verb RunAs) ze skryptem
        i argumentami. Bieżący proces nie jest zamykany; decyduje o tym wywołujący (launcher, GUI).
        Nie zmienia zasad wykonywania ani ustawień UAC.

    .PARAMETER FilePath
        Skrypt do uruchomienia z uprawnieniami administratora.

    .PARAMETER ArgumentList
        Argumenty skryptu; każdy jest cytowany osobno (nie są sklejane z tekstu wejściowego).

    .PARAMETER HostPath
        Program PowerShella; domyślnie ten sam, w którym działa bieżący proces (5.1 albo 7.x).

    .OUTPUTS
        [pscustomobject] typu MWP.Result.

    .EXAMPLE
        Request-MwpElevation -FilePath .\Start-MyWindowsPower.ps1 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,

        [string[]] $ArgumentList = @(),

        [ValidateNotNullOrEmpty()]
        [string] $HostPath = (Get-Process -Id $PID).Path
    )

    $common = @{ Operation = 'Core.Elevation'; Target = $FilePath; ComputerName = 'localhost' }

    if (Test-MwpAdmin) {
        return New-MwpResult @common -Success $true -Message 'Bieżący proces ma już uprawnienia administratora.'
    }
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return New-MwpResult @common -Success $false -Message ("Nie znaleziono skryptu {0}." -f $FilePath)
    }

    $arguments = @('-NoProfile', '-File', (Resolve-Path -LiteralPath $FilePath).ProviderPath) + $ArgumentList
    $argumentLine = @($arguments | ForEach-Object { ConvertTo-MwpProcessArgument -Value $_ }) -join ' '

    $target = Format-MwpOperationTarget -Target ("skrypt {0}" -f $FilePath) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, 'Ponowne uruchomienie z uprawnieniami administratora (UAC)')) {
        return New-MwpResult @common -Success $true -IsPreview -Message ("Podgląd: {0} {1}" -f $HostPath, $argumentLine)
    }

    try {
        $null = Start-Process -FilePath $HostPath -ArgumentList $argumentLine -Verb RunAs -ErrorAction Stop
        $message = 'Uruchomiono nowy proces z uprawnieniami administratora. Bieżący proces można zamknąć.'
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $common.Operation -Message $message -Data @{ FilePath = $FilePath }
        New-MwpResult @common -Success $true -Changed $true -Message $message
    }
    catch {
        $cancelled = $false
        $exception = $_.Exception
        while ($null -ne $exception) {
            if ($exception -is [ComponentModel.Win32Exception] -and $exception.NativeErrorCode -eq 1223) {
                $cancelled = $true
            }
            $exception = $exception.InnerException
        }
        $message = if ($cancelled) {
            'Użytkownik anulował monit UAC; uprawnienia nie zostały podniesione.'
        }
        else {
            "Nie udało się uruchomić procesu z uprawnieniami administratora: $($_.Exception.Message)"
        }
        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation $common.Operation -Message $message
        New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message
    }
}
