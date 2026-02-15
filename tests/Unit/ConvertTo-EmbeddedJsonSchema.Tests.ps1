BeforeAll {
    $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\DscSchemaBuilder.psd1')).Path
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DscSchemaBuilder -Force -ErrorAction Ignore
}

Describe 'ConvertTo-EmbeddedJsonSchema' -Tag 'Unit' {

    BeforeAll {
        $script:resourceInfo = [PSCustomObject]@{
            ClassName  = 'TestWidget'
            BaseClass  = $null
            Methods    = @('Get','Set','Test')
            SourceFile = 'test.ps1'
            Properties = @(
                [PSCustomObject]@{
                    Name = 'Name'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                [PSCustomObject]@{
                    Name = 'Enabled'; TypeName = 'Nullable[bool]'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                [PSCustomObject]@{
                    Name = 'Mode'; TypeName = 'string'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = @('Fast','Slow'); EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                [PSCustomObject]@{
                    Name = 'Tags'; TypeName = 'string[]'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                [PSCustomObject]@{
                    Name = 'ReadOnlyState'; TypeName = 'string'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $true
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
            )
        }
    }

    It 'Should set $schema to JSON Schema 2020-12' {
        InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
            param($ri)
            $schema = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ri
            $schema.'$schema' | Should -Be 'https://json-schema.org/draft/2020-12/schema'
        }
    }

    It 'Should set type to "object"' {
        InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
            param($ri)
            $schema = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ri
            $schema.type | Should -Be 'object'
        }
    }

    It 'Should set additionalProperties to false' {
        InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
            param($ri)
            $schema = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ri
            $schema.additionalProperties | Should -BeFalse
        }
    }

    It 'Should populate the required array with Key properties' {
        InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
            param($ri)
            $schema = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ri
            $schema.required | Should -Contain 'Name'
        }
    }

    It 'Should NOT include non-Key non-Mandatory properties in required' {
        InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
            param($ri)
            $schema = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ri
            $schema.required | Should -Not -Contain 'Enabled'
            $schema.required | Should -Not -Contain 'Mode'
        }
    }

    It 'Should include NotConfigurable properties with readOnly flag' {
        InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
            param($ri)
            $schema = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ri
            $schema.properties.Keys | Should -Contain 'ReadOnlyState'
            $schema.properties.ReadOnlyState.readOnly | Should -BeTrue
        }
    }

    It 'Should include all configurable properties' {
        InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
            param($ri)
            $schema = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ri
            $schema.properties.Keys | Should -Contain 'Name'
            $schema.properties.Keys | Should -Contain 'Enabled'
            $schema.properties.Keys | Should -Contain 'Mode'
            $schema.properties.Keys | Should -Contain 'Tags'
        }
    }

    It 'Should generate a title from the class name' {
        InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
            param($ri)
            $schema = ConvertTo-EmbeddedJsonSchema -ResourceInfo $ri
            $schema.title | Should -Be 'TestWidget Schema'
        }
    }
}
