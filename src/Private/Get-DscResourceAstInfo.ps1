function Get-DscResourceAstInfo {
    <#
        .SYNOPSIS
            Parses a PowerShell file using AST and extracts DSC resource class
            metadata including properties, methods, and enum definitions.
        .DESCRIPTION
            Uses System.Management.Automation.Language.Parser to build the AST
            for the supplied file.  Finds every class decorated with
            [DscResource()] and returns property / method metadata that
            downstream functions need to generate manifests and JSON Schema.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $tokens      = $null
    $parseErrors = $null
    $resolvedPath = (Resolve-Path $Path).Path

    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $resolvedPath,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if ($parseErrors.Count -gt 0) {
        # Only throw on true syntax errors, not type-resolution errors
        # (e.g. missing base class types that are defined elsewhere).
        $fatalErrors = @($parseErrors | Where-Object {
            $_.ErrorId -notin @('TypeNotFound', 'DscResourceMissingKeyProperty')
        })
        if ($fatalErrors.Count -gt 0) {
            $msgs = $fatalErrors | ForEach-Object { $_.Message }
            throw "Failed to parse '$Path': $($msgs -join '; ')"
        }
    }

    # ── Extract .PARAMETER descriptions from comment-based help ──
    $parameterDescriptions = @{}
    $helpComment = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -or
        $node -is [System.Management.Automation.Language.ScriptBlockAst]
    }, $false) | ForEach-Object {
        if ($_.GetHelpContent()) { $_.GetHelpContent() }
    } | Select-Object -First 1

    if (-not $helpComment) {
        # Try the top-level script block help
        $helpComment = $ast.GetHelpContent()
    }

    if ($helpComment -and $helpComment.Parameters) {
        foreach ($key in $helpComment.Parameters.Keys) {
            $desc = ($helpComment.Parameters[$key] -join ' ').Trim()
            if (-not [string]::IsNullOrWhiteSpace($desc)) {
                $parameterDescriptions[$key] = $desc
            }
        }
    }

    # Extract synopsis and description from comment-based help
    $helpSynopsis = if ($helpComment -and $helpComment.Synopsis) {
        ($helpComment.Synopsis).Trim()
    } else { $null }

    $helpDescription = if ($helpComment -and $helpComment.Description) {
        ($helpComment.Description).Trim()
    } else { $null }

    $enumDefs = @{}
    $enumAsts = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.TypeDefinitionAst] -and
        $node.IsEnum
    }, $true)

    foreach ($enumAst in $enumAsts) {
        $enumDefs[$enumAst.Name] = @($enumAst.Members | ForEach-Object { $_.Name })
    }

    $classAsts = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.TypeDefinitionAst] -and
        -not $node.IsEnum -and
        ($node.Attributes | Where-Object {
            $_ -is [System.Management.Automation.Language.AttributeAst] -and
            $_.TypeName.Name -ieq 'DscResource'
        })
    }, $true)

    foreach ($classAst in $classAsts) {
        $properties = [System.Collections.Generic.List[PSCustomObject]]::new()
        $methods    = [System.Collections.Generic.List[string]]::new()

        foreach ($member in $classAst.Members) {
            if ($member -is [System.Management.Automation.Language.PropertyMemberAst]) {
                # Skip hidden members
                if ($member.IsHidden) { continue }

                # Must have [DscProperty()] attribute
                $dscAttrs = @($member.Attributes | Where-Object {
                    $_ -is [System.Management.Automation.Language.AttributeAst] -and
                    $_.TypeName.Name -ieq 'DscProperty'
                })
                if ($dscAttrs.Count -eq 0) { continue }

                $isKey             = $false
                $isMandatory       = $false
                $isNotConfigurable = $false

                foreach ($attr in $dscAttrs) {
                    foreach ($namedArg in $attr.NamedArguments) {
                        # If the expression was omitted (e.g. [DscProperty(Key)])
                        # the implicit value is $true.
                        $isArgTrue = $namedArg.ExpressionOmitted
                        if (-not $isArgTrue) {
                            try   { $isArgTrue = [bool]$namedArg.Argument.SafeGetValue() }
                            catch { $isArgTrue = $true }
                        }

                        if ($isArgTrue) {
                            switch ($namedArg.ArgumentName) {
                                'Key'             { $isKey             = $true }
                                'Mandatory'       { $isMandatory       = $true }
                                'NotConfigurable' { $isNotConfigurable = $true }
                            }
                        }
                    }
                }

                # PropertyType is a direct accessor for the type constraint
                # (NOT in the Attributes collection).
                $typeName = 'System.Object'
                if ($member.PropertyType) {
                    $typeName = $member.PropertyType.TypeName.FullName
                }

                $validateSetValues = $null
                $validateSetAttr = $member.Attributes | Where-Object {
                    $_ -is [System.Management.Automation.Language.AttributeAst] -and
                    $_.TypeName.Name -ieq 'ValidateSet'
                }
                if ($validateSetAttr) {
                    $validateSetValues = @($validateSetAttr.PositionalArguments | ForEach-Object {
                        if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                            $_.Value
                        } else {
                            try   { $_.SafeGetValue() }
                            catch { $_.ToString()     }
                        }
                    })
                }

                $enumValues = $null
                $typeInfo   = Resolve-PropertyTypeInfo -TypeName $typeName
                if ($enumDefs.ContainsKey($typeInfo.BaseType)) {
                    $enumValues = $enumDefs[$typeInfo.BaseType]
                }

                $defaultValue = $null
                if ($member.InitialValue) {
                    try   { $defaultValue = $member.InitialValue.SafeGetValue() }
                    catch { <# complex default — skip #> }
                }

                $propDescription = if ($parameterDescriptions.ContainsKey($member.Name)) {
                    $parameterDescriptions[$member.Name]
                } else { $null }

                $properties.Add([PSCustomObject]@{
                    Name              = $member.Name
                    TypeName          = $typeName
                    IsKey             = $isKey
                    IsMandatory       = $isMandatory
                    IsNotConfigurable = $isNotConfigurable
                    ValidateSetValues = $validateSetValues
                    EnumValues        = $enumValues
                    DefaultValue      = $defaultValue
                    Description       = $propDescription
                })
            }
            elseif ($member -is [System.Management.Automation.Language.FunctionMemberAst]) {
                if (-not $member.IsHidden -and
                    $member.Name -in @('Get','Set','Test','Delete','Export')) {
                    $methods.Add($member.Name)
                }
            }
        }

        [PSCustomObject]@{
            ClassName   = $classAst.Name
            BaseClass   = if ($classAst.BaseTypes.Count -gt 0) {
                              $classAst.BaseTypes[0].TypeName.Name
                          } else { $null }
            Properties  = $properties.ToArray()
            Methods     = $methods.ToArray()
            SourceFile  = $resolvedPath
            Synopsis    = $helpSynopsis
            Description = $helpDescription
        }
    }
}
