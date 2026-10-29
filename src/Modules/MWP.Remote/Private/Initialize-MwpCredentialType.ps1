function Initialize-MwpCredentialType {
    <#
    .SYNOPSIS
        Adapter magazynu poświadczeń: kompiluje (raz na proces) typ z P/Invoke Menedżera poświadczeń Windows.

    .DESCRIPTION
        Jedyne miejsce z deklaracjami advapi32 (CredReadW, CredWriteW, CredDeleteW, CredFree) i strukturą
        CREDENTIAL (D-052; sprawdza to test architektoniczny). Typ ma w nazwie wersję (CredentialApiV1),
        więc ponowny import modułu w tym samym procesie (5.1 i 7.x) używa już skompilowanego typu, a zmiana
        kodu C# wymaga nowej nazwy. Kompilacja jest leniwa (pierwszy dostęp do magazynu), żeby nie
        wydłużać startu aplikacji. Hasło przechodzi między blobem UTF-16 a SecureString znak po znaku,
        bez obiektu string z jawnym hasłem; blob odczytany jest zerowany przed CredFree, a blob zapisu
        zwalniany przez ZeroFreeGlobalAllocUnicode. Zwraca typ.
    #>
    [CmdletBinding()]
    [OutputType([type])]
    param()

    $typeName = 'MwpRemote.CredentialApiV1'
    $type = $typeName -as [type]
    if ($null -ne $type) {
        return $type
    }
    $source = @'
using System;
using System.Runtime.InteropServices;
using System.Security;

namespace MwpRemote
{
    public static class CredentialApiV1
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct CREDENTIAL
        {
            public int Flags;
            public int Type;
            public IntPtr TargetName;
            public IntPtr Comment;
            public int LastWrittenLow;
            public int LastWrittenHigh;
            public int CredentialBlobSize;
            public IntPtr CredentialBlob;
            public int Persist;
            public int AttributeCount;
            public IntPtr Attributes;
            public IntPtr TargetAlias;
            public IntPtr UserName;
        }

        [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CredRead(string target, int type, int flags, out IntPtr credential);

        [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CredWrite(ref CREDENTIAL credential, int flags);

        [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CredDelete(string target, int type, int flags);

        [DllImport("advapi32.dll", EntryPoint = "CredFree")]
        private static extern void CredFree(IntPtr buffer);

        private const int CredTypeGeneric = 1;
        private const int CredPersistLocalMachine = 2;
        private const int ErrorInvalidParameter = 87;

        public static int Read(string target, bool includePassword, out string userName, out SecureString password, out DateTime lastWritten, out int blobSize)
        {
            userName = null;
            password = null;
            lastWritten = DateTime.MinValue;
            blobSize = 0;
            IntPtr pointer;
            if (!CredRead(target, CredTypeGeneric, 0, out pointer))
            {
                return Marshal.GetLastWin32Error();
            }
            try
            {
                CREDENTIAL credential = (CREDENTIAL)Marshal.PtrToStructure(pointer, typeof(CREDENTIAL));
                if (credential.UserName != IntPtr.Zero)
                {
                    userName = Marshal.PtrToStringUni(credential.UserName);
                }
                long fileTime = ((long)(uint)credential.LastWrittenHigh << 32) | (uint)credential.LastWrittenLow;
                try
                {
                    lastWritten = DateTime.FromFileTimeUtc(fileTime).ToLocalTime();
                }
                catch (ArgumentOutOfRangeException)
                {
                    lastWritten = DateTime.MinValue;
                }
                blobSize = credential.CredentialBlobSize;
                if (credential.CredentialBlob != IntPtr.Zero)
                {
                    if (includePassword && blobSize > 0 && blobSize % 2 == 0)
                    {
                        password = new SecureString();
                        for (int offset = 0; offset < blobSize; offset += 2)
                        {
                            password.AppendChar((char)Marshal.ReadInt16(credential.CredentialBlob, offset));
                        }
                        password.MakeReadOnly();
                    }
                    for (int offset = 0; offset < blobSize; offset++)
                    {
                        Marshal.WriteByte(credential.CredentialBlob, offset, 0);
                    }
                }
                return 0;
            }
            finally
            {
                CredFree(pointer);
            }
        }

        public static int Write(string target, string userName, SecureString password, string comment)
        {
            if (string.IsNullOrEmpty(target) || string.IsNullOrEmpty(userName) || password == null || password.Length == 0)
            {
                return ErrorInvalidParameter;
            }
            IntPtr blob = IntPtr.Zero;
            IntPtr targetPointer = IntPtr.Zero;
            IntPtr userPointer = IntPtr.Zero;
            IntPtr commentPointer = IntPtr.Zero;
            try
            {
                blob = Marshal.SecureStringToGlobalAllocUnicode(password);
                targetPointer = Marshal.StringToHGlobalUni(target);
                userPointer = Marshal.StringToHGlobalUni(userName);
                commentPointer = Marshal.StringToHGlobalUni(comment ?? string.Empty);
                CREDENTIAL credential = new CREDENTIAL();
                credential.Type = CredTypeGeneric;
                credential.Persist = CredPersistLocalMachine;
                credential.TargetName = targetPointer;
                credential.UserName = userPointer;
                credential.Comment = commentPointer;
                credential.CredentialBlobSize = password.Length * 2;
                credential.CredentialBlob = blob;
                if (!CredWrite(ref credential, 0))
                {
                    return Marshal.GetLastWin32Error();
                }
                return 0;
            }
            finally
            {
                if (blob != IntPtr.Zero) { Marshal.ZeroFreeGlobalAllocUnicode(blob); }
                if (targetPointer != IntPtr.Zero) { Marshal.FreeHGlobal(targetPointer); }
                if (userPointer != IntPtr.Zero) { Marshal.FreeHGlobal(userPointer); }
                if (commentPointer != IntPtr.Zero) { Marshal.FreeHGlobal(commentPointer); }
            }
        }

        public static int Delete(string target)
        {
            if (string.IsNullOrEmpty(target))
            {
                return ErrorInvalidParameter;
            }
            return CredDelete(target, CredTypeGeneric, 0) ? 0 : Marshal.GetLastWin32Error();
        }
    }
}
'@
    # Dwa runspace'y mogą kompilować równocześnie (zadania okna); blokada na danych domeny aplikacji.
    $domain = [AppDomain]::CurrentDomain
    [Threading.Monitor]::Enter($domain)
    try {
        $type = $typeName -as [type]
        if ($null -eq $type) {
            Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop
            $type = $typeName -as [type]
        }
    }
    finally {
        [Threading.Monitor]::Exit($domain)
    }
    $type
}
