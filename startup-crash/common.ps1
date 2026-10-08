# Shared functions for the narrowly scoped DX10 repair. No network access.
Set-StrictMode -Version Latest
$script:Ac1Build = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'supported-build.json') -Raw | ConvertFrom-Json

function Get-Ac1Hash {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Resolve-Ac1Executable {
    param([Parameter(Mandatory=$true)][string]$ExePath)
    $item = Get-Item -LiteralPath $ExePath -Force -ErrorAction Stop
    if ($item.PSProvider.Name -ne 'FileSystem' -or $item.PSIsContainer) { throw 'Choose a local executable file.' }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Executable links are not supported; choose the actual file.' }
    if ($item.Name -ine $script:Ac1Build.fileName) { throw 'Only AssassinsCreed_Dx10.exe is supported.' }
    if ($item.Length -ne [long]$script:Ac1Build.length) { throw 'Unsupported executable size. No changes made.' }
    return $item.FullName
}

function Assert-Ac1Closed {
    param([Parameter(Mandatory=$true)][string]$ExePath)
    $folder = Split-Path -Parent $ExePath
    $processes = @(Get-Process -Name 'AssassinsCreed_Dx10','AssassinsCreed_Dx9','AssassinsCreed_Game' -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        try { $runningPath = $process.Path } catch { throw 'Cannot inspect a running AC1 process. Close AC1 first.' }
        if ([string]::IsNullOrEmpty($runningPath)) { throw 'Cannot inspect a running AC1 process. Close AC1 first.' }
        if ((Split-Path -Parent $runningPath) -ieq $folder) { throw 'Close Assassin''s Creed before changing this game folder.' }
    }
}

function Get-Ac1State {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)
    if ($Bytes.LongLength -ne [long]$script:Ac1Build.length) { throw 'Unsupported executable size. No changes made.' }
    $hash = Get-Ac1Hash -Bytes $Bytes
    if ($hash -ceq $script:Ac1Build.originalSha256) { return 'Original' }
    if ($hash -ceq $script:Ac1Build.patchedSha256) { return 'Patched' }
    throw 'Unsupported executable checksum. This tool will not overwrite an unknown or modified build.'
}

function Read-Ac1LockedImage {
    param([Parameter(Mandatory=$true)][IO.FileStream]$Stream)
    if ($Stream.Length -ne [long]$script:Ac1Build.length) { throw 'Unsupported executable size.' }
    $bytes = New-Object byte[] ([int]$Stream.Length)
    $Stream.Position = 0
    $read = 0
    while ($read -lt $bytes.Length) {
        $count = $Stream.Read($bytes, $read, $bytes.Length - $read)
        if ($count -eq 0) { throw 'Unexpected end of executable.' }
        $read += $count
    }
    return ,$bytes
}

function Assert-Ac1Backup {
    param([Parameter(Mandatory=$true)][string]$BackupPath)
    $item = Get-Item -LiteralPath $BackupPath -Force -ErrorAction Stop
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Backup must be a regular file.' }
    if ($item.Length -ne [long]$script:Ac1Build.length) { throw 'Backup is not the supported original executable.' }
    $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($hash -cne $script:Ac1Build.originalSha256) { throw 'Backup checksum is invalid. No changes made.' }
}

function Set-Ac1RepairByte {
    param(
        [Parameter(Mandatory=$true)][string]$ExePath,
        [Parameter(Mandatory=$true)][ValidateSet('Original','Patched')][string]$FromState,
        [Parameter(Mandatory=$true)][ValidateSet('Original','Patched')][string]$ToState,
        [Parameter(Mandatory=$true)][string]$BackupPath,
        [switch]$CreateBackup
    )
    Assert-Ac1Closed -ExePath $ExePath
    $stream = [IO.File]::Open($ExePath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $before = Read-Ac1LockedImage -Stream $stream
        if ((Get-Ac1State -Bytes $before) -cne $FromState) { throw 'Executable changed since inspection. No changes made.' }
        $offset = [int]$script:Ac1Build.offset
        $oldByte = $before[$offset]
        $newByte = if ($ToState -ceq 'Patched') { [byte]$script:Ac1Build.patchedByte } else { [byte]$script:Ac1Build.originalByte }
        $after = [byte[]]$before.Clone()
        $after[$offset] = $newByte
        if ((Get-Ac1State -Bytes $after) -cne $ToState) { throw 'Patch recipe validation failed. No changes made.' }

        if ($CreateBackup) {
            if (Test-Path -LiteralPath $BackupPath) {
                Assert-Ac1Backup -BackupPath $BackupPath
            } else {
                $backup = [IO.File]::Open($BackupPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try { $backup.Write($before, 0, $before.Length); $backup.Flush($true) }
                finally { $backup.Dispose() }
                Assert-Ac1Backup -BackupPath $BackupPath
            }
        } else {
            Assert-Ac1Backup -BackupPath $BackupPath
        }

        # Change one byte without replacing or truncating the executable.
        $writeStarted = $false
        try {
            $stream.Position = $offset
            $writeStarted = $true
            $stream.WriteByte($newByte)
            $stream.Flush($true)
            $verified = Read-Ac1LockedImage -Stream $stream
            if ((Get-Ac1State -Bytes $verified) -cne $ToState) { throw 'Post-write checksum verification failed.' }
        } catch {
            $failure = $_
            if ($writeStarted) {
                try {
                    $stream.Position = $offset
                    $stream.WriteByte($oldByte)
                    $stream.Flush($true)
                    if ((Get-Ac1State -Bytes (Read-Ac1LockedImage -Stream $stream)) -cne $FromState) { throw 'Rollback checksum differs.' }
                } catch { throw "Write and rollback failed. Preserve the original backup at '$BackupPath' and restore it manually. $($_.Exception.Message)" }
            }
            throw $failure
        }
    } finally { $stream.Dispose() }
}
