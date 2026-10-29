#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Testy warstwy UI zapamiętywania poświadczeń (D-052), bez WPF: wybór źródła hasła przy „Połącz”
    (pamięć procesu, Menedżer poświadczeń, okno), wskaźnik „hasło zapisane / niezapisane”, wznawianie
    widgetów komputera po połączeniu, stan „Wymaga poświadczeń” bez ponowień w tle oraz statyczne
    sprawdzenie okien (pole „Zapamiętaj” domyślnie wyłączone, „Zapomnij hasło”, przełącznik w Ustawieniach).
    Prawdziwy Menedżer poświadczeń nie jest używany (mock warstwy P/Invoke).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Zmienne z bloków BeforeDiscovery/BeforeAll są używane w blokach It (zakresy Pestera).')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingComputerNameHardcoded', '',
    Justification = 'Sztuczne nazwy komputerów testowych (PC-TEST1, PC-HASLO); testy nie łączą się z żadnym komputerem.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification = 'Pomocnicze funkcje testów tworzą tylko obiekty w pamięci.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '',
    Justification = 'Sztuczne hasło testowe; testy nie używają prawdziwych haseł.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '',
    Justification = 'Pomocnicze funkcje testów budują PSCredential ze sztucznego hasła.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
    Justification = 'Funkcje testowe mają sygnaturę kontraktu widgetu, także gdy nie używają wszystkich parametrów.')]
param()

Describe 'MWP.UI — zapamiętane poświadczenia (logika prezentacji)' {
    BeforeAll {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Core\MWP.Core.psd1') -Force
        $remote = Import-Module -Name (Join-Path -Path $root -ChildPath 'src\Modules\MWP.Remote\MWP.Remote.psd1') -Force -PassThru
        Import-Module -Name (Join-Path -Path $root -ChildPath 'src\UI\MWP.UI.psm1') -Force
        Mock -ModuleName MWP.Remote Invoke-MwpCredentialApi { throw 'Testy nie mogą używać prawdziwego Menedżera poświadczeń Windows.' }
        $configDirectory = Join-Path -Path $TestDrive -ChildPath 'config'
        $null = New-Item -ItemType Directory -Path $configDirectory -Force
        Copy-Item -LiteralPath (Join-Path -Path $root -ChildPath 'config\settings.example.json') -Destination (Join-Path -Path $configDirectory -ChildPath 'settings.example.json')
        Mock -ModuleName MWP.Core Get-MwpDataPath {
            $path = Join-Path -Path $TestDrive -ChildPath $Kind
            if (Get-Variable -Name Detailed -ValueOnly -ErrorAction SilentlyContinue) { [pscustomobject]@{ Path = $path; Root = $TestDrive; Configured = ''; IsFallback = $false; Warning = $null } } else { $path }
        }
        Mock -ModuleName MWP.Core Get-MwpConfigPath {
            [pscustomobject]@{
                Example    = Join-Path -Path $TestDrive -ChildPath 'config\settings.example.json'
                Local      = Join-Path -Path $TestDrive -ChildPath 'config\settings.local.json'
                IsFallback = $false
            }
        }
        $local = [ordered]@{ schemaVersion = 2; targets = @(@{ name = 'PC-HASLO' }, @{ name = 'PC-INNY' }, @{ name = 'PC-DOMENA'; authentication = 'CurrentUser' }) }
        ConvertTo-Json -InputObject $local -Depth 5 | Set-Content -LiteralPath (Join-Path -Path $configDirectory -ChildPath 'settings.local.json') -Encoding UTF8

        $secure = New-Object -TypeName Security.SecureString
        'Test-Hasło-Nie-Ujawniać!'.ToCharArray() | ForEach-Object { $secure.AppendChar($_) }
        $credential = New-Object -TypeName Management.Automation.PSCredential -ArgumentList 'PC-HASLO\admin', $secure

        function New-TestInfo {
            param([bool] $Cached = $false, [bool] $Invalid = $false, $Stored = $false, $StoreEnabled = $true, [string] $StoreError)
            [pscustomobject]@{
                PSTypeName = 'MWP.TargetCredentialInfo'; ComputerName = 'PC-HASLO'; Entry = 'MWP:PC-HASLO'; StoreEnabled = $StoreEnabled; Stored = $Stored
                StoredUserName = $(if ($Stored) { 'PC-HASLO\admin' } else { $null }); LastWritten = $(if ($Stored) { [datetime]'2026-10-29 10:00' } else { $null })
                StoreError = $StoreError; Cached = $Cached; Invalid = $Invalid; CachedUserName = $null
            }
        }
        function New-TestState {
            param([bool] $NeedsCredential = $true, [string] $State = 'Disconnected', [bool] $IsRemote = $true)
            [pscustomobject]@{ PSTypeName = 'MWP.UiConnectionState'; State = $State; NeedsCredential = $NeedsCredential; IsRemote = $IsRemote }
        }
        function New-TestWidget {
            param([object] $Context, [string] $Status = 'NeedsCredential', [int] $Refresh = 30)
            @{
                Id = [guid]::NewGuid().ToString(); Removed = $false; Task = $null; Pending = $false; Version = 0; Status = $Status; Message = 'czeka'
                Instance = [pscustomobject]@{ Context = $Context }; Definition = [pscustomobject]@{ Name = 'Test'; DataCommand = 'Get-MwpCredentialUiTestData' }
                Config = @{ refreshSeconds = $Refresh; title = '' }; Parameters = @{}; NextRefresh = [datetime]::MinValue; View = $null
            }
        }
        function global:Get-MwpCredentialUiTestData {
            param($Context, [switch] $AsOperation, $WidgetParameters)
            # Wywołanie zmieniłoby stan widgetu na Error (wyjątek funkcji danych) — test sprawdza, że go nie ma.
            throw 'funkcja danych nie powinna być wywołana'
        }
    }

    AfterAll {
        Clear-MwpTargetCredentialCache
        Remove-Item -Path Function:\Get-MwpCredentialUiTestData -ErrorAction SilentlyContinue
        Remove-Module -Name MWP.UI, MWP.Remote, MWP.Core -Force -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Clear-MwpTargetCredentialCache
    }

    Context 'Get-MwpUiCredentialPlan — skąd wziąć hasło przy „Połącz”' {
        It 'sprawdzone hasło w pamięci procesu: połączenie bez okna (Cache)' {
            (Get-MwpUiCredentialPlan -State (New-TestState) -Info (New-TestInfo -Cached $true -Stored $true)).Action | Should -Be 'Cache'
        }

        It 'wpis w magazynie, nieodrzucony, zapamiętywanie włączone: połączenie bez okna (Store)' {
            (Get-MwpUiCredentialPlan -State (New-TestState) -Info (New-TestInfo -Stored $true)).Action | Should -Be 'Store'
        }

        It 'brak hasła: okno z polem „Zapamiętaj” tylko przy włączonym zapamiętywaniu' {
            $enabled = Get-MwpUiCredentialPlan -State (New-TestState) -Info (New-TestInfo) -UserName 'PC-HASLO\admin'
            $disabled = Get-MwpUiCredentialPlan -State (New-TestState) -Info (New-TestInfo -StoreEnabled $false -Stored $true)

            $enabled.Action | Should -Be 'Dialog'
            $enabled.OfferSave | Should -BeTrue
            $enabled.UserName | Should -Be 'PC-HASLO\admin'
            $disabled.Action | Should -Be 'Dialog'
            $disabled.OfferSave | Should -BeFalse
        }

        It 'zapisane hasło odrzucone w tym uruchomieniu: okno z ostrzeżeniem zamiast ponownej próby' {
            $plan = Get-MwpUiCredentialPlan -State (New-TestState -State 'Unauthorized') -Info (New-TestInfo -Stored $true -Invalid $true)

            $plan.Action | Should -Be 'Dialog'
            $plan.Notice | Should -Match 'odrzucił hasło zapisane'
            $plan.UserName | Should -Be 'PC-HASLO\admin'
        }

        It 'błąd odczytu magazynu: okno z komunikatem błędu' {
            (Get-MwpUiCredentialPlan -State (New-TestState) -Info (New-TestInfo -StoreError 'kod 1312')).Notice | Should -Be 'kod 1312'
        }

        It 'połączenie nie potrzebuje hasła (localhost, poświadczenie w kontekście): None' {
            (Get-MwpUiCredentialPlan -State (New-TestState -IsRemote $false -NeedsCredential $false) -Info $null).Action | Should -Be 'None'
            (Get-MwpUiCredentialPlan -State (New-TestState -NeedsCredential $false -State 'Disconnected') -Info $null).Action | Should -Be 'None'
        }
    }

    Context 'Get-MwpTargetCredentialText — wskaźnik w edytorze komputera' {
        It 'hasło zapisane: konto, data i nazwa wpisu; można zapomnieć' {
            $text = Get-MwpTargetCredentialText -Info (New-TestInfo -Stored $true)

            $text.Text | Should -Match 'zapisane w Menedżerze poświadczeń'
            $text.Text | Should -Match 'PC-HASLO\\admin'
            $text.Text | Should -Match '2026-10-29 10:00'
            $text.Text | Should -Match 'MWP:PC-HASLO'
            $text.Tone | Should -Be 'Success'
            $text.CanForget | Should -BeTrue
        }

        It 'hasło niezapisane: nie ma czego zapomnieć' {
            $text = Get-MwpTargetCredentialText -Info (New-TestInfo)

            $text.Text | Should -Match 'niezapisane'
            $text.CanForget | Should -BeFalse
        }

        It 'hasło tylko w pamięci, odrzucone i wyłączone zapamiętywanie' {
            (Get-MwpTargetCredentialText -Info (New-TestInfo -Cached $true)).CanForget | Should -BeTrue
            (Get-MwpTargetCredentialText -Info (New-TestInfo -Stored $true -Invalid $true)).Tone | Should -Be 'Warning'
            (Get-MwpTargetCredentialText -Info (New-TestInfo -StoreEnabled $false)).Text | Should -Match 'wyłączone w Ustawieniach'
        }
    }

    Context 'stan połączenia i widgety' {
        It 'sprawdzone hasło komputera w pamięci procesu: nowy kontekst nie wymaga poświadczeń' {
            $context = New-MwpExecutionContext -ComputerName 'PC-HASLO'
            (Get-MwpConnectionStateInfo -Context $context).NeedsCredential | Should -BeTrue

            $null = & $remote { param($c) Set-MwpCachedCredential -ComputerName 'PC-HASLO' -Credential $c } $credential

            (Get-MwpConnectionStateInfo -Context $context).NeedsCredential | Should -BeFalse
        }

        It 'hasło wspólne odrzucone: kontekst z kopią poświadczenia znów wymaga poświadczeń' {
            $context = New-MwpExecutionContext -ComputerName 'PC-HASLO'
            $generation = & $remote { param($c) Set-MwpCachedCredential -ComputerName 'PC-HASLO' -Credential $c } $credential
            & $remote { param($ctx, $c, $g) Set-MwpConnectionCredential -Connection $ctx.Connection -Credential $c -Shared $true -Generation $g } $context $credential $generation

            $null = & $remote { param($g) Set-MwpCachedCredentialInvalid -ComputerName 'PC-HASLO' -Generation $g } $generation

            (Get-MwpConnectionStateInfo -Context $context).NeedsCredential | Should -BeTrue
        }

        It 'widget „Wymaga poświadczeń”: bez ponowień w tle przez wiele tyknięć i bez wywołania funkcji danych' {
            $context = New-MwpExecutionContext -ComputerName 'PC-HASLO'
            $generation = & $remote { param($c) Set-MwpCachedCredential -ComputerName 'PC-HASLO' -Credential $c } $credential
            $null = & $remote { param($g) Set-MwpCachedCredentialInvalid -ComputerName 'PC-HASLO' -Generation $g } $generation
            $widget = New-TestWidget -Context $context
            $registry = New-Object -TypeName System.Collections.Generic.List[object]

            $due = foreach ($minute in 1..30) { @(Get-MwpWidgetDue -Widget @($widget) -AutoRefresh $true -Now ((Get-Date).AddMinutes($minute))) }
            $widget.Pending = $true
            $started = Start-MwpWidgetRefresh -Widget $widget -Registry $registry

            @($due).Count | Should -Be 0
            $started | Should -BeFalse
            $widget.Status | Should -Be 'NeedsCredential'
            $registry.Count | Should -Be 0
        }

        It 'po połączeniu wznawia tylko widgety tego komputera czekające na poświadczenia' {
            $same = New-TestWidget -Context (New-MwpExecutionContext -ComputerName 'PC-HASLO')
            $busy = New-TestWidget -Context (New-MwpExecutionContext -ComputerName 'PC-HASLO')
            $busy.Task = 'trwa'
            $ready = New-TestWidget -Context (New-MwpExecutionContext -ComputerName 'PC-HASLO') -Status 'Ready'
            $other = New-TestWidget -Context (New-MwpExecutionContext -ComputerName 'PC-INNY')

            $count = Resume-MwpUiTargetWidget -Widget @($same, $busy, $ready, $other) -ComputerName 'PC-HASLO'

            $count | Should -Be 1
            $same.Pending | Should -BeTrue
            $busy.Pending | Should -BeFalse
            $ready.Pending | Should -BeFalse
            $other.Pending | Should -BeFalse
        }
    }

    Context 'okna (statycznie, bez WPF)' {
        BeforeAll {
            $uiRoot = Join-Path -Path $root -ChildPath 'src\UI'
            $namespace = @{ w = 'http://schemas.microsoft.com/winfx/2006/xaml/presentation'; x = 'http://schemas.microsoft.com/winfx/2006/xaml' }
            function Get-XamlNode {
                param([string] $File, [string] $Name)
                [xml]$document = [IO.File]::ReadAllText((Join-Path -Path $uiRoot -ChildPath $File), [Text.Encoding]::UTF8)
                (Select-Xml -Xml $document -XPath ("//*[@x:Name='{0}']" -f $Name) -Namespace $namespace | Select-Object -First 1).Node
            }
        }

        It 'okno poświadczeń: pole „Zapamiętaj” domyślnie niezaznaczone i ukryte do czasu -OfferSave' {
            $check = Get-XamlNode -File 'Dialogs\Credential.xaml' -Name 'SaveCheck'
            $panel = Get-XamlNode -File 'Dialogs\Credential.xaml' -Name 'SavePanel'

            $check | Should -Not -BeNullOrEmpty
            $check.GetAttribute('IsChecked') | Should -Be 'False'
            $check.GetAttribute('Content') | Should -Match 'Menedżerze poświadczeń Windows'
            $panel.GetAttribute('Visibility') | Should -Be 'Collapsed'
            $panel.InnerXml | Should -Match 'Menedżer poświadczeń'
        }

        It 'edytor komputera: wskaźnik zapisanego hasła i przycisk „Zapomnij hasło”' {
            (Get-XamlNode -File 'Dialogs\TargetEditor.xaml' -Name 'ForgetButton').GetAttribute('Content') | Should -Be 'Zapomnij hasło'
            Get-XamlNode -File 'Dialogs\TargetEditor.xaml' -Name 'CredentialStatusText' | Should -Not -BeNullOrEmpty
        }

        It 'Ustawienia: przełącznik zapamiętywania haseł' {
            (Get-XamlNode -File 'Views\Settings.xaml' -Name 'CredentialStoreCheck').GetAttribute('Content') | Should -Match 'zapamiętywanie haseł'
        }

        It 'Show-MwpCredentialDialog zwraca Save tylko przy -OfferSave i zaznaczonym polu' {
            $text = [IO.File]::ReadAllText((Join-Path -Path $uiRoot -ChildPath 'Wpf\Show-MwpCredentialDialog.ps1'), [Text.Encoding]::UTF8)

            $text | Should -Match "\[bool\]\`$OfferSave -and \[bool\]\`$c\['SaveCheck'\]\.IsChecked"
            $text | Should -Match "\`$c\['SaveCheck'\]\.IsChecked = \`$false"
        }
    }
}
