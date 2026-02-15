BeforeAll {
    $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\DscSchemaBuilder.psd1')).Path
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DscSchemaBuilder -Force -ErrorAction Ignore
}

Describe 'New-DscManifestEntry' -Tag 'Unit' {

    BeforeAll {
        $script:resourceInfo = [PSCustomObject]@{
            ClassName  = 'MyResource'
            BaseClass  = $null
            Methods    = @('Get','Set','Test')
            SourceFile = 'MyModule.psm1'
            Properties = @(
                [PSCustomObject]@{
                    Name = 'Name'; TypeName = 'string'
                    IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                    ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                    Description = $null
                }
            )
        }
    }

    Context 'Placeholder mode (no resource script)' {
        It 'Should set $schema to DSC manifest schema' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri
                $entry.'$schema' | Should -Be $script:DscManifestSchemaUri
            }
        }

        It 'Should set resource type to class name when no prefix' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri
                $entry.type | Should -Be 'MyResource'
            }
        }

        It 'Should prepend prefix when ResourceTypePrefix is given' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri -ResourceTypePrefix 'Contoso.Apps'
                $entry.type | Should -Be 'Contoso.Apps/MyResource'
            }
        }

        It 'Should add get/set/test entries for detected methods' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri
                $entry.Keys | Should -Contain 'get'
                $entry.Keys | Should -Contain 'set'
                $entry.Keys | Should -Contain 'test'
            }
        }

        It 'Should NOT add delete when class has no Delete method' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri
                $entry.Keys | Should -Not -Contain 'delete'
            }
        }

        It 'Should use placeholder executable when Executable is not given' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri
                $entry.get.executable | Should -Be '<executable>'
            }
        }

        It 'Should use provided Executable' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri -Executable 'my-tool.exe'
                $entry.get.executable | Should -Be 'my-tool.exe'
            }
        }

        It 'Should include embedded schema' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri
                $entry.schema.embedded | Should -Not -BeNullOrEmpty
                $entry.schema.embedded.'$schema' | Should -Be 'https://json-schema.org/draft/2020-12/schema'
            }
        }
    }

    Context 'Resource script mode (UseResourceScript)' {
        It 'Should set executable to "pwsh"' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri -UseResourceScript `
                    -ScriptFileName 'resource.ps1' -ModuleFileName 'MyModule.psm1'
                $entry.get.executable | Should -Be 'pwsh'
            }
        }

        It 'Should include -File, -Operation, -ResourceType, and jsonInputArg in args' {
            InModuleScope DscSchemaBuilder -Parameters @{ ri = $resourceInfo } {
                param($ri)
                $entry = New-DscManifestEntry -ResourceInfo $ri -UseResourceScript `
                    -ScriptFileName 'resource.ps1' -ModuleFileName 'MyModule.psm1'

                $args = $entry.get.args
                $args | Should -Contain '-File'
                $args | Should -Contain 'resource.ps1'
                $args | Should -Contain '-Operation'
                $args | Should -Contain 'get'
                $args | Should -Contain '-ResourceType'
                $args | Should -Contain 'MyResource'
            }
        }
    }

    Context 'Default methods when class has no detected methods' {
        It 'Should default to get/set/test' {
            InModuleScope DscSchemaBuilder {
                $ri = [PSCustomObject]@{
                    ClassName  = 'EmptyMethods'
                    BaseClass  = $null
                    Methods    = @()
                    SourceFile = 'test.ps1'
                    Properties = @(
                        [PSCustomObject]@{
                            Name = 'Id'; TypeName = 'string'
                            IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                            ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                            Description = $null
                        }
                    )
                }
                $entry = New-DscManifestEntry -ResourceInfo $ri
                $entry.Keys | Should -Contain 'get'
                $entry.Keys | Should -Contain 'set'
                $entry.Keys | Should -Contain 'test'
            }
        }
    }

    Context 'Resource with Delete and Export methods' {
        It 'Should include delete and export entries' {
            InModuleScope DscSchemaBuilder {
                $ri = [PSCustomObject]@{
                    ClassName  = 'FullResource'
                    BaseClass  = $null
                    Methods    = @('Get','Set','Test','Delete','Export')
                    SourceFile = 'test.ps1'
                    Properties = @(
                        [PSCustomObject]@{
                            Name = 'Id'; TypeName = 'string'
                            IsKey = $true; IsMandatory = $false; IsNotConfigurable = $false
                            ValidateSetValues = $null; EnumValues = $null; DefaultValue = $null
                            Description = $null
                        }
                    )
                }
                $entry = New-DscManifestEntry -ResourceInfo $ri
                $entry.Keys | Should -Contain 'delete'
                $entry.Keys | Should -Contain 'export'
            }
        }
    }
}
