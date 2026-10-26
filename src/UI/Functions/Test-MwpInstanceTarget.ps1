function Test-MwpInstanceTarget {
    <#
    .SYNOPSIS
        Sprawdza, czy dla modułu można otworzyć instancję na wybranym komputerze; zwraca powód odmowy.

    .DESCRIPTION
        Te same reguły co New-MwpModuleInstance (D-035), sprawdzane przed otwarciem okna wyboru, żeby
        pokazać powód przy komputerze: moduł musi mieć poprawny kontrakt, nie może być bazowy,
        a komputer zdalny wymaga RemoteTarget w Capabilities modułu.

    .PARAMETER Definition
        Definicja modułu (Get-MwpModuleDefinition).

    .PARAMETER Target
        Komputer docelowy (Get-MwpTarget).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Definition,

        [Parameter(Mandatory)]
        [object] $Target
    )

    $reason = $null
    if (-not $Definition.IsValid) {
        $reason = 'Moduł ma niepoprawny kontrakt.'
    }
    elseif ($Definition.IsBase) {
        $reason = 'Moduł bazowy nie tworzy instancji.'
    }
    elseif (-not $Target.IsLocal -and @($Definition.Capabilities) -notcontains 'RemoteTarget') {
        $reason = 'Moduł nie obsługuje jeszcze komputerów zdalnych (brak RemoteTarget w kontrakcie).'
    }
    [pscustomobject]@{
        Allowed = $null -eq $reason
        Reason  = $reason
    }
}
