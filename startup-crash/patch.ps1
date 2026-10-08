#Requires -Version 5.1
<#
.SYNOPSIS
Disables one obsolete Ubisoft hostname in the exact supported AC1 Steam DX10 build.
.EXAMPLE
.\patch.ps1 -ExePath 'C:\Games\Assassins Creed\AssassinsCreed_Dx10.exe' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ExePath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$path = Resolve-Ac1Executable -ExePath $ExePath
$state = Get-Ac1State -Bytes ([IO.File]::ReadAllBytes($path))
$backupPath = $path + '.ac1-fixes.original.bak'
if ($state -ceq 'Patched') {
    [pscustomobject]@{ Status='AlreadyPatched'; ExePath=$path; BackupPath=$backupPath; Sha256=$script:Ac1Build.patchedSha256 }
    return
}
Assert-Ac1Closed -ExePath $path
if (Test-Path -LiteralPath $backupPath) { Assert-Ac1Backup -BackupPath $backupPath }
if ($PSCmdlet.ShouldProcess($path, 'Back up the original and set hostname byte at file offset 0x0130D798 to zero')) {
    Set-Ac1RepairByte -ExePath $path -FromState Original -ToState Patched -BackupPath $backupPath -CreateBackup
    [pscustomobject]@{ Status='Patched'; ExePath=$path; BackupPath=$backupPath; Sha256=$script:Ac1Build.patchedSha256 }
} else {
    [pscustomobject]@{ Status='NotChanged'; ExePath=$path; BackupPath=$backupPath; Sha256=$script:Ac1Build.originalSha256 }
}
