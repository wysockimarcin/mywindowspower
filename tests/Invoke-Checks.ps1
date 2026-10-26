#Requires -Version 5.1
<#
.SYNOPSIS
    Uruchamia analizę statyczną (PSScriptAnalyzer) i testy (Pester) jednym poleceniem.

.DESCRIPTION
    Analizuje launcher, src\, samples\ i tests\ z ustawieniami z PSScriptAnalyzerSettings.psd1,
    a potem uruchamia testy Pester z katalogu tests\. Katalog główny projektu jest
    wyznaczany względem położenia skryptu, więc można go uruchomić z dowolnego miejsca.
    Działa w Windows PowerShell 5.1 i PowerShell 7.x.

.PARAMETER SkipAnalyzer
    Pomija analizę statyczną.

.PARAMETER SkipTests
    Pomija testy Pester.

.OUTPUTS
    Kod wyjścia 0, gdy analiza nie zgłosiła uwag i testy przeszły; 1 w przeciwnym razie.

.EXAMPLE
    .\tests\Invoke-Checks.ps1
#>
[CmdletBinding()]
param(
    [switch] $SkipAnalyzer,
    [switch] $SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$failed = $false

function Import-RequiredModule {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [version] $MinimumVersion
    )

    $available = Get-Module -Name $Name -ListAvailable |
        Where-Object { $_.Version -ge $MinimumVersion } |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
    if (-not $available) {
        throw ("Brak modułu {0} w wersji {1} lub nowszej. Zainstaluj: Install-Module {0} -MinimumVersion {1} -Scope CurrentUser{2}" -f
            $Name, $MinimumVersion, $(if ($Name -eq 'Pester') { ' -SkipPublisherCheck' } else { '' }))
    }
    # W 5.1 jest też wbudowany Pester 3.4, dlatego wersję wybieramy jawnie.
    Import-Module -Name $available.Path -Force
    $available
}

Write-Output ("PowerShell {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)

if (-not $SkipAnalyzer) {
    $analyzer = Import-RequiredModule -Name 'PSScriptAnalyzer' -MinimumVersion '1.21.0'
    Write-Output ("== PSScriptAnalyzer {0}" -f $analyzer.Version)

    $settings = Join-Path -Path $root -ChildPath 'PSScriptAnalyzerSettings.psd1'
    $targets = @(
        Join-Path -Path $root -ChildPath 'Start-MyWindowsPower.ps1'
        Join-Path -Path $root -ChildPath 'src'
        Join-Path -Path $root -ChildPath 'samples'
        Join-Path -Path $root -ChildPath 'tests'
    ) | Where-Object { Test-Path -LiteralPath $_ }

    $results = @(foreach ($target in $targets) {
            Invoke-ScriptAnalyzer -Path $target -Recurse -Settings $settings
        })

    if ($results.Count -eq 0) {
        Write-Output 'PSScriptAnalyzer: brak uwag.'
    }
    else {
        $results |
            Sort-Object -Property ScriptPath, Line |
            Format-Table -Property Severity, RuleName, ScriptName, Line, Message -AutoSize -Wrap |
            Out-String -Width 200 |
            Write-Output
        Write-Output ("PSScriptAnalyzer: uwagi: {0}." -f $results.Count)
        $failed = $true
    }
}

if (-not $SkipTests) {
    $pester = Import-RequiredModule -Name 'Pester' -MinimumVersion '5.0.0'
    Write-Output ("== Pester {0}" -f $pester.Version)

    $configuration = New-PesterConfiguration
    $configuration.Run.Path = $PSScriptRoot
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'Detailed'

    $result = Invoke-Pester -Configuration $configuration
    if ($result.Result -ne 'Passed') {
        Write-Output ("Pester: niepowodzenie (nieudane testy: {0})." -f $result.FailedCount)
        $failed = $true
    }
    else {
        Write-Output ("Pester: wszystkie testy przeszły ({0})." -f $result.PassedCount)
    }
}

if ($failed) {
    Write-Output 'WYNIK: sprawdzenie NIEUDANE.'
    exit 1
}
Write-Output 'WYNIK: sprawdzenie udane.'
exit 0
