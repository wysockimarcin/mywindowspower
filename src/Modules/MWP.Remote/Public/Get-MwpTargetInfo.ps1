function Get-MwpTargetInfo {
    <#
    .SYNOPSIS
        Odczytuje podstawowe informacje o komputerze docelowym: nazwa, system, wersja PowerShella, czas.

    .DESCRIPTION
        Operacja klasy Odczyt na komputerze kontekstu (localhost albo zdalnym). Blok jest
        samowystarczalny i zgodny z Windows PowerShell 5.1 (D-036). Bez -AsOperation wykonuje się
        synchronicznie (Invoke-MwpOnTarget) i zwraca MWP.Result z danymi w Data; z -AsOperation
        startuje w puli runspace'ów (Start-MwpOperation) i zwraca uchwyt MWP.Operation — tak
        korzysta z niej okno hosta (odczyt testowy instancji), żeby nie czekać w wątku okna.
        Dane: ComputerName, System, OSVersion, PowerShell, Time.

    .EXAMPLE
        (Get-MwpTargetInfo -Context (New-MwpExecutionContext)).Data
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [switch] $AsOperation
    )

    $block = {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            System       = [string]$os.Caption
            OSVersion    = [string]$os.Version
            PowerShell   = $PSVersionTable.PSVersion.ToString()
            Time         = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
    }
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -Operation 'Remote.TargetInfo'
    }
    Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -Operation 'Remote.TargetInfo'
}
