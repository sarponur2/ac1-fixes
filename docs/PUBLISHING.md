# Publishing checklist

Repository: [sarponur2/ac1-fixes](https://github.com/sarponur2/ac1-fixes). Git pushes use the SSH remote `git@github.com:sarponur2/ac1-fixes.git`. The first source package is identified by tag `v0.1.0`.

For future versions:

- Review the README, narrowly supported build hashes, commands, MIT license and attribution.
- Confirm the test record for Windows PowerShell 5.1 and PowerShell 7.
- Keep the custom controller code and binary excluded pending redistribution permission and broader compatibility tests.
- Publish only tracked scripts, JSON metadata, tests and Markdown documentation; no original/patched game files, local logs, crash dumps or backups.
- Keep the public repository and SSH remote above; review any change to the publication destination.
- Tag a reviewed commit and include the package files' SHA-256 checksums in `SHA256SUMS`. GitHub provides a source ZIP for each tag; a separate GitHub Release can be added when needed.

A GitHub repository with a readable README is enough for the first version; a separate website is optional.

The local controller experiment does not justify claims of universal compatibility or a complete security audit. Keep that scope explicit in a future release.
