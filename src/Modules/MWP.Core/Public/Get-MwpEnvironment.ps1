function Get-MwpEnvironment {
    <#
    .SYNOPSIS
        Zwraca informacje o środowisku hosta: wersja PowerShella, Windows, administrator, STA.

    .DESCRIPTION
        Wspólne wykrywanie środowiska (D-017). Dotyczy procesu hosta na komputerze lokalnym,
        dlatego ComputerName to zawsze 'localhost'. Funkcja tylko czyta.

    .OUTPUTS
        [pscustomobject] typu MWP.Environment.

    .EXAMPLE
        (Get-MwpEnvironment).IsWindows11
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $onWindows = Test-MwpIsWindows
    $osVersion = [Environment]::OSVersion.Version

    [pscustomobject]@{
        PSTypeName     = 'MWP.Environment'
        ComputerName   = 'localhost'
        HostVersion    = $MyInvocation.MyCommand.Module.Version
        PSVersion      = $PSVersionTable.PSVersion
        PSEdition      = $PSVersionTable.PSEdition
        IsCore         = $PSVersionTable.PSEdition -eq 'Core'
        IsWindows      = $onWindows
        OSVersion      = $osVersion
        OSBuild        = $osVersion.Build
        IsWindows11    = $onWindows -and ($osVersion.Build -ge 22000)
        IsAdmin        = Test-MwpAdmin
        ApartmentState = [Threading.Thread]::CurrentThread.GetApartmentState()
        HostPath       = (Get-Process -Id $PID).Path
    }
}
