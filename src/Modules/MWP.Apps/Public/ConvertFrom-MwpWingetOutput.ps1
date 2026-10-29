function ConvertFrom-MwpWingetOutput {
    <#
    .SYNOPSIS
        Zamienia tekst tabeli winget (list, upgrade, search) na obiekty wierszy — niezależnie od języka i szerokości kolumn.

    .DESCRIPTION
        Czysta funkcja (D-050). winget nie ma wyjścia maszynowego dla tych poleceń, więc tabelę czytamy
        po strukturze, nie po słowach nagłówka:
        - tabela = linia z samych kresek, nagłówek = najbliższa niepusta linia nad nią; początki kolumn
          to początki słów nagłówka (pozycje w kolumnach ekranu: znaki szerokie, np. CJK, liczą się
          podwójnie, jak w konsoli);
        - początek kolumny, przed którym w którymś wierszu danych nie ma spacji, nie jest kolumną
          (nagłówek z dwóch słów w innym języku); gdy żaden wiersz go nie przecina, wygrywa podział
          z największą liczbą poprawnych wierszy (Id bez spacji, niepusta wersja);
        - znaczenie kolumn wynika z ich kolejności (podanej w -Column), bo przełączniki poleceń są stałe
          (np. --source winget: Name, Id, Version, [Available|Match]);
        - wiersze kończy pusta linia; linie, w których Id jest puste albo ma spację (np. „25 upgrades
          available.”), są pomijane; kilka tabel (np. pakiety wymagające jawnego wskazania) ma numer Table.
        Linie z wcześniejszymi komunikatami (zgody źródła, ostrzeżenia, wskaźniki postępu) są pomijane.
        Wiersz: wartości kolumn, IsLocalId (Id lokalne winget: ARP\…, MSIX\…), Truncated (wartość ucięta „…”).

    .PARAMETER Line
        Linie wyjścia winget.

    .PARAMETER Column
        Nazwy kolumn w kolejności wyświetlania; pierwsze trzy to Name, Id, Version.

    .EXAMPLE
        ConvertFrom-MwpWingetOutput -Line (winget list --source winget) -Column Name, Id, Version, Available
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]] $Line,

        [ValidateNotNullOrEmpty()]
        [string[]] $Column = @('Name', 'Id', 'Version', 'Available', 'Source')
    )

    # Linia → komórki ekranu (znak szeroki zajmuje dwie; druga komórka pusta).
    $toCells = {
        param([string] $Text)
        $cells = New-Object -TypeName System.Collections.Generic.List[string]
        $i = 0
        while ($i -lt $Text.Length) {
            $char = $Text[$i]
            $piece = [string]$char
            $code = [int]$char
            if ([char]::IsHighSurrogate($char) -and $i + 1 -lt $Text.Length) {
                $piece = $Text.Substring($i, 2)
                $code = [char]::ConvertToUtf32($char, $Text[$i + 1])
                $i++
            }
            $i++
            $wide = ($code -ge 0x1100 -and $code -le 0x115F) -or ($code -ge 0x2E80 -and $code -le 0xA4CF -and $code -ne 0x303F) -or
            ($code -ge 0xAC00 -and $code -le 0xD7A3) -or ($code -ge 0xF900 -and $code -le 0xFAFF) -or ($code -ge 0xFE30 -and $code -le 0xFE4F) -or
            ($code -ge 0xFF00 -and $code -le 0xFF60) -or ($code -ge 0xFFE0 -and $code -le 0xFFE6) -or ($code -ge 0x1F300 -and $code -le 0x1FAFF) -or
            ($code -ge 0x20000 -and $code -le 0x3FFFD)
            $cells.Add($piece)
            if ($wide) {
                $cells.Add('')
            }
        }
        , $cells.ToArray()
    }
    $slice = {
        param([string[]] $Cells, [int] $Start, [int] $End)
        if ($Start -ge $Cells.Length) {
            return ''
        }
        $stop = [Math]::Min($End, $Cells.Length)
        if ($stop -le $Start) {
            return ''
        }
        (($Cells[$Start..($stop - 1)]) -join '').Trim()
    }

    $clean = @(foreach ($text in @($Line)) {
            $value = @(([string]$text) -split "`r" | Where-Object { $_.Trim() }) | Select-Object -Last 1
            if ($null -eq $value) {
                ''
                continue
            }
            ([regex]::Replace([string]$value, '\x1B\[[0-9;?]*[A-Za-z]', '')).TrimEnd()
        })

    $table = 0
    for ($index = 1; $index -lt $clean.Count; $index++) {
        if ($clean[$index] -notmatch '^\s*[-─]{3,}\s*$') {
            continue
        }
        $headerIndex = $index - 1
        while ($headerIndex -ge 0 -and -not $clean[$headerIndex].Trim()) {
            $headerIndex--
        }
        if ($headerIndex -lt 0) {
            continue
        }
        $table++
        $header = & $toCells $clean[$headerIndex]
        $starts = New-Object -TypeName System.Collections.Generic.List[int]
        for ($c = 0; $c -lt $header.Length; $c++) {
            if ($header[$c] -and $header[$c].Trim() -and ($c -eq 0 -or -not $header[$c - 1].Trim())) {
                $starts.Add($c)
            }
        }

        # Wiersze danych tej tabeli: do pustej linii albo do następnej tabeli.
        $rows = New-Object -TypeName System.Collections.Generic.List[object]
        $next = $index + 1
        while ($next -lt $clean.Count -and $clean[$next].Trim()) {
            if ($next + 1 -lt $clean.Count -and $clean[$next + 1] -match '^\s*[-─]{3,}\s*$') {
                break
            }
            $rows.Add((& $toCells $clean[$next]))
            $next++
        }

        if ($starts.Count -lt 3) {
            continue
        }
        # Wiersz „przecina” początek kolumny, gdy ma znak przed nim i na nim. Linie spoza tabeli (np.
        # „<additional entries truncated…>”, „25 upgrades available.”) są krótsze niż początek trzeciej
        # kolumny albo przecinają kilka początków — pomijamy je. Początek przecięty przez wiersz tabeli
        # to drugie słowo nagłówka (np. nagłówek dwuwyrazowy w innym języku), a nie kolumna.
        $broken = {
            param([string[]] $Row, [int] $Start)
            $Start -gt 0 -and $Row.Length -gt $Start -and $Row[$Start - 1] -and $Row[$Start - 1].Trim() -and $Row[$Start].Trim()
        }
        $tableRows = @(foreach ($row in $rows) {
                $last = $row.Length - 1
                while ($last -ge 0 -and -not ([string]$row[$last]).Trim()) {
                    $last--
                }
                if ($last -lt $starts[2]) {
                    continue
                }
                $count = @($starts | Where-Object { & $broken $row $_ }).Count
                if ($count -le 1) {
                    , $row
                }
            })
        $columns = @($starts | Where-Object {
                $start = $_
                @($tableRows | Where-Object { & $broken $_ $start }).Count -eq 0
            })
        if ($columns.Count -lt 3) {
            continue
        }
        # Gdy żaden wiersz nie przeciął drugiego słowa nagłówka, rozstrzyga poprawność wierszy: Id bez spacji
        # (poza lokalnym ARP\…) i niepusta wersja. Scalamy kolejno słowa nagłówka, dopóki to zwiększa liczbę
        # poprawnych wierszy (zachłannie).
        $valid = {
            param([int[]] $Set)
            $ok = 0
            foreach ($row in $tableRows) {
                $id = & $slice $row $Set[1] $Set[2]
                $versionEnd = if ($Set.Count -gt 3) { $Set[3] } else { [int]::MaxValue }
                if ($id -and ($id -notmatch '\s' -or $id -match '^(ARP|MSIX)\\') -and (& $slice $row $Set[2] $versionEnd)) {
                    $ok++
                }
            }
            $ok
        }
        $best = & $valid $columns
        while ($columns.Count -gt 3 -and $best -lt $tableRows.Count) {
            $choice = $null
            for ($drop = 1; $drop -lt $columns.Count; $drop++) {
                $candidate = @(for ($c = 0; $c -lt $columns.Count; $c++) { if ($c -ne $drop) { $columns[$c] } })
                $score = & $valid $candidate
                if ($score -gt $best) {
                    $best = $score
                    $choice = $candidate
                }
            }
            if ($null -eq $choice) {
                break
            }
            $columns = $choice
        }
        foreach ($row in $tableRows) {
            $item = [ordered]@{}
            for ($c = 0; $c -lt $columns.Count; $c++) {
                $name = if ($c -lt $Column.Count) { $Column[$c] } else { 'Column{0}' -f ($c + 1) }
                $end = if ($c + 1 -lt $columns.Count) { $columns[$c + 1] } else { [int]::MaxValue }
                $item[$name] = & $slice $row $columns[$c] $end
            }
            foreach ($name in $Column) {
                if (-not $item.Contains($name)) {
                    $item[$name] = ''
                }
            }
            $id = [string]$item[$Column[1]]
            $isLocal = $id -match '^(ARP|MSIX)\\'
            if (-not $id -or ($id -match '\s' -and -not $isLocal) -or -not [string]$item[$Column[2]]) {
                continue
            }
            $item['IsLocalId'] = $isLocal
            $item['Truncated'] = @($item.Values | Where-Object { $_ -is [string] -and $_.EndsWith([string][char]0x2026) }).Count -gt 0
            $item['Table'] = $table
            $result = [pscustomobject]$item
            $result.PSObject.TypeNames.Insert(0, 'MWP.WingetRow')
            $result
        }
        $index = $next - 1
    }
}
