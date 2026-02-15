function Convert-MofToDsc
{
    <#
    .SYNOPSIS
        Converts a compiled MOF file into a Microsoft DSC configuration document.

    .DESCRIPTION
        Parses a compiled MOF file and produces a Microsoft DSC configuration document in
        JSON (default) or YAML format. MOF metadata properties are excluded, DependsOn
        references are converted to DSC resourceId() syntax, and resource types are
        derived from the MOF ModuleName and ResourceType.

    .PARAMETER Path
        Path to the compiled MOF file (.mof). Accepts pipeline input and FileInfo
        objects via the FullName property.

    .PARAMETER ResourceTypePrefix
        Optional prefix for resource types (e.g. 'Microsoft.DSC'). When not specified,
        the ModuleName from each MOF instance is used.

    .PARAMETER ToYaml
        When specified, outputs the DSC configuration document in YAML format instead
        of JSON.

    .EXAMPLE
        Convert-MofToDsc -Path .\localhost.mof

        Converts the MOF file to a Microsoft DSC JSON configuration document.

    .EXAMPLE
        Convert-MofToDsc -Path .\localhost.mof -ToYaml

        Converts the MOF file to a Microsoft DSC YAML configuration document.

    .EXAMPLE
        Get-Item .\localhost.mof | Convert-MofToDsc -ResourceTypePrefix 'Contoso.DSC'

        Converts the MOF file using a custom resource type prefix.

    .NOTES
        Authors: LibreDsc
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string] $Path,

        [Parameter()]
        [string] $ResourceTypePrefix,

        [Parameter()]
        [switch] $ToYaml
    )

    process
    {
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

        if (-not (Test-Path -LiteralPath $resolvedPath))
        {
            Write-Error -Message "MOF file not found: $resolvedPath" `
                -Category ObjectNotFound `
                -TargetObject $resolvedPath `
                -ErrorId 'MofFileNotFound'
            return
        }

        try
        {
            $mofContent = [System.IO.File]::ReadAllText($resolvedPath)
            $prefix = if ($PSBoundParameters.ContainsKey('ResourceTypePrefix')) { $ResourceTypePrefix } else { $null }
            [DscSchemaBuilder.MofConverter]::Convert($mofContent, $prefix, $ToYaml.IsPresent)
        }
        catch
        {
            Write-Error -Message "Failed to parse MOF file: $_" `
                -Category ParserError `
                -TargetObject $resolvedPath `
                -ErrorId 'MofParseError'
        }
    }
}
