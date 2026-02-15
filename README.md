
# DscSchemaBuilder - PowerShell module

This is the repository for the Microsoft Desired State Configuration (DSC) schema builder PowerShell module. The module is specifically created to make PowerShell DSC (PSDSC) resources a *first-class citizen* to DSC's engine. It contains multiple commands, but the most notorious one is the generation of a resource manifest (`*.dsc.resource.json` or `*.dsc.manifests.json*`) with optionally a small wrapper script to invoke PSDSC resources directly instead of going through the adapter.

## Commands implemented

- [New-DscResourceManifestFromClass][00]
- [Convert-MofToDsc][01]

<!-- Link reference -->
[00]: docs/Help/New-DscResourceManifestFromClass.md
[01]: docs/Help/Convert-MofToDsc.md
