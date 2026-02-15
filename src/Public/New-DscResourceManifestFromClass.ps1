function New-DscResourceManifestFromClass {
    <#
        .SYNOPSIS
            Generates a Microsoft Desired State Configuration (DSC) resource manifest from PowerShell class-based DSC resources.

        .DESCRIPTION
            The function `New-DscResourceManifestFromClass` generates a Microsoft DSC resource manifest by analyzing PowerShell class definitions 
            decorated with the `[DscResource()]` attribute. It uses the Abstract Syntax Tree (AST) to inspect the structure of the classes and 
            their members, extracting necessary information to create a manifest that describes the DSC resources.

            `New-DscResourceManifestFromClass` accepts a path to a `.ps1` or `.psm1` file containing one or more `[DscResource()]` decorated PowerShell classes.
            It then parses the file to identify classes that are decorated with `[DscResource()]`. For each identified class, the 
            function inspects its properties and methods to determine the characteristics of the DSC resource,
            such as which properties are keys, mandatory, or have specific validation attributes. 
            It also checks for the presence of methods like Get, Set, Test, Delete, and Export to determine the operations supported by the resource.

            When `-GenerateResourceScript` is specified a `resource.ps1` wrapper
            file is also written.  This script bridges the class-based DSC resource model
            to the model DSC expects, allowing the manifest to point to it for execution. 

        .PARAMETER Path
            Path to a `.ps1` or `.psm1` file containing one or more `[DscResource()]` decorated PowerShell classes.

        .PARAMETER ResourceTypePrefix
            Optional namespace prefix for the resource type.
            Example: "MyOrg.Windows" → type becomes "MyOrg.Windows/ClassName".

            Defaults to "LibreDsc.Tutorial"

        .PARAMETER Version
            Semantic version string for all generated resources. Defaults to "0.1.0".

        .PARAMETER Description
            Optional description applied to every resource entry.  When omitted a sensible default is generated from the class name.

        .PARAMETER Executable
            Executable path to embed in the manifest operation entries.  
            Only used when `-GenerateResourceScript` is NOT specified (placeholder mode).  Defaults to "<executable>".

        .PARAMETER AllowNullKeys
            By default, properties decorated with [DscProperty(Key)] are considered required and must have a non-null value.
            When -AllowNullKeys is specified, key properties are allowed to have null values, making them optional in the generated manifest.

        .PARAMETER GenerateResourceScript
            When specified, a resource.ps1 wrapper script is generated
            alongside the manifest and the manifest entries point to it.

        .PARAMETER OutputDirectory
            Directory where the manifest (and optional script) are written.
            Defaults to the directory of the input file.

        .EXAMPLE
            New-DscResourceManifestFromClass -Path .Microsoft.Windows.Settings.psm1 `
                -ResourceTypePrefix 'Microsoft.Windows' `
                -GenerateResourceScript `
                -AllowNullKeys

        .NOTES 
            Author: LibreDsc 
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]
        $Path,

        [Parameter()]
        [string]
        $ResourceTypePrefix = 'LibreDsc.Tutorial',

        [Parameter()]
        [string]
        $Version = '0.1.0',

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $Executable,

        [Parameter()]
        [switch]
        $GenerateResourceScript,

        [Parameter()]
        [switch]
        $AllowNullKeys,

        [Parameter()]
        [string]
        $OutputDirectory
    )

    $resolvedPath   = (Resolve-Path $Path).Path
    $fileName       = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
    $moduleFileName = [System.IO.Path]::GetFileName($resolvedPath)

    if (-not $OutputDirectory) {
        $OutputDirectory = Split-Path $resolvedPath -Parent
    }
    if (-not (Test-Path $OutputDirectory)) {
        $null = New-Item -Path $OutputDirectory -ItemType Directory -Force
    }

    $resources = @(Get-DscResourceAstInfo -Path $resolvedPath)
    if ($resources.Count -eq 0) {
        throw "No DSC resource classes found in '$Path'."
    }

    Write-Verbose "Found $($resources.Count) DSC resource class(es): $($resources.ClassName -join ', ')"

    $scriptFileName = 'resource.ps1'
    $resourceScriptPath = $null

    if ($GenerateResourceScript) {
        $scriptContent      = New-DscResourceAdapterScript -ResourceInfos $resources -ModuleFileName $moduleFileName
        $resourceScriptPath = Join-Path $OutputDirectory $scriptFileName
        Set-Content -Path $resourceScriptPath -Value $scriptContent -Encoding UTF8 -NoNewline
        Write-Verbose "Generated resource adapter script: $resourceScriptPath"
    }

    $manifestEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($resource in $resources) {
        $entryParams = @{
            ResourceInfo       = $resource
            ResourceTypePrefix = $ResourceTypePrefix
            Version            = $Version
            UseResourceScript  = $GenerateResourceScript
            ScriptFileName     = $scriptFileName
            ModuleFileName     = $moduleFileName
            AllowNullKeys      = $AllowNullKeys
        }
        if ($Description)  { $entryParams['Description'] = $Description }
        if ($Executable)   { $entryParams['Executable']  = $Executable  }

        $manifestEntries.Add((New-DscManifestEntry @entryParams))
    }

    if ($manifestEntries.Count -eq 1) {
        $manifestFileName = "$fileName.dsc.resource.json"
        $manifestContent  = $manifestEntries[0]
    } else {
        $manifestFileName = "$fileName.dsc.manifests.json"
        $manifestContent  = [ordered]@{
            resources = @($manifestEntries)
        }
    }

    $manifestPath = Join-Path $OutputDirectory $manifestFileName
    $json = $manifestContent | ConvertTo-Json -Depth 20
    Set-Content -Path $manifestPath -Value $json -Encoding UTF8 -NoNewline
    Write-Verbose "Generated manifest: $manifestPath"

    [PSCustomObject]@{
        ManifestPath       = $manifestPath
        ResourceScriptPath = $resourceScriptPath
        ResourceCount      = $resources.Count
        ResourceNames      = @($resources.ClassName)
    }
}
