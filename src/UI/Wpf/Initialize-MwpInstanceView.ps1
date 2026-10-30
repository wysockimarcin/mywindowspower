function Initialize-MwpInstanceView {
    <#
    .SYNOPSIS
        Wypełnia i podpina widok instancji modułu (zaślepka): przyciski połączenia, odczyt testowy, notatka, kontekst.

    .DESCRIPTION
        Przyciski mają w Tag identyfikator instancji; obsługa znajduje instancję w stanie powłoki.
        Widok nie wywołuje poleceń systemowych ani WinRM: korzysta z funkcji MWP.Remote przez
        Connect-/Disconnect-MwpUiInstance, Invoke-MwpUiTargetTest i Invoke-MwpUiProbe (D-015, D-019).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $v = $Entry.View.Controls
    $instance = $Entry.Instance
    $context = $instance.Context
    $definition = $Entry.Definition

    $phase = @(Get-MwpAreaCatalog | Where-Object { $_.Id -eq $definition.Id }) | Select-Object -First 1
    $modes = @($definition.SupportedPresentationModes | Where-Object { $_ })
    $v['StubText'].Text = $(if ($modes.Count -eq 0) {
            'Widok-zaślepka hosta: moduł {0} nie ma jeszcze własnego widoku{1}. Instancja działa niezależnie od innych: ma własny kontekst wykonania (komputer {2}), stan połączenia, operacje i stan.' -f
            $definition.ModuleName, $(if ($null -ne $phase) { ' (FAZA {0})' -f $phase.Phase } else { '' }), (Format-MwpTargetLabel -Context $context)
        }
        else {
            'Moduł {0} deklaruje tryby: {1}. Host pokazuje jego instancję w widoku ogólnym (własne widoki modułów z paczek — przyszły kontrakt widoku). Instancja ma własny kontekst wykonania (komputer {2}).' -f
            $definition.ModuleName, ($modes -join ', '), (Format-MwpTargetLabel -Context $context)
        })

    # Własny widok modułu wbudowanego (katalog widoków hosta, D-044) zastępuje zaślepkę i odczyt testowy.
    $moduleView = @(Get-MwpModuleViewCatalog -ModuleId $definition.Id) | Select-Object -First 1
    if ($null -ne $moduleView -and $definition.Source -eq 'BuiltIn') {
        $Entry.ModuleView = Import-MwpXaml -Path (Join-Path -Path $script:MwpUi.UiRoot -ChildPath $moduleView.View)
        $Entry.ViewInfo = $moduleView
        $v['ModuleHost'].Content = $Entry.ModuleView.Root
        $v['ModuleHost'].Visibility = 'Visible'
        $v['GenericPanel'].Visibility = 'Collapsed'
        $v['ProbeButton'].Visibility = 'Collapsed'
    }

    $identity = if ($context.Mode -eq 'Local') { 'konto procesu' } else { '{0}{1}' -f $context.Identity.Authentication, $(if ($context.Identity.UserName) { ' (' + $context.Identity.UserName + ')' } else { '' }) }
    $v['ContextList'].ItemsSource = @(
        [pscustomobject]@{ Key = 'Instancja (Id)'; Value = $instance.Id }
        [pscustomobject]@{ Key = 'Kontekst (Id)'; Value = $context.Id }
        [pscustomobject]@{ Key = 'Moduł'; Value = '{0} {1} ({2})' -f $instance.ModuleName, $instance.ModuleVersion, $definition.Source }
        [pscustomobject]@{ Key = 'Komputer docelowy'; Value = '{0} — {1}' -f (Format-MwpTargetLabel -Context $context -Format Subtitle), $context.DisplayName }
        [pscustomobject]@{ Key = 'Tryb i transport'; Value = '{0}, {1}{2}' -f $context.Mode, $context.Transport, $(if ($context.Mode -eq 'Remote') { ', port {0}{1}' -f $context.Port, $(if ($context.UseSsl) { ', HTTPS' } else { '' }) } else { '' }) }
        [pscustomobject]@{ Key = 'Tożsamość'; Value = $identity }
        [pscustomobject]@{ Key = 'Limity czasu'; Value = 'połączenie {0} s, operacja {1} s' -f $context.Policy.ConnectTimeoutSeconds, $context.Policy.OperationTimeoutSeconds }
        [pscustomobject]@{ Key = 'Utworzono'; Value = $instance.CreatedAt.ToString('yyyy-MM-dd HH:mm:ss') }
    )

    foreach ($name in @('ConnectButton', 'DisconnectButton', 'TestButton', 'ProbeButton', 'DetachButton', 'CloseButton', 'NoteBox')) {
        $v[$name].Tag = $Entry.Id
    }
    $v['ConnectButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Instance.Connect' -Action {
                $entry = $script:MwpUi.Instances[[string]$control.Tag]
                if ($null -ne $entry) { Connect-MwpUiInstance -Entry $entry -Owner (Get-MwpOwnerWindow -Element $control) }
            }
        })
    $v['DisconnectButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Instance.Disconnect' -Action {
                $entry = $script:MwpUi.Instances[[string]$control.Tag]
                if ($null -ne $entry) { Disconnect-MwpUiInstance -Entry $entry }
            }
        })
    $v['TestButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Instance.Test' -Action {
                $entry = $script:MwpUi.Instances[[string]$control.Tag]
                if ($null -ne $entry) { Invoke-MwpUiTargetTest -Entry $entry }
            }
        })
    $v['ProbeButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Instance.Probe' -Action {
                $entry = $script:MwpUi.Instances[[string]$control.Tag]
                if ($null -ne $entry) { Invoke-MwpUiProbe -Entry $entry -Owner (Get-MwpOwnerWindow -Element $control) }
            }
        })
    $v['DetachButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Instance.Placement' -Action {
                $entry = $script:MwpUi.Instances[[string]$control.Tag]
                if ($null -ne $entry) {
                    $placement = if ($entry.Placement -eq 'SeparateWindow') { 'Embedded' } else { 'SeparateWindow' }
                    Move-MwpUiInstance -Entry $entry -Placement $placement
                }
            }
        })
    $v['CloseButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Instance.Close' -Action { Close-MwpUiInstance -Id ([string]$control.Tag) }
        })
    $v['NoteBox'].Add_TextChanged({
            param($control)
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry -and $entry.Instance.Status -ne 'Closed') {
                $entry.Instance.State['Note'] = $control.Text
            }
        })
    if ($null -ne $Entry.ViewInfo) {
        & $Entry.ViewInfo.Initialize -Entry $Entry
    }
    Update-MwpInstanceView -Entry $Entry
}
