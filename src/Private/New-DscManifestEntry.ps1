function New-DscManifestEntry {
    <#
        .SYNOPSIS
            Builds a single DSC v3 resource manifest entry (ordered dictionary)
            for one class-based DSC resource.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ResourceInfo,

        [Parameter()]
        [string]$ResourceTypePrefix,

        [Parameter()]
        [string]$Version = '0.1.0',

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string]$Executable,

        [Parameter()]
        [string]$ScriptFileName,

        [Parameter()]
        [string]$ModuleFileName,

        [Parameter()]
        [switch]$UseResourceScript,

        [Parameter()]
        [switch]$AllowNullKeys
    )

    $resourceType = if ($ResourceTypePrefix) {
        $trimmedPrefix = $ResourceTypePrefix.TrimEnd('/')
        "$trimmedPrefix/$($ResourceInfo.ClassName)"
    } else {
        $ResourceInfo.ClassName
    }

    $desc = if ($Description) { $Description }
            elseif ($ResourceInfo.PSObject.Properties['Synopsis'] -and $ResourceInfo.Synopsis) { $ResourceInfo.Synopsis }
            elseif ($ResourceInfo.PSObject.Properties['Description'] -and $ResourceInfo.Description) { $ResourceInfo.Description }
            else { "DSC resource for managing $($ResourceInfo.ClassName)." }

    $resolvedExe = if ($Executable) { $Executable } else { '<executable>' }

    $manifest = [ordered]@{
        '$schema'   = $script:DscManifestSchemaUri
        type        = $resourceType
        version     = $Version
        description = $desc
        exitCodes   = [ordered]@{
            '0' = 'Success'
            '1' = 'Error'
            '2' = 'Invalid JSON'
        }
        schema = [ordered]@{
            embedded = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ResourceInfo -AllowNullKeys:$AllowNullKeys
        }
    }

    $detectedMethods = $ResourceInfo.Methods
    if (-not $detectedMethods -or $detectedMethods.Count -eq 0) {
        $detectedMethods = @('Get', 'Set', 'Test')
    }

    foreach ($method in $detectedMethods) {
        $methodLower = $method.ToLower()

        if ($UseResourceScript) {
            $manifest[$methodLower] = [ordered]@{
                executable = 'pwsh'
                args       = @(
                    '-NoLogo'
                    '-NonInteractive'
                    '-File'
                    $ScriptFileName
                    '-Operation'
                    $methodLower
                    '-ResourceType'
                    $ResourceInfo.ClassName
                    [ordered]@{ jsonInputArg = '-InputJson'; mandatory = $true }
                )
            }
        } else {
            $manifest[$methodLower] = [ordered]@{
                executable = $resolvedExe
                args       = @(
                    $methodLower
                    '--resource'
                    $resourceType
                    [ordered]@{ jsonInputArg = '--input'; mandatory = $true }
                )
            }
        }
    }

    return $manifest
}
