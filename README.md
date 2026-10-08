# AC1 fixes

Targeted troubleshooting for Assassin's Creed: Director's Cut on Windows: a startup crash near the Ubisoft logo and incorrect controller mapping.

Download the [v0.1.0 source package](https://github.com/sarponur2/ac1-fixes/archive/refs/tags/v0.1.0.zip), extract it, and follow the appropriate guide below. The package contains scripts and documentation; no game executable or controller DLL is included.

| Problem | Available here | Tested scope |
| --- | --- | --- |
| Crash around the Ubisoft logo in DX10 | [Guide](startup-crash/guide.md), [patch](startup-crash/patch.ps1), [restore](startup-crash/restore.ps1) | One exact Steam DX10 executable, Windows 10 |
| F710 triggers moving the camera | [Controller guide](controller/guide.md) and EaglePatch attribution | Steam DX10, Logitech F710 in X mode with its wireless dongle |

The crash script accepts only the listed original checksum or its known repaired counterpart. It creates a backup beside the executable, changes one byte and verifies the result. It will refuse other builds or other executable modifications. You can preview with `-WhatIf`.

Find your game folder through Steam's **Manage > Browse local files**, then follow the [crash guide](startup-crash/guide.md). Run scripts from a writable folder with your normal account; administrator access is not requested by these tools.

The controller section documents a working local experiment derived from [Sergeanur's EaglePatch](https://github.com/Sergeanur/EaglePatch). The custom controller source and DLL are deliberately excluded while redistribution permission is clarified. The original author's download is linked in the guide.

## Contents

- `startup-crash/`: patcher, restore script, exact build metadata and guide.
- `controller/`: controller troubleshooting and the scope of the local experiment.
- `tests/`: standalone PowerShell tests; no additional test framework required.
- `docs/`: validation record, attribution, and publishing checklist.

## Testing

```powershell
.\tests\test.ps1
.\tests\test.ps1 -OriginalExePath 'C:\YourBackup\AssassinsCreed_Dx10.exe'
```

The first command tests unsupported input and script parsing. Supplying your own original executable also tests the full patch/restore lifecycle on temporary copies. The supplied original and installed game are never changed by the tests. No game executable is included in this repository.

See [validation](docs/VALIDATION.md), [credits](docs/ATTRIBUTION.md), and [publishing checklist](docs/PUBLISHING.md).

## License

The original scripts and documentation in this repository use the [MIT License](LICENSE). That license does not cover Assassin's Creed, EaglePatch, or any third-party assets. This project is unofficial and is not affiliated with Ubisoft, Logitech, or EaglePatch's author.
