function ConvertTo-EmbeddedJsonSchema {
    <#
        .SYNOPSIS
            Builds a complete JSON Schema 2020-12 object from the properties
            of a DSC resource class.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ResourceInfo,

        [Parameter()]
        [switch]$AllowNullKeys
    )

    $requiredNames = @(
        $ResourceInfo.Properties |
            Where-Object { $_.IsKey -or $_.IsMandatory } |
            ForEach-Object { $_.Name }
    )

    $properties = [ordered]@{}
    foreach ($prop in $ResourceInfo.Properties) {
        $isRequired = $prop.IsKey -or $prop.IsMandatory
        $forceNullable = $AllowNullKeys -and $prop.IsKey
        $propSchema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired:$isRequired -ReadOnly:$prop.IsNotConfigurable -ForceNullable:$forceNullable
        $properties[$prop.Name] = $propSchema
    }

    $schema = [ordered]@{
        '$schema'            = 'https://json-schema.org/draft/2020-12/schema'
        type                 = 'object'
        title                = "$($ResourceInfo.ClassName) Schema"
        description          = "Schema for $($ResourceInfo.ClassName) DSC resource."
        additionalProperties = $false
        properties           = $properties
    }

    if ($requiredNames.Count -gt 0) {
        $schema['required'] = @($requiredNames)
    }

    return $schema
}
