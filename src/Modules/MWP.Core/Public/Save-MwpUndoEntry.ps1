function Save-MwpUndoEntry {
    <#
    .SYNOPSIS
        Zapisuje w rejestrze cofnięć stan sprzed zmiany i sposób jej cofnięcia.

    .DESCRIPTION
        Wpis to plik JSON <katalog danych>\undo\<Id>.json (zapis atomowy); katalog danych to
        domyślnie <folder aplikacji>\data, ustawienie dataPath (D-032).
        Cofnięcie nie jest zapisywane jako kod, tylko jako nazwa polecenia MyWindowsPower
        (Verb-MwpNoun) i jego parametry; Invoke-MwpUndo wywołuje to polecenie. Dzięki temu
        z pliku nie da się uruchomić dowolnego kodu, a wpis działa w każdym procesie i runspace.
        W stanie (-Before, -After, -UndoParameters) nie zapisuj sekretów.

    .PARAMETER ComputerName
        Komputer, na którym wykonano zmianę; domyślnie 'localhost' (D-019).

    .PARAMETER UndoCommand
        Polecenie przywracające stan, np. 'Set-MwpSetting'.

    .PARAMETER UndoParameters
        Parametry polecenia przywracającego (wartości muszą dać się zapisać w JSON).

    .EXAMPLE
        Save-MwpUndoEntry -Module 'MWP.Services' -Operation 'Services.SetStartupType' -Target 'Spooler' -Before 'Automatic' -After 'Manual' -UndoCommand 'Set-MwpServiceStartupType' -UndoParameters @{ Name = 'Spooler'; StartupType = 'Automatic' }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Operation,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost',

        [AllowEmptyString()]
        [string] $Description = '',

        [AllowNull()]
        [object] $Before,

        [AllowNull()]
        [object] $After,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z]+-Mwp[A-Za-z0-9]+$')]
        [string] $UndoCommand,

        [hashtable] $UndoParameters = @{}
    )

    $entry = [ordered]@{
        schemaVersion  = 1
        id             = [guid]::NewGuid().ToString()
        createdAt      = (Get-Date).ToString('o')
        module         = $Module
        operation      = $Operation
        target         = $Target
        computerName   = $ComputerName
        description    = $Description
        before         = $Before
        after          = $After
        undoCommand    = $UndoCommand
        undoParameters = $UndoParameters
        status         = 'Pending'
        undoneAt       = $null
        lastError      = $null
    }

    $path = Join-Path -Path (Get-MwpDataPath -Kind Undo) -ChildPath ($entry['id'] + '.json')
    Write-MwpJsonFile -Path $path -InputObject $entry
    Write-MwpLog -Level Info -Source $Module -Operation 'Undo.Save' -ComputerName $ComputerName `
        -Message ("Zapisano wpis cofnięcia {0} dla operacji {1} ({2})." -f $entry['id'], $Operation, $Target)

    $saved = ConvertTo-MwpHashtable -InputObject (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
    ConvertTo-MwpUndoEntry -Data $saved -Path $path
}
