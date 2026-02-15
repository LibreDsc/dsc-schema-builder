---
document type: cmdlet
external help file: DscSchemaBuilder-Help.xml
HelpUri: ''
Locale: en-US
Module Name: DscSchemaBuilder
ms.date: 02/15/2026
PlatyPS schema version: 2024-05-01
title: Convert-MofToDsc
---

# Convert-MofToDsc

## SYNOPSIS

Converts a compiled MOF file into a Microsoft DSC configuration document.

## SYNTAX

### __AllParameterSets

```powershell
Convert-MofToDsc [-Path] <string> [-ResourceTypePrefix <string>] [-ToYaml] [<CommonParameters>]
```

## DESCRIPTION

Parses a compiled MOF file and produces a Microsoft DSC configuration document in
JSON (default) or YAML format.
MOF metadata properties are excluded, DependsOn
references are converted to DSC resourceId() syntax, and resource types are
derived from the MOF ModuleName and ResourceType.

## EXAMPLES

### EXAMPLE 1

Convert-MofToDsc -Path .\localhost.mof

Converts the MOF file to a Microsoft DSC JSON configuration document.

### EXAMPLE 2

Convert-MofToDsc -Path .\localhost.mof -ToYaml

Converts the MOF file to a Microsoft DSC YAML configuration document.

### EXAMPLE 3

Get-Item .\localhost.mof | Convert-MofToDsc -ResourceTypePrefix 'Contoso.DSC'

Converts the MOF file using a custom resource type prefix.

## PARAMETERS

### -Path

Path to the compiled MOF file (.mof).
Accepts pipeline input and FileInfo
objects via the FullName property.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases:
- FullName
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ResourceTypePrefix

Optional prefix for resource types (e.g.
'Microsoft.DSC').
When not specified,
the ModuleName from each MOF instance is used.

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

### -ToYaml

When specified, outputs the DSC configuration document in YAML format instead
of JSON.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

{{ Fill in the Description }}

## OUTPUTS

### System.String

## NOTES

