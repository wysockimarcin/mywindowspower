function Resolve-MwpCleanupRoot {
    <#
    .SYNOPSIS
        Rozwija katalogi główne kategorii dla komputera docelowego i ocenia, czy wolno je przetwarzać.

    .DESCRIPTION
        Czysta funkcja (na hoście). Tokeny {SystemRoot} i {ProgramData} — jedna ścieżka; {UserProfile}
        i {RecycleBin} — po jednej ścieżce na wybrany profil (Kosz: na każdy dysk lokalny). Profile
        (D-019, D-047): lokalnie bez -IncludeUserProfiles tylko profil bieżącego konta, z nim — wszystkie;
        zdalnie bez -IncludeUserProfiles żaden (tylko lokalizacje systemowe), z nim — wszystkie profile
        z ProfileList komputera docelowego. Każda ścieżka przechodzi Test-MwpCleanupRoot; lokalizacje
        systemowe i cudzych profili wymagają administratora na komputerze docelowym.
        Wynik: MWP.CleanupRoot z Available i Reason (RequiresAdmin, Rejected, UserProfilesNotSelected).

    .PARAMETER Category
        Kategorie z Get-MwpCleanupCategory.

    .PARAMETER Environment
        MWP.CleanupEnvironment komputera docelowego.

    .PARAMETER Remote
        Komputer docelowy jest zdalny (kontekst w trybie Remote).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Category,

        [Parameter(Mandatory)]
        [object] $Environment,

        [switch] $Remote,

        [switch] $IncludeUserProfiles
    )

    $allProfiles = @($Environment.Profiles | Where-Object { $null -ne $_ -and $_.Path -and $_.Sid })
    $profiles = @(if ($IncludeUserProfiles) {
            $allProfiles
        }
        elseif (-not $Remote) {
            $allProfiles | Where-Object { $_.IsCurrent }
        })
    $isAdministrator = [bool]$Environment.IsAdministrator

    foreach ($item in $Category) {
        $index = 0
        foreach ($definition in @($item.Roots)) {
            $index++
            $paths = @()
            switch ($definition.Token) {
                'SystemRoot' {
                    $paths += [pscustomobject]@{ Path = ([string]$definition.Path).Replace('{SystemRoot}', [string]$Environment.SystemRoot); Sid = ''; UserName = ''; IsCurrent = $false }
                }
                'ProgramData' {
                    $paths += [pscustomobject]@{ Path = ([string]$definition.Path).Replace('{ProgramData}', [string]$Environment.ProgramData); Sid = ''; UserName = ''; IsCurrent = $false }
                }
                'UserProfile' {
                    foreach ($userProfile in $profiles) {
                        $paths += [pscustomobject]@{ Path = ([string]$definition.Path).Replace('{UserProfile}', [string]$userProfile.Path); Sid = [string]$userProfile.Sid; UserName = [string]$userProfile.UserName; IsCurrent = [bool]$userProfile.IsCurrent }
                    }
                }
                'RecycleBin' {
                    foreach ($userProfile in $profiles) {
                        foreach ($drive in @($Environment.FixedDrives | Where-Object { $_ })) {
                            $paths += [pscustomobject]@{ Path = (Join-Path -Path ([string]$drive) -ChildPath ('$Recycle.Bin\' + [string]$userProfile.Sid)); Sid = [string]$userProfile.Sid; UserName = [string]$userProfile.UserName; IsCurrent = [bool]$userProfile.IsCurrent }
                        }
                    }
                }
            }
            if ($definition.Scope -eq 'User' -and $profiles.Count -eq 0) {
                [pscustomobject]@{
                    PSTypeName             = 'MWP.CleanupRoot'
                    Key                    = '{0}|{1}' -f $item.Id, $index
                    CategoryId             = $item.Id
                    Path                   = [string]$definition.Path
                    Scope                  = 'User'
                    Sid                    = ''
                    UserName               = ''
                    RequiresAdmin          = $true
                    Available              = $false
                    Reason                 = 'UserProfilesNotSelected'
                    ReasonText             = Get-MwpCleanupText -Reason 'UserProfilesNotSelected'
                    Recurse                = $definition.Recurse
                    Patterns               = $definition.Patterns
                    Exclude                = $definition.Exclude
                    MinAgeDays             = $definition.MinAgeDays
                    RemoveEmptyDirectories = $definition.RemoveEmptyDirectories
                }
                continue
            }
            foreach ($entry in $paths) {
                $path = ([string]$entry.Path).TrimEnd('\')
                $requiresAdmin = $definition.Scope -eq 'System' -or -not $entry.IsCurrent
                $check = Test-MwpCleanupRoot -Path $path -Environment $Environment
                $reason = if (-not $check.IsValid) { 'Rejected' } elseif ($requiresAdmin -and -not $isAdministrator) { 'RequiresAdmin' } else { '' }
                [pscustomobject]@{
                    PSTypeName             = 'MWP.CleanupRoot'
                    Key                    = '{0}|{1}|{2}' -f $item.Id, $index, $path
                    CategoryId             = $item.Id
                    Path                   = $path
                    Scope                  = $definition.Scope
                    Sid                    = $entry.Sid
                    UserName               = $entry.UserName
                    RequiresAdmin          = $requiresAdmin
                    Available              = -not $reason
                    Reason                 = $reason
                    ReasonText             = $(if ($reason -eq 'Rejected') { $check.Reason } elseif ($reason) { Get-MwpCleanupText -Reason $reason } else { '' })
                    Recurse                = $definition.Recurse
                    Patterns               = $definition.Patterns
                    Exclude                = $definition.Exclude
                    MinAgeDays             = $definition.MinAgeDays
                    RemoveEmptyDirectories = $definition.RemoveEmptyDirectories
                }
            }
        }
    }
}
