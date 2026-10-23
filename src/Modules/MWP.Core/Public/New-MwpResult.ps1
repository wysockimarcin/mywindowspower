function New-MwpResult {
    <#
    .SYNOPSIS
        Tworzy standardowy obiekt wyniku operacji (MWP.Result).

    .DESCRIPTION
        Każda funkcja zmieniająca system zwraca ten obiekt (wzorzec w ARCHITEKTURA.md).
        Pola: Success, Changed, IsPreview, RestartRequired, Operation, Target, ComputerName,
        Message, Before, After, UndoId, ErrorMessage, Data, Timestamp. W podglądzie (-IsPreview)
        Changed jest zawsze $false.

    .PARAMETER ComputerName
        Komputer docelowy operacji; domyślnie 'localhost' (D-019).

    .EXAMPLE
        New-MwpResult -Success $true -Changed $true -Operation 'Services.SetStartupType' -Target 'Spooler' -Before 'Automatic' -After 'Manual'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy tylko obiekt w pamięci; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [bool] $Success,

        [AllowEmptyString()]
        [string] $Message = '',

        [AllowEmptyString()]
        [string] $Operation = '',

        [AllowNull()]
        [object] $Target,

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [AllowNull()]
        [object] $Before,

        [AllowNull()]
        [object] $After,

        [bool] $Changed = $false,

        [switch] $RestartRequired,

        [switch] $IsPreview,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $UndoId,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $ErrorMessage,

        [AllowNull()]
        [object] $Data
    )

    [pscustomobject]@{
        PSTypeName      = 'MWP.Result'
        Success         = $Success
        Changed         = $Changed -and -not $IsPreview
        IsPreview       = [bool]$IsPreview
        RestartRequired = [bool]$RestartRequired
        Operation       = $Operation
        Target          = $Target
        ComputerName    = $ComputerName
        Message         = $Message
        Before          = $Before
        After           = $After
        UndoId          = $(if ([string]::IsNullOrEmpty($UndoId)) { $null } else { $UndoId })
        ErrorMessage    = $(if ([string]::IsNullOrEmpty($ErrorMessage)) { $null } else { $ErrorMessage })
        Data            = $Data
        Timestamp       = Get-Date
    }
}
