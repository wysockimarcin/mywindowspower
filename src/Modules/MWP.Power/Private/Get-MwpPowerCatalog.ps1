function Get-MwpPowerCatalog {
    <#
    .SYNOPSIS
        Zwraca stałe modułu MWP.Power: GUID-y planów wbudowanych, szablon „Najwyższa wydajność” i katalog ustawień.

    .DESCRIPTION
        Parsowanie powercfg opiera się na GUID-ach (niezależnie od języka systemu), więc wszystkie
        identyfikatory są w jednym miejscu. GUID-y zweryfikowane w FAZIE 6 (2026-10-27) poleceniem
        powercfg /qh na Windows 11 Pro 26300 oraz w kluczu domyślnych schematów
        HKLM\SYSTEM\CurrentControlSet\Control\Power\User\Default\PowerSchemes (D-044).
        Ustawienia: podgrupa i ustawienie (GUID), rodzaj (Timeout — sekundy, 0 = nigdy; Action —
        indeks akcji) i największy indeks akcji.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    @{
        # Szablon ukrytego schematu „Ultimate Performance” / „Najwyższa wydajność”
        # (powrprof.dll,-19; Microsoft Q&A: powercfg -duplicatescheme e9a42b02-…).
        UltimateTemplateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        BuiltInPlans         = [ordered]@{
            '381b4222-f694-41f0-9685-ff5bb260df2e' = 'Zrównoważony (Balanced)'
            '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' = 'Wysoka wydajność (High performance)'
            'a1841308-3541-4fab-bc81-f71556f20b4a' = 'Oszczędzanie energii (Power saver)'
        }
        ActionLabels         = [ordered]@{
            0 = 'Nic nie rób'
            1 = 'Uśpij'
            2 = 'Hibernuj'
            3 = 'Zamknij system'
            4 = 'Wyłącz ekran'
        }
        Settings             = @(
            [pscustomobject]@{
                Id = 'MonitorTimeout'
                Label = 'Wyłącz ekran po'
                Kind = 'Timeout'
                MaxIndex = 0
                Alias = 'VIDEOIDLE'
                SubGroup = '7516b95f-f776-4464-8c53-06167f40cc99'
                Setting = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'
            }
            [pscustomobject]@{
                Id = 'SleepTimeout'
                Label = 'Uśpij po'
                Kind = 'Timeout'
                MaxIndex = 0
                Alias = 'STANDBYIDLE'
                SubGroup = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
                Setting = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
            }
            [pscustomobject]@{
                Id = 'HibernateTimeout'
                Label = 'Hibernuj po'
                Kind = 'Timeout'
                MaxIndex = 0
                Alias = 'HIBERNATEIDLE'
                SubGroup = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
                Setting = '9d7815a6-7ee4-497e-8888-515a05f02364'
            }
            [pscustomobject]@{
                Id = 'LidAction'
                Label = 'Zamknięcie pokrywy'
                Kind = 'Action'
                MaxIndex = 3
                Alias = 'LIDACTION'
                SubGroup = '4f971e89-eebd-4455-a8de-9e59040e7347'
                Setting = '5ca83367-6e45-459f-a27b-476b1d01c936'
            }
            [pscustomobject]@{
                Id = 'PowerButtonAction'
                Label = 'Przycisk zasilania'
                Kind = 'Action'
                MaxIndex = 4
                Alias = 'PBUTTONACTION'
                SubGroup = '4f971e89-eebd-4455-a8de-9e59040e7347'
                Setting = '7648efa3-dd9c-4e3e-b566-50f929386280'
            }
            [pscustomobject]@{
                Id = 'SleepButtonAction'
                Label = 'Przycisk uśpienia'
                Kind = 'Action'
                MaxIndex = 4
                Alias = 'SBUTTONACTION'
                SubGroup = '4f971e89-eebd-4455-a8de-9e59040e7347'
                Setting = '96996bc0-ad50-47ec-923b-6f41874dd9eb'
            }
        )
    }
}
