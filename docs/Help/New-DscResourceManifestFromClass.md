---
document type: cmdlet
external help file: DscSchemaBuilder-Help.xml
HelpUri: ''
Locale: en-US
Module Name: DscSchemaBuilder
ms.date: 02/15/2026
PlatyPS schema version: 2024-05-01
title: New-DscResourceManifestFromClass
---

# New-DscResourceManifestFromClass

## SYNOPSIS

Generates a Microsoft Desired State Configuration (DSC) resource manifest from PowerShell class-based DSC resources.

## SYNTAX

### __AllParameterSets

```powershell
New-DscResourceManifestFromClass [-Path] <string> [-ResourceTypePrefix <string>] [-Version <string>]
 [-Description <string>] [-Executable <string>] [-GenerateResourceScript] [-AllowNullKeys]
 [-OutputDirectory <string>] [<CommonParameters>]
```

## DESCRIPTION

The function `New-DscResourceManifestFromClass` generates a Microsoft DSC resource manifest by analyzing PowerShell class definitions 
decorated with the `[DscResource()]` attribute.
It uses the Abstract Syntax Tree (AST) to inspect the structure of the classes and 
their members, extracting necessary information to create a manifest that describes the DSC resources.

`New-DscResourceManifestFromClass` accepts a path to a `.ps1` or `.psm1` file containing one or more `[DscResource()]` decorated PowerShell classes.
It then parses the file to identify classes that are decorated with `[DscResource()]`.
For each identified class, the
function inspects its properties and methods to determine the characteristics of the DSC resource,
such as which properties are keys, mandatory, or have specific validation attributes.

It also checks for the presence of methods like Get, Set, Test, Delete, and Export to determine the operations supported by the resource.

When `-GenerateResourceScript` is specified a `resource.ps1` wrapper
file is also written.
 This script bridges the class-based DSC resource model
to the model DSC expects, allowing the manifest to point to it for execution.

## EXAMPLES

### EXAMPLE 1

New-DscResourceManifestFromClass -Path .Microsoft.Windows.Settings.psm1 `
    -ResourceTypePrefix 'Microsoft.Windows' `
    -GenerateResourceScript `
    -AllowNullKeys

## PARAMETERS

### -AllowNullKeys

By default, properties decorated with [DscProperty(Key)] are considered required and must have a non-null value.
When -AllowNullKeys is specified, key properties are allowed to have null values, making them optional in the generated manifest.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Description

Optional description applied to every resource entry.
 When omitted a sensible default is generated from the class name.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Executable

Executable path to embed in the manifest operation entries.
 
Only used when `-GenerateResourceScript` is NOT specified (placeholder mode).
 Defaults to "<executable>".

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -GenerateResourceScript

When specified, a resource.ps1 wrapper script is generated
alongside the manifest and the manifest entries point to it.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -OutputDirectory

Directory where the manifest (and optional script) are written.
Defaults to the directory of the input file.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Path

Path to a `.ps1` or `.psm1` file containing one or more `[DscResource()]` decorated PowerShell classes.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ResourceTypePrefix

Optional namespace prefix for the resource type.
Example: "MyOrg.Windows" → type becomes "MyOrg.Windows/ClassName".

Defaults to "LibreDsc.Tutorial"

```yaml
Type: System.String
DefaultValue: LibreDsc.Tutorial
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Version

Semantic version string for all generated resources.
Defaults to "0.1.0".

```yaml
Type: System.String
DefaultValue: 0.1.0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Management.Automation.PSObject

## NOTES

Author: LibreDsc

## RELATED LINKS
