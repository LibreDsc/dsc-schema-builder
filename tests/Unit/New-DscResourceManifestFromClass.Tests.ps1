BeforeAll {
    $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\DscSchemaBuilder.psd1')).Path
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DscSchemaBuilder -Force -ErrorAction Ignore
}

Describe 'New-DscResourceManifestFromClass' -Tag 'Integration' {

    Context 'Single resource class to .dsc.resource.json' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'Widget.ps1'
            @'
[DscResource()]
class Widget {
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [string] $Color

    [DscProperty()]
    [Nullable[bool]] $Active

    [DscProperty()]
    [ValidateSet('Small','Medium','Large')]
    [string] $Size

    [Widget] Get()   { return $this }
    [void] Set()     { }
    [bool] Test()    { return $true }
}
'@ | Set-Content $tempFile

            $script:result = New-DscResourceManifestFromClass -Path $tempFile -OutputDirectory $TestDrive
        }

        It 'Should produce a .dsc.resource.json file' {
            $result.ManifestPath | Should -BeLike '*.dsc.resource.json'
            Test-Path $result.ManifestPath | Should -BeTrue
        }

        It 'Should report one resource' {
            $result.ResourceCount | Should -Be 1
        }

        It 'Should not produce a resource script by default' {
            $result.ResourceScriptPath | Should -BeNullOrEmpty
        }

        It 'Should produce valid JSON' {
            { Get-Content $result.ManifestPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should contain correct resource type' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.type | Should -Be 'LibreDsc.Tutorial/Widget'
        }

        It 'Should contain embedded schema with required property' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.required | Should -Contain 'Name'
        }

        It 'Should NOT mark non-required string as nullable (only explicit Nullable[] types)' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.properties.Color.type | Should -Be 'string'
        }

        It 'Should mark Nullable[bool] property as nullable' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.properties.Active.type | Should -Contain 'boolean'
            $json.schema.embedded.properties.Active.type | Should -Contain 'null'
        }

        It 'Should emit enum for ValidateSet property' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.properties.Size.enum | Should -Contain 'Small'
            $json.schema.embedded.properties.Size.enum | Should -Contain 'Medium'
            $json.schema.embedded.properties.Size.enum | Should -Contain 'Large'
        }

        It 'Should have get/set/test entries' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.get | Should -Not -BeNullOrEmpty
            $json.set | Should -Not -BeNullOrEmpty
            $json.test | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Multiple resource classes to .dsc.manifests.json' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'MultiRes.psm1'
            @'
[DscResource()]
class Alpha {
    [DscProperty(Key)]
    [string] $Id

    [Alpha] Get()  { return $this }
    [void] Set()   { }
    [bool] Test()  { return $true }
}

[DscResource()]
class Beta {
    [DscProperty(Key)]
    [string] $Name

    [DscProperty(Mandatory)]
    [int] $Priority

    [Beta] Get()   { return $this }
    [void] Set()   { }
    [bool] Test()  { return $true }
}
'@ | Set-Content $tempFile

            $script:result = New-DscResourceManifestFromClass -Path $tempFile -OutputDirectory $TestDrive
        }

        It 'Should produce a .dsc.manifests.json file' {
            $result.ManifestPath | Should -BeLike '*.dsc.manifests.json'
            Test-Path $result.ManifestPath | Should -BeTrue
        }

        It 'Should report two resources' {
            $result.ResourceCount | Should -Be 2
        }

        It 'Should wrap resources in a resources array' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.resources.Count | Should -Be 2
        }

        It 'Should have both resource types' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.resources.type | Should -Contain 'LibreDsc.Tutorial/Alpha'
            $json.resources.type | Should -Contain 'LibreDsc.Tutorial/Beta'
        }
    }

    Context 'With -ResourceTypePrefix' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'Prefixed.ps1'
            @'
[DscResource()]
class Gadget {
    [DscProperty(Key)]
    [string] $Id

    [Gadget] Get()  { return $this }
    [void] Set()    { }
    [bool] Test()   { return $true }
}
'@ | Set-Content $tempFile

            $script:result = New-DscResourceManifestFromClass -Path $tempFile `
                -ResourceTypePrefix 'Contoso.Tools' -OutputDirectory $TestDrive
        }

        It 'Should prefix the resource type' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.type | Should -Be 'Contoso.Tools/Gadget'
        }
    }

    Context 'With -GenerateResourceScript' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'Scripted.psm1'
            @'
[DscResource()]
class ScriptedRes {
    [DscProperty(Key)]
    [string] $Id

    [ScriptedRes] Get()  { return $this }
    [void] Set()         { }
    [bool] Test()        { return $true }
}
'@ | Set-Content $tempFile

            $script:result = New-DscResourceManifestFromClass -Path $tempFile `
                -GenerateResourceScript -OutputDirectory $TestDrive
        }

        It 'Should produce a resource.ps1 file' {
            $result.ResourceScriptPath | Should -Not -BeNullOrEmpty
            Test-Path $result.ResourceScriptPath | Should -BeTrue
        }

        It 'Should set manifest executable to pwsh' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.get.executable | Should -Be 'pwsh'
        }

        It 'Should reference resource.ps1 in the manifest args' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.get.args | Should -Contain 'resource.ps1'
        }

        It 'Should generate a parseable PowerShell script' {
            $content = Get-Content $result.ResourceScriptPath -Raw
            $tokens = $null
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }
    }

    Context 'With -Version and -Description' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'Versioned.ps1'
            @'
[DscResource()]
class Versioned {
    [DscProperty(Key)]
    [string] $Id

    [Versioned] Get()  { return $this }
    [void] Set()       { }
    [bool] Test()      { return $true }
}
'@ | Set-Content $tempFile

            $script:result = New-DscResourceManifestFromClass -Path $tempFile `
                -Version '2.0.0' -Description 'Custom description' -OutputDirectory $TestDrive
        }

        It 'Should use the given version' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.version | Should -Be '2.0.0'
        }

        It 'Should use the given description' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.description | Should -Be 'Custom description'
        }
    }

    Context 'Resource with Delete and Export methods' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'FullOps.ps1'
            @'
[DscResource()]
class FullOps {
    [DscProperty(Key)]
    [string] $Id

    [FullOps] Get()  { return $this }
    [void] Set()     { }
    [bool] Test()    { return $true }
    [void] Delete()  { }
    [void] Export()  { }
}
'@ | Set-Content $tempFile

            $script:result = New-DscResourceManifestFromClass -Path $tempFile -OutputDirectory $TestDrive
        }

        It 'Should include delete entry' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.delete | Should -Not -BeNullOrEmpty
        }

        It 'Should include export entry' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.export | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Resource with enum type defined in same file' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'WithEnum.ps1'
            @'
enum Ensure {
    Present
    Absent
}

[DscResource()]
class WithEnum {
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [Ensure] $Ensure

    [WithEnum] Get()  { return $this }
    [void] Set()      { }
    [bool] Test()     { return $true }
}
'@ | Set-Content $tempFile

            $script:result = New-DscResourceManifestFromClass -Path $tempFile -OutputDirectory $TestDrive
        }

        It 'Should resolve enum values into the schema' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.properties.Ensure.enum | Should -Contain 'Present'
            $json.schema.embedded.properties.Ensure.enum | Should -Contain 'Absent'
        }
    }

    Context 'With -AllowNullKeys' {
        BeforeAll {
            $tempFile = Join-Path $TestDrive 'NullableKey.ps1'
            @'
[DscResource()]
class NullableKey {
    [DscProperty(Key)]
    [string] $SID

    [DscProperty()]
    [string] $Color

    [DscProperty(Mandatory)]
    [int] $Priority

    [NullableKey] Get()  { return $this }
    [void] Set()         { }
    [bool] Test()        { return $true }
}
'@ | Set-Content $tempFile

            $script:result = New-DscResourceManifestFromClass -Path $tempFile -AllowNullKeys -OutputDirectory $TestDrive
        }

        It 'Should make Key property type a nullable array' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.properties.SID.type | Should -Contain 'string'
            $json.schema.embedded.properties.SID.type | Should -Contain 'null'
        }

        It 'Should still include Key property in required list' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.required | Should -Contain 'SID'
        }

        It 'Should NOT make non-key properties nullable' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.properties.Color.type | Should -Be 'string'
        }

        It 'Should NOT make Mandatory (non-key) properties nullable' {
            $json = Get-Content $result.ManifestPath -Raw | ConvertFrom-Json
            $json.schema.embedded.properties.Priority.type | Should -Be 'integer'
        }
    }
}
