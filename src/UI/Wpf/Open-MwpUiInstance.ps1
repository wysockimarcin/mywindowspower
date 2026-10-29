function Open-MwpUiInstance {
    <#
    .SYNOPSIS
        Otwiera nową instancję modułu dla wybranego komputera i pokazuje ją w oknie głównym albo w osobnym oknie.

    .DESCRIPTION
        Host jest fabryką instancji (D-035): New-MwpModuleInstance tworzy instancję z własnym
        kontekstem wykonania, Initialize-MwpModuleInstance importuje moduł (raz na proces). Bez
        -Selection pokazuje okno wyboru komputera i trybu (Show-MwpTargetPicker). Widok instancji jest
        tworzony osobno dla każdej instancji (Views\Instance.xaml), więc dwie instancje tego samego
        modułu dla różnych komputerów mają niezależne widoki i stan. Połączenie z komputerem zdalnym
        (opcja w oknie wyboru) działa w tle (Connect-MwpUiInstance).

    .PARAMETER Definition
        Definicja modułu.

    .PARAMETER Selection
        Wybór z Show-MwpTargetPicker (ComputerName, Mode, Connect).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Definition,

        [AllowNull()]
        [object] $Selection,

        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    if ($null -eq $Selection) {
        $Selection = Show-MwpTargetPicker -Definition $Definition -Owner $Owner
        if ($null -eq $Selection) {
            return
        }
    }

    $instance = New-MwpModuleInstance -ModuleId $Definition.Id -ComputerName $Selection.ComputerName
    $initialization = Initialize-MwpModuleInstance -Instance $instance
    if (-not $initialization.Success) {
        $null = Close-MwpModuleInstance -Instance $instance
        Show-MwpMessage -Text $initialization.Message -Kind Error -Owner $Owner
        return
    }

    $entry = @{
        Id          = $instance.Id
        Instance    = $instance
        Definition  = $Definition
        View        = Import-MwpXaml -Path (Join-Path -Path $ui.UiRoot -ChildPath 'Views\Instance.xaml')
        Window      = $null
        Placement   = 'Embedded'
        Busy        = 0
        Reattaching = $false
        Message     = $null
        ModuleView  = $null
        ViewInfo    = $null
    }
    $ui.Instances[$instance.Id] = $entry
    Initialize-MwpInstanceView -Entry $entry
    Update-MwpNavigation

    if ($Selection.Mode -eq 'SeparateWindow') {
        Move-MwpUiInstance -Entry $entry -Placement SeparateWindow
    }
    else {
        Show-MwpView -Key ('instance:' + $instance.Id)
    }
    if ($instance.Context.Mode -eq 'Remote') {
        # Bez „Połącz od razu” instancja i tak łączy się w tle, gdy hasło komputera jest już w pamięci
        # procesu (D-052): operacje modułu działają, więc stan „Rozłączono” wprowadzałby w błąd.
        Connect-MwpUiInstance -Entry $entry -Owner $Owner -Automatic:(-not $Selection.Connect)
    }
}
