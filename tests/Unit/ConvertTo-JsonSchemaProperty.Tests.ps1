BeforeAll {
    $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\DscSchemaBuilder.psd1')).Path
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DscSchemaBuilder -Force -ErrorAction Ignore
}

Describe 'ConvertTo-JsonSchemaProperty' -Tag 'Unit' {

    Context 'Required string property' {
        It 'Should produce type "string" without null' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Name'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired
                $schema.type | Should -Be 'string'
            }
        }
    }

    Context 'Non-required string property' {
        It 'Should produce type "string" without null (only Nullable[] types get null)' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Desc'; TypeName = 'string'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop
                $schema.type | Should -Be 'string'
            }
        }
    }

    Context 'Nullable[bool] property' {
        It 'Should produce type ["boolean","null"]' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Enabled'; TypeName = 'Nullable[bool]'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop
                $schema.type | Should -Contain 'boolean'
                $schema.type | Should -Contain 'null'
            }
        }
    }

    Context 'Nullable[System.Int32] property (required)' {
        It 'Should still be nullable because the type is explicitly Nullable' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Count'; TypeName = 'Nullable[System.Int32]'
                    IsKey = $false; IsMandatory = $true; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired
                $schema.type | Should -Contain 'integer'
                $schema.type | Should -Contain 'null'
            }
        }
    }

    Context 'System.Double property' {
        It 'Should produce type "number" (not nullable unless explicitly Nullable)' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Size'; TypeName = 'System.Double'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop
                $schema.type | Should -Be 'number'
            }
        }
    }

    Context 'ValidateSet property (required)' {
        It 'Should produce an enum array without null' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Level'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = @('Low','Medium','High'); EnumValues = $null
                    DefaultValue = $null; Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired
                $schema.enum | Should -Be @('Low','Medium','High')
                $schema.Keys | Should -Not -Contain 'type'
            }
        }
    }

    Context 'ValidateSet property (non-required)' {
        It 'Should produce an enum array without null (enums are never nullable)' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Mode'; TypeName = 'string'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = @('Auto','Manual'); EnumValues = $null
                    DefaultValue = $null; Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop
                $schema.enum | Should -Contain 'Auto'
                $schema.enum | Should -Contain 'Manual'
                $schema.enum | Should -Not -Contain $null
            }
        }
    }

    Context 'Custom enum property' {
        It 'Should use EnumValues when ValidateSetValues is absent' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Ensure'; TypeName = 'Ensure'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = @('Present','Absent')
                    DefaultValue = $null; Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop
                $schema.enum | Should -Contain 'Present'
                $schema.enum | Should -Contain 'Absent'
                $schema.enum | Should -Not -Contain $null
            }
        }
    }

    Context 'Array property' {
        It 'Should produce type "array" with items' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Tags'; TypeName = 'string[]'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop
                $schema.type         | Should -Be 'array'
                $schema.items.type   | Should -Be 'string'
            }
        }
    }

    Context 'Property with default value' {
        It 'Should include the default key' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Retries'; TypeName = 'int'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = 3
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop
                $schema.default | Should -Be 3
            }
        }
    }

    Context 'ReadOnly property' {
        It 'Should include readOnly = true when -ReadOnly is specified' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Status'; TypeName = 'string'
                    IsKey = $false; IsMandatory = $false; IsNotConfigurable = $true
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -ReadOnly
                $schema.readOnly | Should -BeTrue
                $schema.type | Should -Be 'string'
            }
        }

        It 'Should NOT include readOnly when -ReadOnly is not specified' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Name'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired
                $schema.Keys | Should -Not -Contain 'readOnly'
            }
        }
    }

    Context 'Property with description' {
        It 'Should include description when provided' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Path'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = 'The full path to the file to manage. This is a key property.'
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired
                $schema.description | Should -Be 'The full path to the file to manage. This is a key property.'
            }
        }

        It 'Should NOT include description when null or empty' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Name'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired
                $schema.Keys | Should -Not -Contain 'description'
            }
        }
    }

    Context 'ForceNullable switch' {
        It 'Should make a plain string property nullable when -ForceNullable is specified' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'SID'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired -ForceNullable
                $schema.type | Should -Contain 'string'
                $schema.type | Should -Contain 'null'
            }
        }

        It 'Should make an integer property nullable when -ForceNullable is specified' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Id'; TypeName = 'int'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired -ForceNullable
                $schema.type | Should -Contain 'integer'
                $schema.type | Should -Contain 'null'
            }
        }

        It 'Should NOT make a property nullable when -ForceNullable is not specified' {
            InModuleScope DscSchemaBuilder {
                $prop = [PSCustomObject]@{
                    Name = 'Name'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
                $schema = ConvertTo-JsonSchemaProperty -PropertyInfo $prop -IsRequired
                $schema.type | Should -Be 'string'
            }
        }
    }
}
