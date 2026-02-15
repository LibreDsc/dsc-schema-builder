@{
    RootModule        = 'DscSchemaBuilder.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'f4c7e2a1-5d38-4b69-9c17-8a6f3e2d1b0c'
    Author            = 'LibreDsc'
    Copyright         = 'Copyright (c) 2026 LibreDsc. All rights reserved.'
    Description       = 'Generate Microsoft Desired State Configuration (DSC) resource manifests and JSON Schema from PowerShell DSC resources'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('New-DscResourceManifestFromClass')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('DSC', 'JSON', 'Schema', 'AST')
            ProjectUri = 'https://github.com/LibreDsc/dsc-schema-builder'
            LicenseUri = 'https://github.com/LibreDsc/dsc-schema-builder/blob/main/LICENSE'
        }
    }
}
