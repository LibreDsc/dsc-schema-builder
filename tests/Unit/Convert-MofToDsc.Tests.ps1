BeforeAll {
    $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\src\DscSchemaBuilder.psd1')).Path
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DscSchemaBuilder -Force -ErrorAction Ignore
}

Describe 'Convert-MofToDsc' -Tag 'Unit' {

    BeforeAll {
        # A minimal MOF with two resources and a DependsOn relationship
        $script:mofContent = @'
instance of MSFT_FileDirectoryConfiguration as $MSFT_FileDirectoryConfiguration1ref
{
 ResourceID = "[File]TempDir";
 DestinationPath = "C:\\Temp";
 Ensure = "Present";
 Type = "Directory";
 SourceInfo = "C:\\Config\\MyConfig.ps1::5::9::File";
 ModuleName = "PSDesiredStateConfiguration";
 ModuleVersion = "1.1";
 ConfigurationName = "MyConfig";
};

instance of MSFT_FileDirectoryConfiguration as $MSFT_FileDirectoryConfiguration2ref
{
 ResourceID = "[File]TestFile";
 DestinationPath = "C:\\Temp\\test.txt";
 Contents = "Hello, World!";
 Ensure = "Present";
 Type = "File";
 DependsOn = {"[File]TempDir"};
 SourceInfo = "C:\\Config\\MyConfig.ps1::12::9::File";
 ModuleName = "PSDesiredStateConfiguration";
 ModuleVersion = "1.1";
 ConfigurationName = "MyConfig";
};
'@

        $script:mofPath = Join-Path $TestDrive 'test.mof'
        Set-Content -Path $script:mofPath -Value $script:mofContent -Encoding UTF8
    }

    Context 'JSON output (default)' {

        BeforeAll {
            $script:result = Convert-MofToDsc -Path $script:mofPath
            $script:doc = $script:result | ConvertFrom-Json
        }

        It 'Should return valid JSON' {
            { $script:result | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should include the DSC v3 $schema URI' {
            $script:doc.'$schema' | Should -Be 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
        }

        It 'Should contain the correct number of resources' {
            $script:doc.resources.Count | Should -Be 2
        }

        It 'Should set resource type using ModuleName and ResourceType' {
            $script:doc.resources[0].type | Should -Be 'PSDesiredStateConfiguration/File'
            $script:doc.resources[1].type | Should -Be 'PSDesiredStateConfiguration/File'
        }

        It 'Should extract instance name from ResourceID' {
            $script:doc.resources[0].name | Should -Be 'TempDir'
            $script:doc.resources[1].name | Should -Be 'TestFile'
        }

        It 'Should exclude MOF metadata properties from resource properties' {
            $props = $script:doc.resources[0].properties
            $propNames = $props.PSObject.Properties.Name
            $propNames | Should -Not -Contain 'ResourceID'
            $propNames | Should -Not -Contain 'SourceInfo'
            $propNames | Should -Not -Contain 'ModuleName'
            $propNames | Should -Not -Contain 'ModuleVersion'
            $propNames | Should -Not -Contain 'ConfigurationName'
            $propNames | Should -Not -Contain 'DependsOn'
        }

        It 'Should include configurable properties' {
            $script:doc.resources[0].properties.DestinationPath | Should -Be 'C:\Temp'
            $script:doc.resources[0].properties.Ensure | Should -Be 'Present'
            $script:doc.resources[1].properties.Contents | Should -Be 'Hello, World!'
        }

        It 'Should convert DependsOn to resourceId() format' {
            $script:doc.resources[1].dependsOn | Should -Not -BeNullOrEmpty
            $script:doc.resources[1].dependsOn[0] | Should -Be "[resourceId('PSDesiredStateConfiguration/File', 'TempDir')]"
        }

        It 'Should not include dependsOn when resource has no dependencies' {
            $script:doc.resources[0].PSObject.Properties.Name | Should -Not -Contain 'dependsOn'
        }
    }

    Context 'YAML output (-ToYaml)' {

        BeforeAll {
            $script:yamlResult = Convert-MofToDsc -Path $script:mofPath -ToYaml
        }

        It 'Should return a string' {
            $script:yamlResult | Should -BeOfType [string]
        }

        It 'Should contain the $schema URI' {
            $script:yamlResult | Should -Match 'https://aka\.ms/dsc/schemas/v3/bundled/config/document\.json'
        }

        It 'Should contain resource type entries' {
            $script:yamlResult | Should -Match 'type: PSDesiredStateConfiguration/File'
        }

        It 'Should contain resource names' {
            $script:yamlResult | Should -Match 'name: TempDir'
            $script:yamlResult | Should -Match 'name: TestFile'
        }

        It 'Should contain dependsOn with resourceId reference' {
            $script:yamlResult | Should -Match 'dependsOn'
            $script:yamlResult | Should -Match "resourceId\("
        }

        It 'Should not contain JSON braces' {
            $script:yamlResult | Should -Not -Match '^\s*\{' 
        }
    }

    Context 'ResourceTypePrefix parameter' {

        BeforeAll {
            $script:prefixResult = Convert-MofToDsc -Path $script:mofPath -ResourceTypePrefix 'Contoso.DSC'
            $script:prefixDoc = $script:prefixResult | ConvertFrom-Json
        }

        It 'Should use the custom prefix instead of ModuleName' {
            $script:prefixDoc.resources[0].type | Should -Be 'Contoso.DSC/File'
            $script:prefixDoc.resources[1].type | Should -Be 'Contoso.DSC/File'
        }

        It 'Should use the custom prefix in dependsOn resourceId references' {
            $script:prefixDoc.resources[1].dependsOn[0] | Should -Be "[resourceId('Contoso.DSC/File', 'TempDir')]"
        }
    }

    Context 'Error handling' {

        It 'Should write an error for a non-existent file' {
            $err = $null
            Convert-MofToDsc -Path (Join-Path $TestDrive 'nonexistent.mof') -ErrorVariable err -ErrorAction SilentlyContinue
            $err | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Pipeline input' {

        It 'Should accept path from pipeline' {
            $result = $script:mofPath | Convert-MofToDsc
            $doc = $result | ConvertFrom-Json
            $doc.resources.Count | Should -Be 2
        }

        It 'Should accept FileInfo from pipeline via FullName alias' {
            $result = Get-Item $script:mofPath | Convert-MofToDsc
            $doc = $result | ConvertFrom-Json
            $doc.resources.Count | Should -Be 2
        }
    }
}

