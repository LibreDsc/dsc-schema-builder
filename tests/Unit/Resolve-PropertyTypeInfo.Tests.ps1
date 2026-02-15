BeforeAll {
    $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\DscSchemaBuilder.psd1')).Path
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DscSchemaBuilder -Force -ErrorAction Ignore
}

Describe 'Resolve-PropertyTypeInfo' -Tag 'Unit' {

    Context 'Simple types' {
        It 'Should identify a plain string type' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'string'
                $r.IsNullable | Should -BeFalse
                $r.IsArray    | Should -BeFalse
                $r.BaseType   | Should -Be 'string'
            }
        }

        It 'Should identify System.String' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'System.String'
                $r.BaseType | Should -Be 'System.String'
            }
        }

        It 'Should identify bool' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'bool'
                $r.IsNullable | Should -BeFalse
                $r.BaseType   | Should -Be 'bool'
            }
        }

        It 'Should identify int' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'int'
                $r.BaseType | Should -Be 'int'
            }
        }
    }

    Context 'Nullable types' {
        It 'Should detect Nullable[bool]' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'Nullable[bool]'
                $r.IsNullable | Should -BeTrue
                $r.BaseType   | Should -Be 'bool'
            }
        }

        It 'Should detect Nullable[System.Boolean]' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'Nullable[System.Boolean]'
                $r.IsNullable | Should -BeTrue
                $r.BaseType   | Should -Be 'System.Boolean'
            }
        }

        It 'Should detect Nullable[System.Int32]' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'Nullable[System.Int32]'
                $r.IsNullable | Should -BeTrue
                $r.BaseType   | Should -Be 'System.Int32'
            }
        }

        It 'Should detect System.Nullable[System.Double]' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'System.Nullable[System.Double]'
                $r.IsNullable | Should -BeTrue
                $r.BaseType   | Should -Be 'System.Double'
            }
        }
    }

    Context 'Array types' {
        It 'Should detect string[]' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'string[]'
                $r.IsArray  | Should -BeTrue
                $r.BaseType | Should -Be 'string'
            }
        }

        It 'Should detect System.Int32[]' {
            InModuleScope DscSchemaBuilder {
                $r = Resolve-PropertyTypeInfo -TypeName 'System.Int32[]'
                $r.IsArray  | Should -BeTrue
                $r.BaseType | Should -Be 'System.Int32'
            }
        }
    }

    Context 'ConvertTo-JsonBaseType mapping' {
        It 'Maps string to "string"' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'string' | Should -Be 'string'
            }
        }

        It 'Maps System.String to "string"' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'System.String' | Should -Be 'string'
            }
        }

        It 'Maps bool to "boolean"' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'bool' | Should -Be 'boolean'
            }
        }

        It 'Maps System.Boolean to "boolean"' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'System.Boolean' | Should -Be 'boolean'
            }
        }

        It 'Maps int to "integer"' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'int' | Should -Be 'integer'
            }
        }

        It 'Maps System.Int32 to "integer"' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'System.Int32' | Should -Be 'integer'
            }
        }

        It 'Maps double to "number"' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'double' | Should -Be 'number'
            }
        }

        It 'Maps System.Double to "number"' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'System.Double' | Should -Be 'number'
            }
        }

        It 'Maps unknown type to "string" as fallback' {
            InModuleScope DscSchemaBuilder {
                ConvertTo-JsonBaseType -TypeName 'SomeCustomType' | Should -Be 'string'
            }
        }
    }
}
