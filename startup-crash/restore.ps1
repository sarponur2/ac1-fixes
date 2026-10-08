#Requires -Version 5.1
<#
.SYNOPSIS
Undoes this repository's one-byte AC1 DX10 repair after validating the original backup.
.EXAMPLE
.\restore.ps1 -ExePath 'C:\Games\Assassins Creed\AssassinsCreed_Dx10.exe'
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ExePath,
    [string]$BackupPath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$path = Resolve-Ac1Executable -ExePath $ExePath
if ([string]::IsNullOrWhiteSpace($BackupPath)) { $BackupPath = $path + '.ac1-fixes.original.bak' }
$state = Get-Ac1State -Bytes ([IO.File]::ReadAllBytes($path))
if ($state -ceq 'Original') {
    [pscustomobject]@{ Status='AlreadyOriginal'; ExePath=$path; Sha256=$script:Ac1Build.originalSha256 }
    return
}
Assert-Ac1Closed -ExePath $path
Assert-Ac1Backup -BackupPath $BackupPath
if ($PSCmdlet.ShouldProcess($path, 'Validate the original backup and restore the hostname byte at file offset 0x0130D798')) {
    Set-Ac1RepairByte -ExePath $path -FromState Patched -ToState Original -BackupPath $BackupPath
    [pscustomobject]@{ Status='Restored'; ExePath=$path; BackupPath=$BackupPath; Sha256=$script:Ac1Build.originalSha256 }
} else {
    [pscustomobject]@{ Status='NotChanged'; ExePath=$path; BackupPath=$BackupPath; Sha256=$script:Ac1Build.patchedSha256 }
}
