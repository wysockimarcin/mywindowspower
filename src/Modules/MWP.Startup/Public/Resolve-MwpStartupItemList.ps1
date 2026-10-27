function Resolve-MwpStartupItemList {
    <#
    .SYNOPSIS
        Zamienia surowy wynik odczytu autostartu (Get-MwpStartupItem -AsOperation, blok ItemList) na listę MWP.StartupItemList.

    .DESCRIPTION
        Czysta funkcja (bez wywołań na komputerze docelowym): przyjmuje tekst JSON, MWP.Result
        z operacji w tle albo obiekt MWP.StartupItemRaw; gotowa MWP.StartupItemList jest zwracana
        bez zmian. Każda pozycja (MWP.StartupItem) ma identyfikator (Id = miejsce|SID|nazwa),
        stan z wartości StartupApproved (bit 0 pierwszego bajtu = wyłączona, jak w Menedżerze
        zadań; brak wartości = włączona), datę wyłączenia, możliwość przełączenia (RunOnce — nie),
        ocenę podpisu (Get-MwpSignatureRisk) i opis miejsca po polsku. Zwraca $null, gdy danych nie ma.

    .EXAMPLE
        Resolve-MwpStartupItemList -Data (Wait-MwpOperation -Operation (Get-MwpStartupItem -AsOperation))
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.StartupItemList') {
        return $Data
    }
    $raw = ConvertFrom-MwpStartupJson -Data $Data -Kind 'MWP.StartupItemRaw'
    if ($null -eq $raw -or $raw.Error) {
        return $null
    }
    $toggle = @('MachineRun', 'MachineRun32', 'MachineStartupFolder', 'UserRun', 'UserStartupFolder')
    $items = @(foreach ($item in @($raw.Items | Where-Object { $null -ne $_ })) {
            $location = [string]$item.Location
            $canToggle = $toggle -contains $location
            $approval = [string]$item.Approval
            $enabled = $true
            $disabledAt = $null
            if ($canToggle -and $approval -match '^([0-9A-Fa-f]{2})+$') {
                $bytes = [byte[]]@(for ($index = 0; $index -lt $approval.Length; $index += 2) { [Convert]::ToByte($approval.Substring($index, 2), 16) })
                $enabled = ($bytes[0] -band 1) -eq 0
                if (-not $enabled -and $bytes.Length -ge 12) {
                    $fileTime = [BitConverter]::ToInt64($bytes, 4)
                    if ($fileTime -gt 0) {
                        try {
                            $disabledAt = [DateTime]::FromFileTimeUtc($fileTime).ToLocalTime()
                        }
                        catch {
                            $disabledAt = $null
                        }
                    }
                }
            }
            $risk = Get-MwpSignatureRisk -SignatureStatus ([string]$item.SignatureStatus) -SignerSubject ([string]$item.SignerSubject)
            $scope = if ($location -like 'User*') { 'User' } else { 'Machine' }
            [pscustomobject]@{
                PSTypeName      = 'MWP.StartupItem'
                Id              = '{0}|{1}|{2}' -f $location, [string]$item.UserSid, [string]$item.Name
                Name            = [string]$item.Name
                Location        = $location
                LocationText    = Get-MwpStartupText -Location $location
                Scope           = $scope
                UserSid         = $(if ($scope -eq 'User') { [string]$item.UserSid } else { $null })
                UserName        = $(if ($scope -eq 'User') { [string]$item.UserName } else { 'Wszyscy użytkownicy' })
                Command         = [string]$item.Command
                FilePath        = [string]$item.FilePath
                FileExists      = [bool]$item.FileExists
                Enabled         = $enabled
                CanToggle       = $canToggle
                StateText       = $(if (-not $canToggle) { 'Jednorazowo (RunOnce)' } elseif ($enabled) { 'Włączony' } else { 'Wyłączony' })
                DisabledAt      = $disabledAt
                SignatureStatus = [string]$item.SignatureStatus
                Publisher       = $risk.Publisher
                Risk            = $risk.Risk
                RiskText        = $risk.RiskText
                Source          = [string]$item.Source
            }
        })

    [pscustomobject]@{
        PSTypeName      = 'MWP.StartupItemList'
        Kind            = 'MWP.StartupItemList'
        ComputerName    = [string]$raw.ComputerName
        CollectedAt     = [string]$raw.CollectedAt
        IsAdministrator = $raw.IsAdministrator
        CurrentUserSid  = [string]$raw.CurrentUserSid
        UserMode        = [string]$raw.UserMode
        Users           = @($raw.Users | Where-Object { $null -ne $_ })
        Items           = @($items | Sort-Object -Property Scope, Location, Name)
        Warnings        = @($raw.Warnings | Where-Object { $_ } | ForEach-Object { [string]$_ })
    }
}
