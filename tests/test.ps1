#Requires -Version 5.1
[CmdletBinding()]
param([string]$OriginalExePath, [string]$ReportPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent $PSScriptRoot
$patch=Join-Path $repoRoot 'startup-crash\patch.ps1'
$restore=Join-Path $repoRoot 'startup-crash\restore.ps1'
$build=Get-Content -LiteralPath (Join-Path $repoRoot 'startup-crash\supported-build.json') -Raw | ConvertFrom-Json
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('ac1-fixes-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$script:CaseNumber=0
$results=New-Object 'System.Collections.Generic.List[object]'
function Assert-True([bool]$Condition,[string]$Message) { if(!$Condition){throw $Message} }
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Assert-Throws([scriptblock]$Action) {
    $failed=$false
    try {$null=& $Action} catch {$failed=$true}
    if(!$failed){throw 'Expected an exception, but operation succeeded.'}
}
function Case([string]$Name,[scriptblock]$Action) {
    try {
        $null=& $Action
        $results.Add([pscustomobject]@{Name=$Name;Passed=$true})
        Write-Host "PASS $Name"
    } catch {
        $results.Add([pscustomobject]@{Name=$Name;Passed=$false;Error=$_.Exception.Message})
        Write-Host "FAIL $Name : $($_.Exception.Message)"
    }
}
function Folder {
    $script:CaseNumber++
    $dir=Join-Path $testRoot ('case-' + $script:CaseNumber)
    New-Item -ItemType Directory -Path $dir | Out-Null
    return $dir
}
function Fixture([switch]$Patched) {
    $path=Join-Path (Folder) $build.fileName
    if($Patched){$bytes=$patchedBytes}else{$bytes=$originalBytes}
    [IO.File]::WriteAllBytes($path,$bytes)
    return $path
}
try {
    Case 'PowerShell parser accepts every script' {
        foreach($file in Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter '*.ps1' -File) {
            $tokens=$null; $errors=$null
            $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            if($errors){throw "Parser errors in $($file.Name): $errors"}
        }
    }
    Case 'Missing executable is refused' { Assert-Throws { & $patch -ExePath (Join-Path $testRoot 'missing.exe') } }
    Case 'DX9 filename is refused without changes' {
        $p=Join-Path (Folder) 'AssassinsCreed_Dx9.exe'
        [IO.File]::WriteAllBytes($p,[byte[]](1,2,3));$before=Hash $p
        Assert-Throws { & $patch -ExePath $p }
        Assert-True ((Hash $p) -ceq $before) 'Unsupported file changed.'
    }
    Case 'Short unknown DX10 file is refused without backup' {
        $p=Join-Path (Folder) $build.fileName
        [IO.File]::WriteAllBytes($p,[byte[]](1,2,3));$before=Hash $p
        Assert-Throws { & $patch -ExePath $p }
        Assert-True ((Hash $p) -ceq $before) 'Unsupported file changed.'
        Assert-True (!(Test-Path -LiteralPath ($p+'.ac1-fixes.original.bak'))) 'Unexpected backup.'
    }
    Case 'Restore refuses an unsupported file' {
        $p=Join-Path (Folder) $build.fileName
        [IO.File]::WriteAllBytes($p,[byte[]](1,2,3));$before=Hash $p
        Assert-Throws { & $restore -ExePath $p }
        Assert-True ((Hash $p) -ceq $before) 'Unsupported file changed.'
    }
    Case 'A directory named like the executable is refused' {
        $p=Join-Path (Folder) $build.fileName
        New-Item -ItemType Directory -Path $p | Out-Null
        Assert-Throws { & $patch -ExePath $p }
    }
    Case 'Oversized executable is refused before reading its contents' {
        $p=Join-Path (Folder) $build.fileName
        $f=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $f.SetLength([long]$build.length + 1) } finally { $f.Dispose() }
        Assert-Throws { & $patch -ExePath $p }
        Assert-True ((Get-Item -LiteralPath $p).Length -eq [long]$build.length+1) 'Oversized file changed.'
        Assert-True (!(Test-Path -LiteralPath ($p+'.ac1-fixes.original.bak'))) 'Unexpected backup.'
    }
    $fullRun=![string]::IsNullOrWhiteSpace($OriginalExePath)
    if($fullRun) {
        $originalPath=(Get-Item -LiteralPath $OriginalExePath -ErrorAction Stop).FullName
        Assert-True ((Hash $originalPath) -ceq $build.originalSha256) 'Fixture must be the exact supported original executable.'
        $originalBytes=[IO.File]::ReadAllBytes($originalPath)
        $patchedBytes=[byte[]]$originalBytes.Clone();$patchedBytes[[int]$build.offset]=[byte]$build.patchedByte
        if(-not ('Ac1PatchByteDiff' -as [type])) {
            Add-Type -TypeDefinition @"
public static class Ac1PatchByteDiff {
    public static int[] Changed(byte[] a, byte[] b) {
        if(a.Length!=b.Length) throw new System.Exception("Length changed");
        var indexes=new System.Collections.Generic.List<int>();
        for(int i=0;i<a.Length;i++) if(a[i]!=b[i]) indexes.Add(i);
        return indexes.ToArray();
    }
}
"@
        }
        $lifecycle=Fixture
        $backup=$lifecycle+'.ac1-fixes.original.bak'
        Case 'Patch produces expected checksum and original backup' {
            $r=& $patch -ExePath $lifecycle
            Assert-True ($r.Status -ceq 'Patched') 'Incorrect patch status.'
            Assert-True ((Hash $lifecycle) -ceq $build.patchedSha256) 'Patched checksum differs.'
            Assert-True ((Hash $backup) -ceq $build.originalSha256) 'Backup checksum differs.'
        }
        Case 'Exactly the intended byte changes' {
            $diff=[Ac1PatchByteDiff]::Changed($originalBytes,[IO.File]::ReadAllBytes($lifecycle))
            Assert-True ($diff.Length -eq 1 -and $diff[0] -eq [int]$build.offset) 'Patch changed an unexpected number/location of bytes.'
        }
        Case 'Repeated patch leaves executable and backup unchanged' {
            $stamp=(Get-Item -LiteralPath $backup).LastWriteTimeUtc
            $exeStamp=(Get-Item -LiteralPath $lifecycle).LastWriteTimeUtc
            $r=& $patch -ExePath $lifecycle
            Assert-True ($r.Status -ceq 'AlreadyPatched') 'Incorrect idempotent status.'
            Assert-True ((Hash $backup) -ceq $build.originalSha256) 'Backup changed.'
            Assert-True ((Get-Item -LiteralPath $backup).LastWriteTimeUtc -eq $stamp) 'Backup was overwritten.'
            Assert-True ((Get-Item -LiteralPath $lifecycle).LastWriteTimeUtc -eq $exeStamp) 'Executable was rewritten.'
        }
        Case 'Restore WhatIf changes neither executable nor backup' {
            $r=& $restore -ExePath $lifecycle -WhatIf
            Assert-True ($r.Status -ceq 'NotChanged') 'Incorrect preview status.'
            Assert-True ((Hash $lifecycle) -ceq $build.patchedSha256) 'Preview changed executable.'
            Assert-True ((Hash $backup) -ceq $build.originalSha256) 'Preview changed backup.'
        }
        Case 'Restore recreates exact original and preserves backup' {
            $r=& $restore -ExePath $lifecycle
            Assert-True ($r.Status -ceq 'Restored') 'Incorrect restore status.'
            Assert-True ((Hash $lifecycle) -ceq $build.originalSha256) 'Original checksum not restored.'
            Assert-True ((Hash $backup) -ceq $build.originalSha256) 'Backup changed.'
        }
        Case 'Repeated restore is a no-op' {
            $stamp=(Get-Item -LiteralPath $lifecycle).LastWriteTimeUtc
            $r=& $restore -ExePath $lifecycle
            Assert-True ($r.Status -ceq 'AlreadyOriginal') 'Incorrect idempotent restore status.'
            Assert-True ((Get-Item -LiteralPath $lifecycle).LastWriteTimeUtc -eq $stamp) 'Original executable was rewritten.'
        }
        Case 'A valid pre-existing backup is reused without overwrite' {
            $stamp=(Get-Item -LiteralPath $backup).LastWriteTimeUtc
            $r=& $patch -ExePath $lifecycle
            Assert-True ($r.Status -ceq 'Patched') 'Repatch failed.'
            Assert-True ((Get-Item -LiteralPath $backup).LastWriteTimeUtc -eq $stamp) 'Existing backup was overwritten.'
        }
        Case 'Patch WhatIf creates no backup and changes no bytes' {
            $p=Fixture;$stamp=(Get-Item -LiteralPath $p).LastWriteTimeUtc
            $r=& $patch -ExePath $p -WhatIf
            Assert-True ($r.Status -ceq 'NotChanged') 'Incorrect preview status.'
            Assert-True ((Hash $p) -ceq $build.originalSha256) 'Preview changed executable.'
            Assert-True (!(Test-Path -LiteralPath ($p+'.ac1-fixes.original.bak'))) 'Preview created backup.'
            Assert-True ((Get-Item -LiteralPath $p).LastWriteTimeUtc -eq $stamp) 'Preview changed timestamp.'
        }
        Case 'Wrong full-size checksum is refused' {
            $p=Fixture;$bytes=[IO.File]::ReadAllBytes($p);$bytes[0]=$bytes[0] -bxor 1
            [IO.File]::WriteAllBytes($p,$bytes);$before=Hash $p
            Assert-Throws { & $patch -ExePath $p }
            Assert-True ((Hash $p) -ceq $before) 'Unknown executable changed.'
            Assert-True (!(Test-Path -LiteralPath ($p+'.ac1-fixes.original.bak'))) 'Unknown executable produced backup.'
        }
        Case 'Corrupt existing backup is refused without overwriting it' {
            $p=Fixture;$b=$p+'.ac1-fixes.original.bak';[IO.File]::WriteAllBytes($b,[byte[]](1,2,3));$before=Hash $b
            Assert-Throws { & $patch -ExePath $p }
            Assert-True ((Hash $p) -ceq $build.originalSha256) 'Executable changed.'
            Assert-True ((Hash $b) -ceq $before) 'Corrupt backup overwritten.'
        }
        Case 'Full-size corrupt backup is refused' {
            $p=Fixture;$b=$p+'.ac1-fixes.original.bak';$bytes=[byte[]]$originalBytes.Clone();$bytes[0]=$bytes[0] -bxor 1
            [IO.File]::WriteAllBytes($b,$bytes);$before=Hash $b
            Assert-Throws { & $patch -ExePath $p }
            Assert-True ((Hash $p) -ceq $build.originalSha256) 'Executable changed.'
            Assert-True ((Hash $b) -ceq $before) 'Backup changed.'
        }
        Case 'Restore refuses a missing backup' {
            $p=Fixture -Patched
            Assert-Throws { & $restore -ExePath $p }
            Assert-True ((Hash $p) -ceq $build.patchedSha256) 'Missing-backup restore changed file.'
        }
        Case 'Restore refuses a corrupt backup' {
            $p=Fixture -Patched;$b=$p+'.ac1-fixes.original.bak';[IO.File]::WriteAllBytes($b,[byte[]](1,2,3))
            Assert-Throws { & $restore -ExePath $p }
            Assert-True ((Hash $p) -ceq $build.patchedSha256) 'Corrupt-backup restore changed file.'
        }
        Case 'Restore refuses an executable with additional changes' {
            $p=Fixture -Patched;$b=$p+'.ac1-fixes.original.bak';[IO.File]::WriteAllBytes($b,$originalBytes)
            $bytes=[IO.File]::ReadAllBytes($p);$bytes[0]=$bytes[0] -bxor 1;[IO.File]::WriteAllBytes($p,$bytes);$before=Hash $p
            Assert-Throws { & $restore -ExePath $p }
            Assert-True ((Hash $p) -ceq $before) 'Restore overwrote another modification.'
        }
        Case 'Restore accepts an explicitly supplied original backup' {
            $p=Fixture -Patched;$b=Join-Path (Folder) 'original.copy';[IO.File]::WriteAllBytes($b,$originalBytes)
            $r=& $restore -ExePath $p -BackupPath $b
            Assert-True ($r.Status -ceq 'Restored') 'Explicit-backup restore failed.'
            Assert-True ((Hash $p) -ceq $build.originalSha256) 'Original not restored.'
        }
        Case 'Already repaired file without backup stays untouched' {
            $p=Fixture -Patched
            $r=& $patch -ExePath $p
            Assert-True ($r.Status -ceq 'AlreadyPatched') 'Incorrect already-patched status.'
            Assert-True (!(Test-Path -LiteralPath ($p+'.ac1-fixes.original.bak'))) 'Invented a backup.'
        }
        Case 'Locked executable is refused without changes' {
            $p=Fixture
            $lock=[IO.File]::Open($p,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
            try { Assert-Throws { & $patch -ExePath $p } } finally { $lock.Dispose() }
            Assert-True ((Hash $p) -ceq $build.originalSha256) 'Locked-file test changed bytes.'
            Assert-True (!(Test-Path -LiteralPath ($p+'.ac1-fixes.original.bak'))) 'Locked-file test created backup.'
        }
        Case 'Read-only executable is refused without changes' {
            $p=Fixture
            [IO.File]::SetAttributes($p,[IO.FileAttributes]::ReadOnly)
            try { Assert-Throws { & $patch -ExePath $p } } finally { [IO.File]::SetAttributes($p,[IO.FileAttributes]::Normal) }
            Assert-True ((Hash $p) -ceq $build.originalSha256) 'Read-only file changed.'
            Assert-True (!(Test-Path -LiteralPath ($p+'.ac1-fixes.original.bak'))) 'Read-only file produced backup.'
        }
        Case 'User-supplied original fixture remains unchanged' {
            Assert-True ((Hash $originalPath) -ceq $build.originalSha256) 'Input fixture was modified.'
        }
    } else { Write-Host 'Full patch/restore tests skipped; supply -OriginalExePath to run them.' }
    $failed=@($results | Where-Object {!$_.Passed}).Count
    $report=[pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();FullRun=$fullRun;Passed=$results.Count-$failed;Failed=$failed;Cases=$results.ToArray()}
    if($ReportPath){$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8}
    Write-Host "$($report.Passed) passed; $failed failed. PowerShell $($report.PowerShell)."
    if($failed -gt 0){throw 'AC1 tests failed.'}
} finally {
    if(Test-Path -LiteralPath $testRoot) {
        $resolved=(Resolve-Path -LiteralPath $testRoot).Path
        $tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if(!$resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^ac1-fixes-tests-[0-9a-f]{32}$'){throw 'Unsafe test cleanup target.'}
        if(Get-ChildItem -LiteralPath $resolved -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue){throw 'Unexpected test reparse point; cleanup stopped.'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}