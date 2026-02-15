function ConvertTo-JsonSchemaProperty {
    <#
        .SYNOPSIS
            Converts a single DSC property info object to a JSON Schema 2020-12
            property definition (returned as an ordered dictionary).
        .DESCRIPTION
            Handles type mapping, Nullable → null union, array → items,
            ValidateSet / enum → enum keyword, and default values.
            Only explicitly Nullable[] typed properties are made nullable.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PropertyInfo,

        [Parameter()]
        [switch]$IsRequired,

        [Parameter()]
        [switch]$ReadOnly,

        [Parameter()]
        [switch]$ForceNullable
    )

    $schema   = [ordered]@{}

    if ($ReadOnly) {
        $schema['readOnly'] = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($PropertyInfo.Description)) {
        $schema['description'] = $PropertyInfo.Description
    }

    $typeInfo = Resolve-PropertyTypeInfo -TypeName $PropertyInfo.TypeName

    $shouldBeNullable = $typeInfo.IsNullable -or $ForceNullable

    $enumValues = $PropertyInfo.ValidateSetValues
    if (-not $enumValues -and $PropertyInfo.EnumValues) {
        $enumValues = $PropertyInfo.EnumValues
    }

    if ($enumValues) {
        $schema['enum'] = @($enumValues)

        if ($null -ne $PropertyInfo.DefaultValue) {
            $schema['default'] = $PropertyInfo.DefaultValue
        }
        return $schema
    }

    if ($typeInfo.IsArray) {
        $elementType = ConvertTo-JsonBaseType -TypeName $typeInfo.BaseType
        $schema['type']  = 'array'
        $schema['items'] = [ordered]@{ type = $elementType }

        if ($null -ne $PropertyInfo.DefaultValue) {
            $schema['default'] = $PropertyInfo.DefaultValue
        }
        return $schema
    }

    $jsonType = ConvertTo-JsonBaseType -TypeName $typeInfo.BaseType

    if ($shouldBeNullable) {
        $schema['type'] = @($jsonType, 'null')
    } else {
        $schema['type'] = $jsonType
    }

    if ($null -ne $PropertyInfo.DefaultValue) {
        $schema['default'] = $PropertyInfo.DefaultValue
    }

    return $schema
}
