#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy modułu MWP.Power (FAZA 6) z mockiem powercfg.exe: symulator powercfg w zakresie MWP.Remote
    (tam Invoke-MwpOnTarget wykonuje bloki) z komunikatami po polsku i po angielsku, plus mocki
    rejestru (Get-/New-ItemProperty), baterii (Get-CimInstance) i uprawnień (Test-MwpAdmin).
    Sprawdzają: parsowanie po GUID niezależne od języka, odczyt stanu, każdą zmianę z -WhatIf (bez
    wywołania polecenia zmieniającego), log, wpis cofnięcia i cofnięcie, ochronę planu aktywnego
    i planów wbudowanych, raporty, komputer zdalny (mock transportu WinRM) i błąd połączenia.
    System bez zmian: prawdziwy powercfg nie jest wywoływany.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
param()

BeforeDiscovery {
    $languages = @(@{ Language = 'pl' }, @{ Language = 'en' })
}

Describe 'MWP.Power — plany zasilania i ustawienia energii' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        foreach ($name in 'MWP.Core', 'MWP.Remote', 'MWP.Power') {
            Import-Module -Name (Join-Path -Path $root -ChildPath "src\Modules\$name\$name.psd1") -Force
        }
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $name = Get-Variable -Name Kind -ValueOnly -ErrorAction SilentlyContinue
            $path = if ($name -and $name -ne 'Root') { Join-Path -Path $TestDrive -ChildPath $name } else { [string]$TestDrive }
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example    = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local      = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
                IsFallback = $false
            }
        }
        $remoteName = 'PC-TEST1'
        $local = [ordered]@{ schemaVersion = 2; targets = @(@{ name = $remoteName; authentication = 'CurrentUser' }) }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        $balanced = '381b4222-f694-41f0-9685-ff5bb260df2e'
        $high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        $custom = '11111111-2222-3333-4444-555555555555'
        $template = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $video = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'
        $lid = '5ca83367-6e45-459f-a27b-476b1d01c936'

        # Stan symulatora powercfg (plany, wartości ustawień, hibernacja, bateria, język komunikatów).
        function Initialize-FakePowercfg {
            param([string] $Language = 'pl', [switch] $Desktop, [switch] $NoTemplate)
            $script:Fake = @{
                Language    = $Language
                Plans       = [ordered]@{}
                Active      = $balanced
                Values      = @{}
                Hibernate   = 1
                FastStartup = 1
                Battery     = -not $Desktop
                Admin       = $true
                NoTemplate  = [bool]$NoTemplate
                Unavailable = @($(if ($Desktop) { $lid }))
                Fail        = @{}
                Exported    = @{}
                NextGuid    = 0
            }
            $script:Fake.Plans[$balanced] = $(if ($Language -eq 'pl') { 'Zrównoważony' } else { 'Balanced' })
            $script:Fake.Plans[$high] = $(if ($Language -eq 'pl') { 'Wysoka wydajność' } else { 'High performance' })
            $script:Fake.Plans[$custom] = 'Mój plan (praca)'
            foreach ($plan in @($script:Fake.Plans.Keys)) {
                $script:Fake.Values["$plan|$video|AC"] = 600
                $script:Fake.Values["$plan|$video|DC"] = 180
            }
            $script:Calls = New-Object -TypeName System.Collections.Generic.List[string]
        }
        Initialize-FakePowercfg

        # Symulator powercfg.exe. Mock w MWP.Remote (tam wykonują się bloki), a dla bezpieczeństwa także
        # w MWP.Power i w zakresie tego pliku — prawdziwy powercfg nie może zostać wywołany.
        $fakePowercfg = {
            $a = @($args | ForEach-Object { [string]$_ })
            $script:Calls.Add(($a -join ' '))
            $fake = $script:Fake
            $pl = $fake.Language -eq 'pl'
            $verb = $a[0].ToLowerInvariant()
            Set-Variable -Name LASTEXITCODE -Scope Global -Value 0
            $invalid = { Set-Variable -Name LASTEXITCODE -Scope Global -Value 1; 'Invalid Parameters -- try "/?" for help' }
            if ($fake.Fail.ContainsKey($verb)) {
                Set-Variable -Name LASTEXITCODE -Scope Global -Value $fake.Fail[$verb]
                return $(if ($pl) { 'Nie można wykonać operacji. Może wystąpić jeden z następujących problemów.' } else { 'Unable to perform operation. An unexpected error (0x65b) has occured.' })
            }
            $planLabel = if ($pl) { 'Identyfikator GUID schematu zasilania' } else { 'Power Scheme GUID' }
            $resolve = { param($Value) if ($Value -eq 'SCHEME_CURRENT') { $fake.Active } else { $Value.ToLowerInvariant() } }
            switch ($verb) {
                '/list' {
                    ''
                    $(if ($pl) { 'Istniejące schematy zasilania (* Aktywne)' } else { 'Existing Power Schemes (* Active)' })
                    '-----------------------------------'
                    foreach ($guid in $fake.Plans.Keys) {
                        '{0}: {1}  ({2}){3}' -f $planLabel, $guid, $fake.Plans[$guid], $(if ($guid -eq $fake.Active) { ' *' } else { '' })
                    }
                }
                '/qh' {
                    $plan = & $resolve $a[1]
                    if (-not $fake.Plans.Contains($plan)) {
                        Set-Variable -Name LASTEXITCODE -Scope Global -Value 1
                        return 'The power scheme, subgroup or setting specified does not exist.'
                    }
                    '{0}: {1}  ({2})' -f $planLabel, $plan, $fake.Plans[$plan]
                    if ($fake.Unavailable -contains $a[3]) {
                        return
                    }
                    '  Subgroup GUID: {0}  (Grupa)' -f $a[2]
                    '    Power Setting GUID: {0}  (Ustawienie)' -f $a[3]
                    $ac = $fake.Values["$plan|$($a[3])|AC"]
                    $dc = $fake.Values["$plan|$($a[3])|DC"]
                    if ($null -eq $ac) { $ac = 1 }
                    if ($null -eq $dc) { $dc = 1 }
                    if ($pl) {
                        '      Minimalne możliwe ustawienie: 0x00000000'
                        '      Maksymalne możliwe ustawienie: 0xffffffff'
                        '      Przyrost możliwych ustawień: 0x00000001'
                        '      Jednostki możliwych ustawień: Sekundy'
                        '    Bieżący indeks ustawienia zasilania prądem przemiennym: 0x{0:x8}' -f [long]$ac
                        '    Bieżący indeks ustawienia zasilania prądem stałym: 0x{0:x8}' -f [long]$dc
                    }
                    else {
                        '      Minimum Possible Setting: 0x00000000'
                        '      Maximum Possible Setting: 0xffffffff'
                        '      Possible Settings increment: 0x00000001'
                        '    Current AC Power Setting Index: 0x{0:x8}' -f [long]$ac
                        '    Current DC Power Setting Index: 0x{0:x8}' -f [long]$dc
                    }
                }
                '/setactive' {
                    $plan = & $resolve $a[1]
                    if (-not $fake.Plans.Contains($plan)) { return & $invalid }
                    $fake.Active = $plan
                }
                { $_ -in '/setacvalueindex', '/setdcvalueindex' } {
                    $plan = & $resolve $a[1]
                    $source = if ($verb -eq '/setacvalueindex') { 'AC' } else { 'DC' }
                    $fake.Values["$plan|$($a[3])|$source"] = [long]$a[4]
                }
                '/duplicatescheme' {
                    $source = $a[1].ToLowerInvariant()
                    $isTemplate = $source -eq $template -and -not $fake.NoTemplate
                    if (-not $fake.Plans.Contains($source) -and -not $isTemplate) { return & $invalid }
                    $fake.NextGuid++
                    $new = 'aaaaaaaa-0000-0000-0000-{0:d12}' -f $fake.NextGuid
                    $name = if ($isTemplate) { if ($pl) { 'Najwyższa wydajność' } else { 'Ultimate Performance' } } else { $fake.Plans[$source] }
                    $fake.Plans[$new] = $name
                    '{0}: {1}  ({2})' -f $planLabel, $new, $name
                }
                '/changename' {
                    $plan = & $resolve $a[1]
                    if (-not $fake.Plans.Contains($plan)) { return & $invalid }
                    $fake.Plans[$plan] = $a[2]
                }
                '/delete' {
                    $plan = & $resolve $a[1]
                    if (-not $fake.Plans.Contains($plan) -or $plan -eq $fake.Active) { return & $invalid }
                    $fake.Plans.Remove($plan)
                }
                '/export' {
                    $plan = & $resolve $a[2]
                    if (-not $fake.Plans.Contains($plan)) { return & $invalid }
                    [IO.File]::WriteAllText($a[1], ('POW|{0}|{1}' -f $plan, $fake.Plans[$plan]))
                }
                '/import' {
                    $parts = [IO.File]::ReadAllText($a[1]).Split('|')
                    $guid = $a[2].ToLowerInvariant()
                    if ($fake.Plans.Contains($guid)) { return & $invalid }
                    $fake.Plans[$guid] = $parts[2]
                    'Imported Scheme GUID: {0}' -f $guid
                }
                '/hibernate' {
                    $fake.Hibernate = $(if ($a[1] -eq 'on') { 1 } else { 0 })
                }
                '/batteryreport' {
                    if (-not $fake.Battery) {
                        Set-Variable -Name LASTEXITCODE -Scope Global -Value 1
                        return 'Unable to perform operation. The battery report requires a battery.'
                    }
                    [IO.File]::WriteAllText($a[2], '<html>raport baterii</html>')
                    'Battery life report saved to file path {0}' -f $a[2]
                }
                '/energy' {
                    if (-not $fake.Admin) {
                        Set-Variable -Name LASTEXITCODE -Scope Global -Value 1
                        return 'You must be an administrator to run this command.'
                    }
                    [IO.File]::WriteAllText($a[2], '<html>raport energii</html>')
                    Set-Variable -Name LASTEXITCODE -Scope Global -Value 7
                    'Energy efficiency problems were found.'
                }
                default { & $invalid }
            }
        }
        Mock -ModuleName MWP.Remote powercfg.exe $fakePowercfg
        Mock -ModuleName MWP.Power powercfg.exe $fakePowercfg
        Mock powercfg.exe $fakePowercfg
        Mock -ModuleName MWP.Remote Get-ItemProperty -ParameterFilter { $LiteralPath -like 'HKLM:\SYSTEM\CurrentControlSet\Control\*Power' } {
            if ($LiteralPath -like '*Session Manager\Power') {
                if ($null -eq $script:Fake.FastStartup) { return [pscustomobject]@{ Other = 1 } }
                return [pscustomobject]@{ HiberbootEnabled = $script:Fake.FastStartup }
            }
            [pscustomobject]@{ HibernateEnabledDefault = 1; HibernateEnabled = $script:Fake.Hibernate }
        }
        Mock -ModuleName MWP.Remote New-ItemProperty -ParameterFilter { $LiteralPath -like '*Session Manager\Power' } {
            $script:Fake.FastStartup = [int]$Value
        }
        Mock -ModuleName MWP.Remote Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_Battery' } {
            if ($script:Fake.Battery) { [pscustomobject]@{ Name = 'Bateria' } }
        }
        Mock -ModuleName MWP.Power Test-MwpAdmin { $script:Fake.Admin }

        $context = New-MwpExecutionContext
        function Get-Call {
            param([string] $Verb)
            @($script:Calls | Where-Object { $_ -like "$Verb*" })
        }
    }

    AfterAll {
        Remove-Module -Name MWP.Power, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Initialize-FakePowercfg
    }

    Context 'parsowanie wyniku powercfg (niezależne od języka)' {
        It 'lista planów, plan aktywny i wartości ustawień są takie same po polsku i po angielsku' {
            $results = foreach ($language in 'pl', 'en') {
                Initialize-FakePowercfg -Language $language
                (Get-MwpPowerStatus -Context $context).Data
            }
            foreach ($status in $results) {
                @($status.Plans).Count | Should -Be 3
                $status.ActivePlan.Guid | Should -Be $balanced
                ($status.Settings | Where-Object Id -eq 'MonitorTimeout').Ac | Should -Be 600
                ($status.Settings | Where-Object Id -eq 'MonitorTimeout').Dc | Should -Be 180
            }
            ($results[0].Plans | Where-Object Guid -eq $custom).Name | Should -Be 'Mój plan (praca)'
            $results[0].ActivePlan.Name | Should -Be 'Zrównoważony'
            $results[1].ActivePlan.Name | Should -Be 'Balanced'
        }

        It 'linia planu z nazwą zawierającą nawiasy i bez gwiazdki' {
            $plans = InModuleScope MWP.Power {
                ConvertFrom-MwpPowercfgOutput -As List -Line @(
                    'Existing Power Schemes (* Active)'
                    'Power Scheme GUID: 381B4222-F694-41F0-9685-FF5BB260DF2E  (Balanced) *'
                    'Identyfikator GUID schematu zasilania: 11111111-2222-3333-4444-555555555555  (Mój (nowy) plan)'
                )
            }
            @($plans).Count | Should -Be 2
            $plans[0].Guid | Should -Be '381b4222-f694-41f0-9685-ff5bb260df2e'
            $plans[0].IsActive | Should -BeTrue
            $plans[1].Name | Should -Be 'Mój (nowy) plan'
            $plans[1].IsActive | Should -BeFalse
        }

        It 'zapytanie bez wartości (ustawienie ukryte lub niedostępne) daje Available = $false' {
            $value = InModuleScope MWP.Power { ConvertFrom-MwpPowercfgOutput -As Query -Line @('Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)', '  GUID Alias: SCHEME_BALANCED') }
            $value.Available | Should -BeFalse
        }

        It 'odczyt używa /qh (ustawienia ukryte) i GUID-ów, nie aliasów nazw' {
            $null = Get-MwpPowerStatus -Context $context
            @(Get-Call '/qh').Count | Should -Be 6
            Get-Call '/qh' | Should -Contain "/qh SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 $video"
        }
    }

    Context 'Get-MwpPowerStatus' {
        It 'zwraca hibernację, szybkie uruchamianie, baterię i teksty wartości' {
            $status = (Get-MwpPowerStatus -Context $context).Data
            $status.Hibernate | Should -BeTrue
            $status.FastStartup | Should -BeTrue
            $status.HasBattery | Should -BeTrue
            ($status.Settings | Where-Object Id -eq 'MonitorTimeout').AcText | Should -Be '10 min'
            ($status.Settings | Where-Object Id -eq 'LidAction').AcText | Should -Be 'Uśpij'
        }

        It 'komputer stacjonarny: brak baterii i niedostępna pokrywa' {
            Initialize-FakePowercfg -Desktop
            $status = (Get-MwpPowerStatus -Context $context).Data
            $status.HasBattery | Should -BeFalse
            ($status.Settings | Where-Object Id -eq 'LidAction').Available | Should -BeFalse
            (Set-MwpPowerSetting -Setting LidAction -PowerSource AC -Value 0 -Context $context).Message | Should -Match 'niedostępne'
        }

        It 'błąd powercfg /list daje wynik z błędem, bez wyjątku' {
            $script:Fake.Fail['/list'] = 1
            $result = Get-MwpPowerStatus -Context $context
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'kodem 1'
        }

        It '-AsOperation startuje operację w tle z blokiem powercfg, a Resolve-MwpPowerStatus parsuje surowy wynik' {
            Mock -ModuleName MWP.Power Start-MwpOperation { [pscustomobject]@{ PSTypeName = 'MWP.Operation'; Operation = $Operation; Arguments = $ArgumentList } }
            $operation = Get-MwpPowerStatus -Context $context -AsOperation
            $operation.Operation | Should -Be 'Power.Status'
            $json = InModuleScope MWP.Remote -Parameters @{ Request = [string]$operation.Arguments[0] } {
                param($Request)
                $text = (& (Get-Module -Name MWP.Power) { Get-MwpPowerScript -Name Powercfg }).ToString()
                & ((Get-Module -Name MWP.Remote).NewBoundScriptBlock([scriptblock]::Create($text))) $Request
            }
            $status = Resolve-MwpPowerStatus -Data $json
            $status.ActivePlan.Guid | Should -Be $balanced
            $status.HasBattery | Should -BeTrue
        }

        It 'widok widgetu pokazuje plan aktywny i czasy AC/DC' {
            $view = ConvertTo-MwpPowerStatusView -Data (Get-MwpPowerStatus -Context $context)
            $view.PSObject.TypeNames | Should -Contain 'MWP.WidgetView'
            $view.Summary | Should -Match 'Zrównoważony'
            ($view.Sections[1].Items | Where-Object Label -eq 'Wyłącz ekran po').Value | Should -Be 'sieć 10 min · bateria 3 min'
            ConvertTo-MwpPowerStatusView -Data $null | Should -BeNullOrEmpty
        }
    }

    Context 'widget Dashboardu (D-053)' {
        It 'widok „Zasilanie”: sekcje z parametru Sections; bez parametru wszystkie (widgety sprzed D-053)' {
            $data = (Get-MwpPowerStatus -Context $context).Data
            @((ConvertTo-MwpPowerStatusView -Data $data -WidgetParameters @{ Sections = @('Plan') }).Sections | ForEach-Object Title) | Should -Be @('Plan zasilania')
            @((ConvertTo-MwpPowerStatusView -Data $data).Sections).Count | Should -Be 3
        }
    }

    Context 'aktywny plan' {
        It '-WhatIf: podgląd z nazwą komputera, bez /setactive' {
            $result = Set-MwpActivePowerPlan -Guid $high -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue
            $result.Changed | Should -BeFalse
            $result.Message | Should -Match 'Wysoka wydajność'
            Get-Call '/setactive' | Should -BeNullOrEmpty
        }

        It 'przełącza plan, loguje i cofa (Invoke-MwpUndo przywraca poprzedni plan)' {
            $result = Set-MwpActivePowerPlan -Guid $high -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.Changed | Should -BeTrue
            $script:Fake.Active | Should -Be $high
            $log = Get-ChildItem -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Logs') -Filter '*.log' | Get-Content -Raw -Encoding UTF8
            $log | Should -Match '"operation":"Power.SetActivePlan"'

            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            $script:Fake.Active | Should -Be $balanced
        }

        It 'plan już aktywny: bez zmian; nieznany GUID: błąd' {
            (Set-MwpActivePowerPlan -Guid $balanced -Context $context -Confirm:$false).Changed | Should -BeFalse
            (Set-MwpActivePowerPlan -Guid '99999999-9999-9999-9999-999999999999' -Context $context -Confirm:$false).Success | Should -BeFalse
            Get-Call '/setactive' | Should -BeNullOrEmpty
        }
    }

    Context 'ustawienia AC/DC' {
        It '-WhatIf: podgląd bez /setacvalueindex' {
            $result = Set-MwpPowerSetting -Setting MonitorTimeout -PowerSource AC -Value 900 -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue
            $result.Before | Should -Be '10 min'
            $result.After | Should -Be '15 min'
            Get-Call '/setacvalueindex' | Should -BeNullOrEmpty
        }

        It 'zmienia wartość DC po GUID-ach, stosuje plan aktywny i cofa' {
            $result = Set-MwpPowerSetting -Setting MonitorTimeout -PowerSource DC -Value 300 -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            Get-Call '/setdcvalueindex' | Should -Be "/setdcvalueindex $balanced 7516b95f-f776-4464-8c53-06167f40cc99 $video 300"
            Get-Call '/setactive' | Should -Be "/setactive $balanced"
            $script:Fake.Values["$balanced|$video|DC"] | Should -Be 300

            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            $script:Fake.Values["$balanced|$video|DC"] | Should -Be 180
        }

        It 'zmiana w planie nieaktywnym (PlanGuid) nie wywołuje /setactive' {
            $result = Set-MwpPowerSetting -Setting MonitorTimeout -PowerSource AC -Value 0 -PlanGuid $custom -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.After | Should -Be 'Nigdy'
            $script:Fake.Values["$custom|$video|AC"] | Should -Be 0
            Get-Call '/setactive' | Should -BeNullOrEmpty
        }

        It 'akcja spoza zakresu i ta sama wartość' {
            (Set-MwpPowerSetting -Setting LidAction -PowerSource AC -Value 4 -Context $context).Success | Should -BeFalse
            (Set-MwpPowerSetting -Setting MonitorTimeout -PowerSource AC -Value 600 -Context $context -Confirm:$false).Changed | Should -BeFalse
            Get-Call '/setacvalueindex' | Should -BeNullOrEmpty
        }

        It 'błąd powercfg przy zmianie: wynik z błędem i bez wpisu cofnięcia' {
            $script:Fake.Fail['/setacvalueindex'] = 87
            $result = Set-MwpPowerSetting -Setting SleepTimeout -PowerSource AC -Value 60 -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'kodem 87'
            $result.UndoId | Should -BeNullOrEmpty
            Get-Call '/setactive' | Should -BeNullOrEmpty
        }
    }

    Context 'duplikowanie, „Najwyższa wydajność”, zmiana nazwy, import i usuwanie' {
        It 'Add-MwpUltimatePowerPlan: -WhatIf bez /duplicatescheme' {
            $result = Add-MwpUltimatePowerPlan -Context $context -WhatIf
            $result.IsPreview | Should -BeTrue
            Get-Call '/duplicatescheme' | Should -BeNullOrEmpty
        }

        It 'Add-MwpUltimatePowerPlan duplikuje szablon e9a42b02-…, nadaje nazwę, a cofnięcie usuwa kopię' -ForEach $languages {
            Initialize-FakePowercfg -Language $Language
            $result = Add-MwpUltimatePowerPlan -Name 'Turbo' -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            Get-Call '/duplicatescheme' | Should -Be "/duplicatescheme $template"
            $new = $result.Data.Guid
            $new | Should -Be 'aaaaaaaa-0000-0000-0000-000000000001'
            $script:Fake.Plans[$new] | Should -Be 'Turbo'
            $script:Fake.Active | Should -Be $balanced

            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            $script:Fake.Plans.Contains($new) | Should -BeFalse
        }

        It 'brak szablonu na komputerze: czytelny błąd' {
            Initialize-FakePowercfg -NoTemplate
            $result = Add-MwpUltimatePowerPlan -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'nowoczesnego wstrzymania'
        }

        It 'Copy-MwpPowerPlan kopiuje plan z listy; nieznany plan to błąd' {
            $result = Copy-MwpPowerPlan -Guid $custom -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            @($script:Fake.Plans.Keys).Count | Should -Be 4
            (Copy-MwpPowerPlan -Guid '99999999-9999-9999-9999-999999999999' -Context $context -Confirm:$false).Success | Should -BeFalse
        }

        It 'Rename-MwpPowerPlan zmienia nazwę (argument osobno, bez sklejania) i cofa' {
            (Rename-MwpPowerPlan -Guid $custom -Name 'Nowa nazwa' -Context $context -WhatIf).IsPreview | Should -BeTrue
            Get-Call '/changename' | Should -BeNullOrEmpty
            $result = Rename-MwpPowerPlan -Guid $custom -Name 'Nowa nazwa' -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $script:Fake.Plans[$custom] | Should -Be 'Nowa nazwa'
            $null = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $script:Fake.Plans[$custom] | Should -Be 'Mój plan (praca)'
        }

        It 'nazwa z cudzysłowem jest odrzucana przez walidację parametru' {
            { Rename-MwpPowerPlan -Guid $custom -Name 'a"b' -Context $context -Confirm:$false } | Should -Throw
        }

        It 'Remove-MwpPowerPlan odmawia usunięcia planu aktywnego i planu wbudowanego' {
            $script:Fake.Active = $custom
            $active = Remove-MwpPowerPlan -Guid $custom -Context $context -Confirm:$false
            $active.Success | Should -BeFalse
            $active.Message | Should -Match 'aktywny'
            $protected = Remove-MwpPowerPlan -Guid $high -Context $context -Confirm:$false
            $protected.Success | Should -BeFalse
            $protected.Message | Should -Match 'liście ochronnej'
            Get-Call '/delete' | Should -BeNullOrEmpty
        }

        It 'Remove-MwpPowerPlan: -WhatIf bez usuwania; usunięcie po eksporcie, cofnięcie importuje plan z tym samym GUID' {
            (Remove-MwpPowerPlan -Guid $custom -Context $context -WhatIf).IsPreview | Should -BeTrue
            Get-Call '/delete' | Should -BeNullOrEmpty

            $result = Remove-MwpPowerPlan -Guid $custom -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $script:Calls.IndexOf([string]@(Get-Call '/export')[0]) | Should -BeLessThan $script:Calls.IndexOf([string]@(Get-Call '/delete')[0])
            $script:Fake.Plans.Contains($custom) | Should -BeFalse

            $undo = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $undo.Success | Should -BeTrue -Because $undo.Message
            $script:Fake.Plans[$custom] | Should -Be 'Mój plan (praca)'
        }

        It 'Remove-MwpPowerPlan nie usuwa planu, gdy eksport (kopia do cofnięcia) się nie powiódł' {
            $script:Fake.Fail['/export'] = 1
            $result = Remove-MwpPowerPlan -Guid $custom -Context $context -Confirm:$false
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'kopii do cofnięcia'
            Get-Call '/delete' | Should -BeNullOrEmpty
        }

        It 'Import-MwpPowerPlan z lokalnego pliku; istniejący GUID jest odrzucany' {
            $file = Join-Path -Path $TestDrive -ChildPath 'plan.pow'
            [IO.File]::WriteAllText($file, 'POW|x|Plan z pliku')
            $guid = '22222222-3333-4444-5555-666666666666'
            $result = Import-MwpPowerPlan -Path $file -Guid $guid -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $script:Fake.Plans[$guid] | Should -Be 'Plan z pliku'
            (Import-MwpPowerPlan -Path $file -Guid $guid -Context $context -Confirm:$false).Message | Should -Match 'już istnieje'
        }
    }

    Context 'hibernacja i szybkie uruchamianie' {
        It 'bez uprawnień administratora: błąd przed jakąkolwiek zmianą' {
            $script:Fake.Admin = $false
            (Set-MwpHibernation -Enabled $false -Context $context -Confirm:$false).Message | Should -Match 'administratora'
            (Set-MwpFastStartup -Enabled $false -Context $context -Confirm:$false).Message | Should -Match 'administratora'
            Get-Call '/hibernate' | Should -BeNullOrEmpty
            Should -Invoke New-ItemProperty -ModuleName MWP.Remote -Times 0 -Exactly
        }

        It 'Set-MwpHibernation: -WhatIf bez zmiany, zmiana /hibernate off i cofnięcie /hibernate on' {
            (Set-MwpHibernation -Enabled $false -Context $context -WhatIf).IsPreview | Should -BeTrue
            Get-Call '/hibernate' | Should -BeNullOrEmpty
            $result = Set-MwpHibernation -Enabled $false -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $script:Fake.Hibernate | Should -Be 0
            $null = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            Get-Call '/hibernate' | Should -Be @('/hibernate off', '/hibernate on')
        }

        It 'Set-MwpFastStartup: -WhatIf bez zapisu, zapis HiberbootEnabled = 0 i cofnięcie' {
            (Set-MwpFastStartup -Enabled $false -Context $context -WhatIf).IsPreview | Should -BeTrue
            Should -Invoke New-ItemProperty -ModuleName MWP.Remote -Times 0 -Exactly
            $result = Set-MwpFastStartup -Enabled $false -Context $context -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $script:Fake.FastStartup | Should -Be 0
            $null = Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false
            $script:Fake.FastStartup | Should -Be 1
        }

        It 'brak wartości HiberbootEnabled: cofnięcie przywraca wartość domyślną (włączone)' {
            $script:Fake.FastStartup = $null
            $result = Set-MwpFastStartup -Enabled $false -Context $context -Confirm:$false
            $result.Before | Should -Match 'domyślnie włączone'
            $entry = Get-MwpUndoEntry -Id $result.UndoId
            $entry.UndoParameters['Enabled'] | Should -BeTrue
        }

        It 'włączenie szybkiego uruchamiania przy wyłączonej hibernacji ostrzega w komunikacie' {
            $script:Fake.Hibernate = 0
            $script:Fake.FastStartup = 0
            (Set-MwpFastStartup -Enabled $true -Context $context -Confirm:$false).Message | Should -Match 'hibernacja jest wyłączona'
        }
    }

    Context 'raporty batteryreport i energy' {
        It 'raport baterii powstaje na komputerze docelowym, wraca jako treść i zapisuje się w folderze' {
            $report = New-MwpPowerReport -Kind Battery -Context $context
            $report.Success | Should -BeTrue -Because $report.Message
            $folder = Join-Path -Path $TestDrive -ChildPath 'raporty'
            $saved = Save-MwpPowerReport -Report $report -Directory $folder
            $saved.Success | Should -BeTrue -Because $saved.Message
            $saved.Data.Path | Should -Match 'localhost-battery-report-\d{8}-\d{6}\.html$'
            [IO.File]::ReadAllText($saved.Data.Path) | Should -Be '<html>raport baterii</html>'
            @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Filter 'mwp-report-*' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-1) }).Count | Should -Be 0
        }

        It 'Save-MwpPowerReport -WhatIf nie zapisuje; domyślny folder to reports w katalogu danych' {
            $report = New-MwpPowerReport -Kind Battery -Context $context
            $preview = Save-MwpPowerReport -Report $report -WhatIf
            $preview.IsPreview | Should -BeTrue
            $preview.After | Should -BeLike (Join-Path -Path $TestDrive -ChildPath 'reports\*')
            Test-Path -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'reports') | Should -BeFalse
        }

        It 'raport energii z niezerowym kodem (wykryte problemy) jest sukcesem; czas pomiaru w argumentach' {
            $report = New-MwpPowerReport -Kind Energy -DurationSeconds 10 -Context $context
            $report.Success | Should -BeTrue -Because $report.Message
            $report.Message | Should -Match 'kod 7'
            @(Get-Call '/energy')[0] | Should -Match '/duration 10$'
        }

        It 'błędy: brak baterii, brak uprawnień do raportu energii — komunikat z podpowiedzią' {
            Initialize-FakePowercfg -Desktop
            (New-MwpPowerReport -Kind Battery -Context $context).Message | Should -Match 'z baterią'
            $script:Fake.Admin = $false
            $energy = New-MwpPowerReport -Kind Energy -Context $context
            $energy.Success | Should -BeFalse
            $energy.Message | Should -Match 'administratora'
            (Save-MwpPowerReport -Report $energy).Success | Should -BeFalse
        }

        It 'Open-MwpPowerReport odrzuca plik, którego nie ma, albo inny niż .html' {
            (Open-MwpPowerReport -Path (Join-Path -Path $TestDrive -ChildPath 'brak.html')).Success | Should -BeFalse
            $text = Join-Path -Path $TestDrive -ChildPath 'plik.txt'
            Set-Content -LiteralPath $text -Value 'x'
            (Open-MwpPowerReport -Path $text).Success | Should -BeFalse
        }
    }

    Context 'komputer zdalny (D-019)' {
        BeforeEach {
            Mock -ModuleName MWP.Remote Remove-MwpPSSession { }
            Mock -ModuleName MWP.Remote New-MwpPSSession { [pscustomobject]@{ ComputerName = $ComputerName; State = 'Opened' } }
            # „Zdalne” wykonanie: blok związany z zakresem MWP.Remote (tam działają mocki powercfg, rejestru i CIM).
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand {
                $bound = (Get-Module -Name MWP.Remote).NewBoundScriptBlock($ScriptBlock)
                [pscustomobject]@{ Output = @(& $bound @ArgumentList); Errors = @() }
            }
            $remote = New-MwpExecutionContext -ComputerName $remoteName
        }

        It 'odczyt i zmiana przez sesję komputera zdalnego; log i wynik z jego nazwą' {
            (Get-MwpPowerStatus -Context $remote).Data.ActivePlan.Guid | Should -Be $balanced
            $result = Set-MwpActivePowerPlan -Guid $high -Context $remote -Confirm:$false
            $result.Success | Should -BeTrue -Because $result.Message
            $result.ComputerName | Should -Be $remoteName
            (Get-MwpUndoEntry -Id $result.UndoId).ComputerName | Should -Be $remoteName
            Should -Invoke Test-MwpAdmin -ModuleName MWP.Power -Times 0 -Exactly
            $log = Get-ChildItem -LiteralPath (Join-Path -Path $TestDrive -ChildPath 'Logs') -Filter '*.log' | Get-Content -Raw -Encoding UTF8
            $log | Should -Match ('"computer":"{0}","source":"MWP.Power","operation":"Power.SetActivePlan"' -f $remoteName)
        }

        It 'cofnięcie zmiany zdalnej wymaga kontekstu tego komputera' {
            $result = Set-MwpPowerSetting -Setting SleepTimeout -PowerSource AC -Value 60 -Context $remote -Confirm:$false
            (Invoke-MwpUndo -Id $result.UndoId -Context $context -Confirm:$false).Success | Should -BeFalse
            (Invoke-MwpUndo -Id $result.UndoId -Context $remote -Confirm:$false).Success | Should -BeTrue
        }

        It 'uprawnienia administratora sprawdzane na komputerze zdalnym (blok w sesji)' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand -ParameterFilter { $ScriptBlock.ToString() -match 'IsInRole' -and $ScriptBlock.ToString() -notmatch 'powercfg' } {
                [pscustomobject]@{ Output = @($true); Errors = @() }
            }
            $result = Set-MwpHibernation -Enabled $false -Context $remote -WhatIf
            $result.IsPreview | Should -BeTrue -Because $result.Message
            Should -Invoke Invoke-MwpSessionCommand -ModuleName MWP.Remote -Times 1 -Exactly -ParameterFilter { $ScriptBlock.ToString() -notmatch 'powercfg' }
        }

        It 'utrata połączenia: wynik z błędem dla tej instancji, bez wyjątku, i bez zmiany' {
            Mock -ModuleName MWP.Remote Invoke-MwpSessionCommand { throw (New-Object -TypeName Management.Automation.Remoting.PSRemotingTransportException -ArgumentList 'Połączenie zerwane') }
            $result = Set-MwpActivePowerPlan -Guid $high -Context $remote -Confirm:$false
            $result.Success | Should -BeFalse
            $result.ComputerName | Should -Be $remoteName
            $remote.Connection.State | Should -Be 'Disconnected'
            $script:Fake.Active | Should -Be $balanced
            (Get-MwpPowerStatus -Context $context).Success | Should -BeTrue
        }
    }

    Context 'kontrakt modułu i bloki komputera docelowego' {
        It 'kontrakt jest poprawny: RemoteTarget, tryby z widgetem i widget PowerStatus' {
            $definition = Get-MwpModuleDefinition -Name 'MWP.Power'
            $definition.IsValid | Should -BeTrue -Because ($definition.Errors -join ' ')
            $definition.Capabilities | Should -Contain 'RemoteTarget'
            $definition.SupportedPresentationModes | Should -Contain 'DashboardWidget'
            @(Get-MwpWidgetDefinition | Where-Object { $_.ModuleId -eq 'Power' -and $_.WidgetId -eq 'PowerStatus' }).Count | Should -Be 1
        }

        It 'bloki nie używają funkcji MWP ani poleceń spoza Windows PowerShell 5.1, a powercfg dostaje argumenty jako tablicę' {
            foreach ($name in 'Powercfg', 'FastStartup', 'ExportPlan', 'ImportPlan', 'Report') {
                $block = InModuleScope MWP.Power -Parameters @{ Name = $name } { param($Name) Get-MwpPowerScript -Name $Name }
                $commands = @($block.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
                @($commands | Where-Object { $_ -match '-Mwp' }) | Should -BeNullOrEmpty -Because $name
                $block.ToString() | Should -Not -Match 'Invoke-Expression|\$using:'
            }
        }

        It 'lista ochronna zawiera trzy plany wbudowane (PowerPlan)' {
            @(Get-MwpProtectedItem -Category PowerPlan).Count | Should -Be 3
            Test-MwpProtectedItem -Category PowerPlan -Name $balanced | Should -BeTrue
            Test-MwpProtectedItem -Category PowerPlan -Name $custom | Should -BeFalse
        }
    }
}
