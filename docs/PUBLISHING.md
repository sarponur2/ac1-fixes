# Publishing checklist

Status: local draft; no remote or public release has been created.

Before publishing this first version:

- Review the README, narrowly supported build hashes, commands, MIT license and attribution.
- Confirm the test record for Windows PowerShell 5.1 and PowerShell 7.
- Keep the custom controller code and binary excluded pending redistribution permission and broader compatibility tests.
- Publish only tracked scripts, JSON metadata, tests and Markdown documentation; no original/patched game files, local logs, crash dumps or backups.
- Select the GitHub repository owner, name and visibility. Use an SSH Git remote (`git@github.com:OWNER/ac1-fixes.git`) for pushing, as requested.
- Create a release from the reviewed commit and include the script package's SHA-256 checksums.

A GitHub repository with a readable README is enough for the first version; a separate website is optional.

The local controller experiment does not justify claims of universal compatibility or a complete security audit. Keep that scope explicit in a future release.
