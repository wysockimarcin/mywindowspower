# Ustawienia PSScriptAnalyzer dla mywindowspower.
# Uruchamianie: .\tests\Invoke-Checks.ps1 (albo Invoke-ScriptAnalyzer -Settings .\PSScriptAnalyzerSettings.psd1).
# Kod musi działać w Windows PowerShell 5.1 (wymaganie podstawowe) i PowerShell 7.x (D-002, D-009).
@{
    # Błędy i ostrzeżenia powodują niepowodzenie sprawdzenia.
    Severity            = @('Error', 'Warning')

    # Reguły domyślne działają zawsze; poniższe są dodatkowo skonfigurowane.
    IncludeDefaultRules = $true

    Rules               = @{
        # Składnia dostępna w obu wersjach (np. brak ??, ?., operatora trójargumentowego w 5.1).
        PSUseCompatibleSyntax      = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }

        # Polecenia i typy dostępne w Windows PowerShell 5.1 i PowerShell 7 na Windows.
        # Profile pochodzą z PSScriptAnalyzer (Windows 10 Pro 1809 / 5.1 oraz PowerShell 7.0);
        # nowszych profili dla Windows 11 PSScriptAnalyzer nie dostarcza.
        PSUseCompatibleCommands    = @{
            Enable         = $true
            TargetProfiles = @(
                'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
            )
            # Profile znają tylko wbudowanego Pestera 3.4, więc składnia Pestera 5+ byłaby
            # fałszywie zgłaszana. Get-Verb istnieje w 5.1, ale brakuje go w profilu.
            IgnoreCommands = @(
                'Describe', 'Context', 'It', 'Should', 'Mock',
                'BeforeDiscovery', 'BeforeAll', 'AfterAll', 'BeforeEach', 'AfterEach',
                'Invoke-Pester', 'New-PesterConfiguration', 'InModuleScope',
                'Get-Verb'
            )
        }
        PSUseCompatibleTypes       = @{
            Enable         = $true
            TargetProfiles = @(
                'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
            )
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        PSUseConsistentWhitespace  = @{
            Enable          = $true
            CheckOpenBrace  = $true
            CheckOpenParen  = $true
            CheckOperator   = $false
            CheckSeparator  = $true
            CheckInnerBrace = $true
        }
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
    }
}
