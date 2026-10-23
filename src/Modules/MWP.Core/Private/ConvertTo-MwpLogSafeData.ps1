function ConvertTo-MwpLogSafeData {
    <#
    .SYNOPSIS
        Przygotowuje dane do zapisu w logu: ukrywa sekrety i ogranicza głębokość.

    .DESCRIPTION
        Ukrywane są wartości typu SecureString i PSCredential oraz pola, których nazwa wskazuje
        na sekret (hasło, token, klucz API, poświadczenia). W logach nie zapisujemy sekretów (D-015).
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $InputObject,

        [int] $Depth = 0
    )

    $hidden = '[UKRYTE]'
    $sensitiveName = '(?i)(password|passwd|pwd|haslo|hasło|secret|token|credential|apikey|api_key)'

    if ($null -eq $InputObject) {
        return $null
    }
    if ($InputObject -is [securestring] -or $InputObject -is [pscredential]) {
        return $hidden
    }
    if ($Depth -ge 5) {
        return '[...]'
    }
    if ($InputObject -is [string] -or $InputObject -is [bool] -or $InputObject -is [char] -or $InputObject.GetType().IsPrimitive -or
        $InputObject -is [decimal] -or $InputObject -is [guid] -or $InputObject -is [version] -or $InputObject -is [enum]) {
        return $InputObject
    }
    if ($InputObject -is [datetime]) {
        return $InputObject.ToString('o')
    }

    $source = $null
    if ($InputObject -is [Collections.IDictionary]) {
        $source = $InputObject
    }
    elseif ($InputObject -is [Management.Automation.PSCustomObject]) {
        $source = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $source[$property.Name] = $property.Value
        }
    }

    if ($null -ne $source) {
        $table = [ordered]@{}
        foreach ($key in $source.Keys) {
            if ([string]$key -match $sensitiveName) {
                $table[[string]$key] = $hidden
            }
            else {
                $table[[string]$key] = ConvertTo-MwpLogSafeData -InputObject $source[$key] -Depth ($Depth + 1)
            }
        }
        return $table
    }

    if ($InputObject -is [Collections.IEnumerable]) {
        return , @(foreach ($item in $InputObject) {
                ConvertTo-MwpLogSafeData -InputObject $item -Depth ($Depth + 1)
            })
    }

    [string]$InputObject
}
