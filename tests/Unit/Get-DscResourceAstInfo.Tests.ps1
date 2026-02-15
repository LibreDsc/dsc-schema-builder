BeforeAll {
    $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\DscSchemaBuilder.psd1')).Path
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DscSchemaBuilder -Force -ErrorAction Ignore
}

Describe 'Get-DscResourceAstInfo' -Tag 'Unit' {

    Context 'Single resource class with various property types' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'SingleResource.ps1'
            @'
[DscResource()]
class TestResource {
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [string] $Description

    [DscProperty()]
    [Nullable[bool]] $Enabled

    [DscProperty()]
    [ValidateSet('Low', 'Medium', 'High')]
    [string] $Priority

    [DscProperty()]
    [string[]] $Tags

    [DscProperty()]
    [Nullable[System.Int32]] $Count

    hidden [string] $InternalState

    [TestResource] Get()    { return $this }
    [void] Set()            { }
    [bool] Test()           { return $true }
}
'@ | Set-Content $tempFile

            $script:result = InModuleScope DscSchemaBuilder -Parameters @{ f = $tempFile } {
                param($f)
                Get-DscResourceAstInfo -Path $f
            }
        }

        It 'Should return exactly one resource' {
            @($result).Count | Should -Be 1
        }

        It 'Should detect the class name' {
            $result.ClassName | Should -Be 'TestResource'
        }

        It 'Should have no base class' {
            $result.BaseClass | Should -BeNullOrEmpty
        }

        It 'Should find the Key property' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Name' }
            $prop.IsKey | Should -BeTrue
        }

        It 'Should mark non-Key properties correctly' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Description' }
            $prop.IsKey | Should -BeFalse
            $prop.IsMandatory | Should -BeFalse
        }

        It 'Should detect Nullable[bool] type name' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Enabled' }
            $prop.TypeName | Should -Be 'Nullable[bool]'
        }

        It 'Should detect Nullable[System.Int32] type name' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Count' }
            $prop.TypeName | Should -Be 'Nullable[System.Int32]'
        }

        It 'Should detect ValidateSet values' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Priority' }
            $prop.ValidateSetValues | Should -Be @('Low', 'Medium', 'High')
        }

        It 'Should detect array type' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Tags' }
            $prop.TypeName | Should -Be 'string[]'
        }

        It 'Should exclude hidden properties' {
            $result.Properties.Name | Should -Not -Contain 'InternalState'
        }

        It 'Should detect Get, Set, Test methods' {
            $result.Methods | Should -Contain 'Get'
            $result.Methods | Should -Contain 'Set'
            $result.Methods | Should -Contain 'Test'
        }

        It 'Should NOT list Delete or Export' {
            $result.Methods | Should -Not -Contain 'Delete'
            $result.Methods | Should -Not -Contain 'Export'
        }
    }

    Context 'Multiple resource classes in one file' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'MultiResource.psm1'
            @'
[DscResource()]
class ResourceA {
    [DscProperty(Key)]
    [string] $Id

    [ResourceA] Get()  { return $this }
    [void] Set()       { }
    [bool] Test()      { return $true }
}

[DscResource()]
class ResourceB {
    [DscProperty(Key)]
    [string] $Name

    [DscProperty(Mandatory)]
    [int] $Count

    [ResourceB] Get()  { return $this }
    [void] Set()       { }
    [bool] Test()      { return $true }
    [void] Delete()    { }
}
'@ | Set-Content $tempFile

            $script:results = @(InModuleScope DscSchemaBuilder -Parameters @{ f = $tempFile } {
                param($f)
                Get-DscResourceAstInfo -Path $f
            })
        }

        It 'Should return two resources' {
            $results.Count | Should -Be 2
        }

        It 'Should detect both class names' {
            $results.ClassName | Should -Contain 'ResourceA'
            $results.ClassName | Should -Contain 'ResourceB'
        }

        It 'Should detect Mandatory property on ResourceB' {
            $resB = $results | Where-Object { $_.ClassName -eq 'ResourceB' }
            $countProp = $resB.Properties | Where-Object { $_.Name -eq 'Count' }
            $countProp.IsMandatory | Should -BeTrue
        }

        It 'Should detect Delete method on ResourceB' {
            $resB = $results | Where-Object { $_.ClassName -eq 'ResourceB' }
            $resB.Methods | Should -Contain 'Delete'
        }
    }

    Context 'Resource with custom enum type' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'EnumResource.ps1'
            @'
enum Ensure {
    Present
    Absent
}

[DscResource()]
class EnumTestResource {
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [Ensure] $Ensure

    [EnumTestResource] Get() { return $this }
    [void] Set()             { }
    [bool] Test()            { return $true }
}
'@ | Set-Content $tempFile

            $script:result = InModuleScope DscSchemaBuilder -Parameters @{ f = $tempFile } {
                param($f)
                Get-DscResourceAstInfo -Path $f
            }
        }

        It 'Should resolve enum values for custom enum property' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Ensure' }
            $prop.EnumValues | Should -Contain 'Present'
            $prop.EnumValues | Should -Contain 'Absent'
        }
    }

    Context 'Resource with base class' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'InheritedResource.ps1'
            @'
[DscResource()]
class ChildResource : SomeBase {
    [DscProperty(Key)]
    [string] $Id

    [ChildResource] Get() { return $this }
    [void] Set()          { }
    [bool] Test()         { return $true }
}
'@ | Set-Content $tempFile

            $script:result = InModuleScope DscSchemaBuilder -Parameters @{ f = $tempFile } {
                param($f)
                Get-DscResourceAstInfo -Path $f
            }
        }

        It 'Should detect the base class name' {
            $result.BaseClass | Should -Be 'SomeBase'
        }
    }

    Context 'File with no DSC resources' {
        It 'Should throw when no DSC resource class is found (via public command)' {
            $tempFile = Join-Path $TestDrive 'NoResource.ps1'
            @'
class RegularClass {
    [string] $Name
}
'@ | Set-Content $tempFile

            { New-DscResourceManifestFromClass -Path $tempFile } | Should -Throw '*No DSC resource*'
        }
    }

    Context 'Resource with comment-based help .PARAMETER descriptions' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'DescribedResource.psm1'
            @'
<#
.SYNOPSIS
    A test resource with parameter descriptions.

.PARAMETER Path
    The full path to the file to manage. This is a key property.

.PARAMETER Content
    The content that should be in the file.

.PARAMETER FileSize
    The file size in bytes. This is a read-only property.
#>

[DscResource()]
class DescribedResource {
    [DscProperty(Key)]
    [string] $Path

    [DscProperty()]
    [string] $Content

    [DscProperty(NotConfigurable)]
    [long] $FileSize

    [DscProperty()]
    [string] $NoDescription

    [DescribedResource] Get() { return $this }
    [void] Set()              { }
    [bool] Test()             { return $true }
}
'@ | Set-Content $tempFile

            $script:result = InModuleScope DscSchemaBuilder -Parameters @{ f = $tempFile } {
                param($f)
                Get-DscResourceAstInfo -Path $f
            }
        }

        It 'Should extract description for Path parameter' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Path' }
            $prop.Description | Should -Be 'The full path to the file to manage. This is a key property.'
        }

        It 'Should extract description for Content parameter' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'Content' }
            $prop.Description | Should -Be 'The content that should be in the file.'
        }

        It 'Should extract description for NotConfigurable parameter' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'FileSize' }
            $prop.Description | Should -Be 'The file size in bytes. This is a read-only property.'
        }

        It 'Should have null description when no .PARAMETER block exists' {
            $prop = $result.Properties | Where-Object { $_.Name -eq 'NoDescription' }
            $prop.Description | Should -BeNullOrEmpty
        }
    }
}
