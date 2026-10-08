# Validation

## Previously observed game behavior — 8 October 2026

- Original Steam DX10 build: startup crashes at the Ubisoft logo; Windows fault `0x80000003`, offset `0x0076d452`.
- One-byte hostname repair: normal Steam DX10 launch and normal visuals confirmed by the user.
- Local controller-only build: keyboard/mouse and F710 input confirmed; a later gameplay check reported everything working.
- Local controller binary: Windows Defender found no threats; repeated local compilation produced identical bytes. This is a local check, not an independent security audit.

## Standalone repository scripts — 9 October 2026

| Runtime | Passed | Failed |
| --- | ---: | ---: |
| Windows PowerShell 5.1.19041.7725 | 26 | 0 |
| PowerShell 7.6.5 | 26 | 0 |

The full suite ran with a locally supplied original executable matching the supported checksum. It verified the exact patched checksum, exactly one changed byte, backup preservation, repeated calls, preview mode, explicit backup selection, and restoration to the original checksum. Unsupported builds, missing or invalid backups, additional modifications, directories, locked files and read-only files were refused without changing the executable.

The runner uses temporary executable copies and removes them after testing. The supplied original backup and installed game were unchanged. Real game binaries, local test reports, crash dumps and controller binaries are excluded from this repository and its review package.

Without `-OriginalExePath`, the runner performs seven parsing and synthetic-input checks and explicitly skips the full lifecycle tests. These results cover the listed executable and runtimes, not other game builds or every hardware configuration. The repository scripts were tested on copies; the earlier game launch confirmation used the same byte change applied locally.
