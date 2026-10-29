function New-MwpCleanupScan {
    <#
    .SYNOPSIS
        Składa wynik skanu czyszczenia (MWP.CleanupScan) z wyników kategorii: sumy plików i rozmiaru.

    .DESCRIPTION
        Wspólne dla Measure-MwpCleanupCategory (skan krok po kroku) i Resolve-MwpCleanupScan (wynik
        operacji w tle widgetu, D-053), żeby oba miały ten sam kształt.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy tylko obiekt w pamięci.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $ComputerName,

        [AllowEmptyCollection()]
        [object[]] $Category = @(),

        [bool] $IsAdministrator,

        [bool] $IsRemote,

        [bool] $IncludeUserProfiles,

        [AllowEmptyCollection()]
        [string[]] $UserProfile = @(),

        [bool] $Cancelled,

        [AllowEmptyCollection()]
        [string[]] $Warning = @(),

        [datetime] $CollectedAt = (Get-Date)
    )

    $totalBytes = [long]0
    $totalFiles = [long]0
    foreach ($item in $Category) {
        $totalBytes += $item.SizeBytes
        $totalFiles += $item.FileCount
    }
    [pscustomobject]@{
        PSTypeName          = 'MWP.CleanupScan'
        ComputerName        = $ComputerName
        CollectedAt         = $CollectedAt
        IsAdministrator     = $IsAdministrator
        IsRemote            = $IsRemote
        IncludeUserProfiles = $IncludeUserProfiles
        UserProfiles        = @($UserProfile)
        Categories          = @($Category)
        TotalFiles          = $totalFiles
        TotalBytes          = $totalBytes
        TotalText           = Format-MwpCleanupSize -Bytes $totalBytes
        Cancelled           = $Cancelled
        Warnings            = @($Warning)
    }
}
