using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Kingsland.MofParser.Models.Types;
using Kingsland.MofParser.Models.Values;
using Kingsland.MofParser.Parsing;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace DscSchemaBuilder;

/// <summary>
/// Converts a compiled MOF file into a Microsoft DSC configuration document (JSON or YAML).
/// This is a plain class library intended to be called from a PowerShell function wrapper.
/// </summary>
public static class MofConverter
{
    private const string DscConfigSchemaUri = "https://aka.ms/dsc/schemas/v3/bundled/config/document.json";
    private static readonly HashSet<string> MetadataProperties = new(StringComparer.OrdinalIgnoreCase)
    {
        "ResourceID",
        "SourceInfo",
        "ModuleName",
        "ModuleVersion",
        "DependsOn",
        "ConfigurationName"
    };

    // MOF class names that represent document metadata rather than DSC resources
    private static readonly HashSet<string> SkippedTypeNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "OMI_ConfigurationDocument"
    };

    // Regex to parse MOF ResourceID: [ResourceType]InstanceName
    private static readonly Regex ResourceIdPattern = new(@"^\[(.+?)\](.+)$", RegexOptions.Compiled);

    /// <summary>
    /// Extracts the string content from a property value.
    /// The Kingsland MOF parser may return StringValue or EnumValue for quoted strings.
    /// </summary>
    private static string? GetStringValue(PropertyValue value)
    {
        return value switch
        {
            StringValue sv => sv.Value,
            EnumValue ev => ev.Name,
            _ => null
        };
    }

    /// <summary>
    /// Converts MOF file content to a DSC configuration document string.
    /// </summary>
    /// <param name="mofContent">The raw text content of the MOF file.</param>
    /// <param name="resourceTypePrefix">Optional prefix for resource types. When null, ModuleName from the MOF is used.</param>
    /// <param name="toYaml">When true, outputs YAML instead of JSON.</param>
    /// <returns>The DSC configuration document as a JSON or YAML string.</returns>
    public static string Convert(string mofContent, string? resourceTypePrefix = null, bool toYaml = false)
    {
        var module = Parser.ParseText(mofContent);

        // First pass: build a lookup from MOF ResourceID (e.g. "[File]TestFile")
        // to the resolved DSC type and instance name, so DependsOn can reference them.
        var resourceLookup = new Dictionary<string, (string DscType, string Name)>(StringComparer.OrdinalIgnoreCase);

        foreach (var instance in module.Instances)
        {
            if (SkippedTypeNames.Contains(instance.TypeName))
            {
                continue;
            }

            var (resourceId, dscType, name) = ResolveResourceIdentity(instance, resourceTypePrefix);
            if (resourceId is not null)
            {
                resourceLookup[resourceId] = (dscType, name);
            }
        }

        // Second pass: convert each instance to a DSC resource, resolving DependsOn
        var resources = new List<Dictionary<string, object?>>();

        foreach (var instance in module.Instances)
        {
            if (SkippedTypeNames.Contains(instance.TypeName))
            {
                continue;
            }

            var resource = ConvertInstanceToResource(instance, resourceLookup, resourceTypePrefix);
            if (resource is not null)
            {
                resources.Add(resource);
            }
        }

        var configDocument = new Dictionary<string, object?>
        {
            ["$schema"] = DscConfigSchemaUri,
            ["resources"] = resources
        };

        if (toYaml)
        {
            var serializer = new SerializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                .ConfigureDefaultValuesHandling(DefaultValuesHandling.OmitNull)
                .Build();

            return serializer.Serialize(configDocument).TrimEnd();
        }
        else
        {
            var jsonOptions = new JsonSerializerOptions
            {
                WriteIndented = true,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
            };

            return JsonSerializer.Serialize(configDocument, jsonOptions);
        }
    }

    /// <summary>
    /// Extracts the MOF ResourceID string, resolved DSC type, and instance name from an instance.
    /// </summary>
    private static (string? ResourceId, string DscType, string Name) ResolveResourceIdentity(
        Instance instance, string? resourceTypePrefix)
    {
        string? resourceId = null;
        string? resourceType = null;
        string? instanceName = null;
        string? moduleName = null;

        var resourceIdProp = instance.Properties.FirstOrDefault(p =>
            string.Equals(p.Name, "ResourceID", StringComparison.OrdinalIgnoreCase));

        if (resourceIdProp is not null)
        {
            resourceId = GetStringValue(resourceIdProp.Value);
            if (resourceId is not null)
            {
                var match = ResourceIdPattern.Match(resourceId);
                if (match.Success)
                {
                    resourceType = match.Groups[1].Value;
                    instanceName = match.Groups[2].Value;
                }
            }
        }

        var moduleNameProp = instance.Properties.FirstOrDefault(p =>
            string.Equals(p.Name, "ModuleName", StringComparison.OrdinalIgnoreCase));

        if (moduleNameProp is not null)
        {
            moduleName = GetStringValue(moduleNameProp.Value);
        }

        var prefix = !string.IsNullOrEmpty(resourceTypePrefix) ? resourceTypePrefix
                   : !string.IsNullOrEmpty(moduleName) ? moduleName
                   : instance.TypeName;
        var dscType = resourceType is not null
            ? $"{prefix}/{resourceType}"
            : $"{prefix}/{instance.TypeName}";

        var name = instanceName ?? instance.Alias ?? instance.TypeName;

        return (resourceId, dscType, name);
    }

    private static Dictionary<string, object?>? ConvertInstanceToResource(
        Instance instance,
        Dictionary<string, (string DscType, string Name)> resourceLookup,
        string? resourceTypePrefix)
    {
        var (_, dscType, name) = ResolveResourceIdentity(instance, resourceTypePrefix);

        // Resolve DependsOn to DSC resourceId() references
        // MOF format:  DependsOn = {"[File]TestFile"};
        // DSC format:  "dependsOn": ["[resourceId('PSDesiredStateConfiguration/File', 'TestFile')]"]
        var dependsOn = new List<string>();
        var dependsOnProp = instance.Properties.FirstOrDefault(p =>
            string.Equals(p.Name, "DependsOn", StringComparison.OrdinalIgnoreCase));

        if (dependsOnProp is not null)
        {
            IEnumerable<PropertyValue> depValues = dependsOnProp.Value switch
            {
                LiteralValueArray lva => lva.Values,
                _ => new[] { dependsOnProp.Value }
            };

            foreach (var depValue in depValues)
            {
                var depString = GetStringValue(depValue);
                if (depString is not null)
                {
                    if (resourceLookup.TryGetValue(depString, out var target))
                    {
                        dependsOn.Add($"[resourceId('{target.DscType}', '{target.Name}')]");
                    }
                    else
                    {
                        var depMatch = ResourceIdPattern.Match(depString);
                        if (depMatch.Success)
                        {
                            var depName = depMatch.Groups[2].Value;
                            var depType = depMatch.Groups[1].Value;
                            var prefix = !string.IsNullOrEmpty(resourceTypePrefix) ? resourceTypePrefix : depType;
                            dependsOn.Add($"[resourceId('{prefix}/{depType}', '{depName}')]");
                        }
                        else
                        {
                            dependsOn.Add(depString);
                        }
                    }
                }
            }
        }

        // Collect configurable properties, excluding MOF metadata
        var properties = new Dictionary<string, object?>();

        foreach (var prop in instance.Properties)
        {
            if (MetadataProperties.Contains(prop.Name))
            {
                continue;
            }

            properties[prop.Name] = ConvertPropertyValue(prop.Value);
        }

        var resource = new Dictionary<string, object?>
        {
            ["type"] = dscType,
            ["name"] = name
        };

        if (dependsOn.Count > 0)
        {
            resource["dependsOn"] = dependsOn;
        }

        if (properties.Count > 0)
        {
            resource["properties"] = properties;
        }

        return resource;
    }

    private static object? ConvertPropertyValue(PropertyValue value)
    {
        return value switch
        {
            StringValue sv => sv.Value,
            EnumValue ev => ev.Name,
            IntegerValue iv => iv.Value,
            BooleanValue bv => bv.Value,
            RealValue rv => rv.Value,
            NullValue => null,
            LiteralValueArray lva => lva.Values
                .Select(ConvertPropertyValue)
                .ToArray(),
            _ => value.ToString()
        };
    }
}
