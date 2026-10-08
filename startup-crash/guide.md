# Startup crash around the Ubisoft logo

This repair disables an obsolete Ubisoft hostname in one exact Steam DX10 executable. It resolved the observed startup crash in a local test. It does not diagnose or fix every crash at the logo.

## Check whether this applies

The tested failure was in `AssassinsCreed_Dx10.exe` version 1.0.2.1: Windows exception `0x80000003`, fault offset `0x0076d452`. Inspection connected the fatal error to the old hostname lookup. The unmodified DX9 executable worked on that machine. After the one-byte change, the DX10 version launched through Steam with normal visuals, including with the Steam overlay loaded.

The patcher supports only these file hashes:

| State | SHA-256 |
| --- | --- |
| Original | `576a04841c37be5a819974abd59ea3ecd818f0bc36acab71c62ee0313dca0129` |
| Repaired | `9e767f248f0c192b8188b6e0878c4c9bd2a135ea5fb6e2c18626bbd552771157` |

File size: 24,183,432 bytes. Confirmed source: Steam. Other storefronts, DX9 and modified executables are outside this tool's tested scope.

## Apply

1. Exit the game.
2. In Steam, choose **Manage > Browse local files** for Assassin's Creed.
3. Open PowerShell in this downloaded repository's folder.
4. Substitute the actual executable path in the commands below. The example location is illustrative.

Preview:

```powershell
.\startup-crash\patch.ps1 -ExePath 'C:\Games\Assassins Creed\AssassinsCreed_Dx10.exe' -WhatIf
```

Apply:

```powershell
.\startup-crash\patch.ps1 -ExePath 'C:\Games\Assassins Creed\AssassinsCreed_Dx10.exe'
```

The output should say `Patched` or `AlreadyPatched`. Launch normally through Steam and check whether the crash is resolved.

If Windows blocks a downloaded script, read the scripts first. You can then run it with a process-only execution-policy override; this command does not change your saved PowerShell policy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\startup-crash\patch.ps1' -ExePath 'C:\Games\Assassins Creed\AssassinsCreed_Dx10.exe'
```

The scripts contain no download commands, network calls, registry changes, firewall changes, driver installation or executable launching. They target the selected executable and its backup.

## What changes

At file offset `0x0130D798`, the first byte of `gconnect.ubi.com` changes from `0x67` (`g`) to `0x00`. The address becomes an empty string. The script validates the whole file before and after writing.

The original is saved beside the executable as `AssassinsCreed_Dx10.exe.ac1-fixes.original.bak`. Existing backups must match the supported original checksum; they are never overwritten. `-WhatIf` creates no backup and writes no executable bytes.

Only one byte in the DX10 executable changes. DX9, controller DLLs, saves and configuration files are not edited. The game itself continues its normal save/config behavior when launched.

## Undo

Exit the game, then run:

```powershell
.\startup-crash\restore.ps1 -ExePath 'C:\Games\Assassins Creed\AssassinsCreed_Dx10.exe'
```

The restore script validates the backup and the known repaired executable, restores the original byte and verifies the original checksum. It keeps the backup. `-WhatIf` also works for restore.

If your original backup is somewhere else, pass `-BackupPath 'C:\YourBackup\AssassinsCreed_Dx10.exe'`. If the script says `AlreadyPatched` on its first run, it did not create a new backup; provide an existing supported original backup to restore, or use Steam's file verification to recover the original executable.

Steam's **Verify integrity of game files** can undo the one-byte repair. If so, rerun the patcher only after confirming this is still the same failure.

## Attribution and limits

This hostname workaround is existing community work. EaglePatch's AC1 source implements the same telemetry-byte change in memory. This repository contributes the narrowly scoped standalone scripts, whole-file verification, backup/restore flow and local test record. [Upstream source](https://github.com/Sergeanur/EaglePatch/blob/a39dc87/EaglePatch/src/ac1.cpp).

A successful local test is not a guarantee for every machine. If the checksum is unsupported, the tool stops; do not edit its accepted hashes to force a patch onto another build.
