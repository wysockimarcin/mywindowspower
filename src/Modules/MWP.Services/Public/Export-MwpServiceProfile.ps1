function Export-MwpServiceProfile {
    <#
    .SYNOPSIS
        Zapisuje profil usług (typ uruchomienia i stan każdej usługi) komputera docelowego do pliku JSON.

    .DESCRIPTION
        Profil: { kind = 'MWP.ServiceProfile'; schemaVersion = 1; computerName; createdAt;
        services = [ { name; displayName; startupType; status } ] } (UTF-8 bez BOM). Usługi
        o nieznanym typie uruchomienia są pomijane. Źródło: odczyt z komputera kontekstu albo gotowa
        lista (-ServiceList, np. ostatni odczyt widoku — bez ponownego odczytu). Zapis pliku na
        komputerze, na którym działa host; obsługuje -WhatIf; nie zmienia systemu, więc bez wpisu
        cofnięcia. Profil wczytuje Read-MwpServiceProfile, różnice pokazuje Compare-MwpServiceProfile.

    .PARAMETER Path
        Plik docelowy (.json); istniejący jest zastępowany.

    .PARAMETER ServiceList
        Lista usług (MWP.ServiceList z Get-MwpService albo surowy wynik operacji w tle).

    .PARAMETER Name
        Tylko te usługi (domyślnie wszystkie).

    .EXAMPLE
        Export-MwpServiceProfile -Path "$env:USERPROFILE\Desktop\uslugi.json"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low', DefaultParameterSetName = 'Context')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(ParameterSetName = 'Context')]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [object] $ServiceList,

        [ValidateScript({ Test-MwpServiceName -Name $_ })]
        [string[]] $Name = @()
    )

    $operation = 'Services.ExportProfile'
    if ($PSCmdlet.ParameterSetName -eq 'List') {
        $list = Resolve-MwpServiceList -Data $ServiceList
        if ($null -eq $list) {
            return New-MwpResult -Operation $operation -Target $Path -Success $false -Message 'Brak listy usług do zapisania w profilu.'
        }
    }
    else {
        $read = Get-MwpService -Context $Context -Name $Name
        if (-not $read.Success) {
            return $read
        }
        $list = $read.Data
    }
    $computerName = if ($list.ComputerName) { $list.ComputerName } elseif ($PSCmdlet.ParameterSetName -eq 'Context') { $Context.ComputerName } else { 'localhost' }
    $common = @{ Operation = $operation; Target = $Path; ComputerName = $computerName }
    $services = @($list.Services | Where-Object { $_.StartupType -ne 'Unknown' -and ($Name.Count -eq 0 -or $Name -contains $_.Name) } | Sort-Object -Property Name | ForEach-Object {
            [ordered]@{ name = $_.Name; displayName = $_.DisplayName; startupType = $_.StartupType; status = $_.Status }
        })
    try {
        $fullPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))
    }
    catch {
        return New-MwpResult @common -Success $false -Message ("Niepoprawna ścieżka profilu '{0}': {1}" -f $Path, $_.Exception.Message) -ErrorMessage $_.Exception.Message
    }
    $common.Target = $fullPath

    if (-not $PSCmdlet.ShouldProcess($fullPath, ('Zapis profilu usług komputera {0} ({1} usług)' -f $computerName, $services.Count))) {
        return New-MwpResult @common -Success $true -IsPreview -After $fullPath -Message ("Podgląd: profil {0} usług komputera '{1}' zostanie zapisany do '{2}'." -f $services.Count, $computerName, $fullPath)
    }
    $profileData = [ordered]@{
        kind          = 'MWP.ServiceProfile'
        schemaVersion = 1
        computerName  = $computerName
        createdAt     = (Get-Date).ToString('o')
        services      = $services
    }
    try {
        $folder = Split-Path -Path $fullPath -Parent
        if ($folder -and -not [IO.Directory]::Exists($folder)) {
            $null = [IO.Directory]::CreateDirectory($folder)
        }
        [IO.File]::WriteAllText($fullPath, (ConvertTo-Json -InputObject $profileData -Depth 5), (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false))
    }
    catch {
        $message = "Nie udało się zapisać profilu usług do '{0}': {1}" -f $fullPath, $_.Exception.Message
        Write-MwpLog -Level Warning -Source 'MWP.Services' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message
    }
    $message = "Zapisano profil {0} usług komputera '{1}' do '{2}'." -f $services.Count, $computerName, $fullPath
    Write-MwpLog -Level Info -Source 'MWP.Services' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Path = $fullPath; Count = $services.Count }
    New-MwpResult @common -Success $true -Changed $true -After $fullPath -Message $message -Data ([ordered]@{ Path = $fullPath; Count = $services.Count })
}
