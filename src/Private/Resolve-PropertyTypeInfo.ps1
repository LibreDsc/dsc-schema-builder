function Resolve-PropertyTypeInfo {
    <#
        .SYNOPSIS
            Parses a PowerShell type name string and extracts nullability, array,
            and base type information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$TypeName
    )

    $result = [PSCustomObject]@{
        IsNullable = $false
        IsArray    = $false
        BaseType   = $TypeName
    }

    if ($TypeName -match '^(.+)\[\]$') {
        $result.IsArray  = $true
        $result.BaseType = $Matches[1]
        return $result
    }

    if ($TypeName -match '^(?:System\.)?Nullable\[(.+)\]$') {
        $result.IsNullable = $true
        $result.BaseType   = $Matches[1]
        return $result
    }

    return $result
}

function ConvertTo-JsonBaseType {
    <#
        .SYNOPSIS
            Maps a .NET / PowerShell type name to its JSON Schema type string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$TypeName
    )

    switch -Regex ($TypeName) {
        '^(string|System\.String)$'                                                                        { return 'string'  }
        '^(bool|boolean|System\.Boolean)$'                                                                 { return 'boolean' }
        '^(int|int32|int16|int64|long|byte|uint16|uint32|uint64|System\.Int32|System\.Int16|System\.Int64|System\.Byte|System\.UInt16|System\.UInt32|System\.UInt64)$' {
            return 'integer'
        }
        '^(double|float|single|decimal|System\.Double|System\.Single|System\.Decimal)$'                    { return 'number'  }
        default                                                                                            { return 'string'  }
    }
}
