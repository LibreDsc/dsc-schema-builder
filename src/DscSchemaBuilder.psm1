$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Constant for the schema URI used in generated manifests
# Update when new schema versions are released or if the URI changes
$script:DscManifestSchemaUri = 'https://aka.ms/dsc/schemas/v3/bundled/resource/manifest.json'

$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path "$PSScriptRoot/Public"  -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($import in @($Private + $Public)) {
    try {
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

Export-ModuleMember -Function $Public.BaseName
