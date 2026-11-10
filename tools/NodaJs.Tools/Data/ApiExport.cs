using System.Reflection;
using NodaJs.Tools.Common;
// ReSharper disable MemberHidesStaticFromOuterClass

namespace NodaJs.Tools.Data;

/// <summary>NodaTime's public API (kinds and signatures), which each port's API test checks itself against.</summary>
internal static class ApiExport
{
    private static readonly string[] ExcludedNamespaces = ["NodaTime.Annotations", "NodaTime.HighPerformance", "NodaTime.Xml"];

    // Not ported (docs/api-differences.md).
    private static readonly HashSet<string> BclInteropTypes =
    [
        "System.DateTime", "System.DateTimeOffset", "System.TimeSpan", "System.DateOnly", "System.TimeOnly",
        "System.TimeZoneInfo", "System.TimeProvider", "System.Diagnostics.Stopwatch", "System.DayOfWeek",
        "System.Xml.XmlReader", "System.Xml.XmlWriter", "System.Xml.Schema.XmlSchema", "System.Xml.Schema.XmlSchemaSet",
        "System.Xml.XmlQualifiedName", "System.ComponentModel.ITypeDescriptorContext", "System.Type",
    ];

    private const BindingFlags Declared = BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;

    public static void Run(GeneratedFiles output)
    {
        var types = ReflectionExports.NodaTimeAssembly.GetExportedTypes()
            .Where(t => !ExcludedNamespaces.Contains(t.Namespace))
            .OrderBy(t => t.FullName, StringComparer.Ordinal)
            .Select(t => new ApiType(t, t.IsEnum ? [] : Members(t).ToList()))
            .ToList();
        foreach (var port in LangTarget.All)
        {
            var body = port.NewWriter();
            switch (body)
            {
                case TypescriptWriter:
                    body.WriteLine("import type { ApiType } from \"./types.ts\";", emptyLineAfter: true)
                        .OpenBlock("export const NodaTimeApi: readonly ApiType[] = [");
                    break;
                case DartWriter:
                    body.WriteLine("import 'types.dart';", emptyLineAfter: true)
                        .OpenBlock("const List<ApiType> NodaTimeApi = [");
                    break;
                default:
                    body.ThrowUnknown();
                    break;
            }
            foreach (var apiType in types)
            {
                var type = apiType.Type;
                body.OpenObjectLine("ApiType")
                    .Property("name", body.Str(ReflectionExports.FlatTypeName(type)))
                    .Property("fullName", body.Str(type.FullName))
                    .Property("kind", body.Str(Kind(type)));
                if (type.IsEnum)
                {
                    body.Property("members", "[]")
                        .CloseObjectLine();
                    continue;
                }
                body.OpenBlock("members: [");
                foreach (var member in apiType.Members)
                    body.WriteLine(body.Object("ApiMember", new
                    {
                        name = body.Str(member.Name),
                        csName = body.Str(member.CsName),
                        kind = body.Str(member.Kind),
                        isStatic = body.Bool(member.IsStatic),
                        signatures = body.List(member.Signatures.Select(body.Str)),
                        bclInterop = member.BclInterop ? body.Bool(true) : null,
                    }) + ",");
                body.CloseBlock("],")
                    .CloseObjectLine();
            }
            body.CloseBlock("];");
            output.Write(port.Test("api/nodatime-api"), "api", body,
                ["Source: NodaTime's public API, by reflection."]);
        }
    }

    private static string Kind(Type type) =>
        type.IsEnum ? "enum" :
        type.IsInterface ? "interface" :
        type.IsValueType ? "struct" :
        typeof(Delegate).IsAssignableFrom(type) ? "delegate" :
        type.IsAbstract && type.IsSealed ? "static class" :
        "class";

    private sealed record ApiType(Type Type, IReadOnlyList<Member> Members);

    private sealed record Member(string Name, string CsName, string Kind, bool IsStatic, List<string> Signatures, bool BclInterop);

    private sealed record MemberKey(string Name, string Kind, bool IsStatic);

    private static IEnumerable<Member> Members(Type type)
    {
        var members = new Dictionary<MemberKey, Member>();
        void Add(string csName, string kind, bool isStatic, string signature, bool bcl)
        {
            var name = kind == "constructor" ? "constructor" : csName;
            var key = new MemberKey(name, kind, isStatic);
            if (!members.TryGetValue(key, out var member))
            {
                member = new Member(name, csName, kind, isStatic, [], true);
                members[key] = member;
            }
            member.Signatures.Add(signature);
            if (!bcl)
                members[key] = member with { BclInterop = false };
        }

        foreach (var ctor in type.GetConstructors(BindingFlags.Public | BindingFlags.Instance))
            Add(".ctor", 
                "constructor", 
                false, 
                Parameters(ctor),
                UsesBcl(ctor.GetParameters().Select(p => p.ParameterType)));
        foreach (var property in type.GetProperties(Declared).OrderBy(p => p.MetadataToken))
        {
            if (property.GetIndexParameters().Length > 0)
            {
                Add("Item",
                    "indexer", 
                    false, 
                    $"[{string.Join(", ", property.GetIndexParameters().Select(p => $"{TypeName(p.ParameterType)} {p.Name}"))}]: {TypeName(property.PropertyType)}", 
                    false);
                continue;
            }
            var isStatic = (property.GetMethod ?? property.SetMethod)!.IsStatic;
            Add(property.Name, 
                "property", 
                isStatic, 
                $"{TypeName(property.PropertyType)}{(property.SetMethod?.IsPublic == true ? " { get; set; }" : "")}", 
                UsesBcl([property.PropertyType]));
        }
        foreach (var field in type.GetFields(Declared).OrderBy(f => f.MetadataToken))
            Add(field.Name, 
                field.IsLiteral ? "const" : "field", 
                field.IsStatic, 
                TypeName(field.FieldType), 
                UsesBcl([field.FieldType]));
        foreach (var method in type.GetMethods(Declared).OrderBy(m => m.MetadataToken))
        {
            if (method.IsSpecialName && !method.Name.StartsWith("op_", StringComparison.Ordinal))
                continue; // property accessors, events
            
            if ((method.Name is "GetHashCode" or "Deconstruct" or "GetSchema" or "ReadXml" or "WriteXml" or "AddSchema") ||
                (method.Name == "CompareTo" && method.GetParameters() is [{ ParameterType: var p }] && p == typeof(object)))
                continue;
            
            var kind = method.Name.StartsWith("op_", StringComparison.Ordinal) ? "operator" : "method";
            var types = method.GetParameters().Select(p => p.ParameterType).Append(method.ReturnType);
            Add(method.Name, kind, method.IsStatic, $"{Parameters(method)}: {TypeName(method.ReturnType)}", UsesBcl(types));
        }
        return members.Values;
    }

    private static string Parameters(MethodBase method) =>
        "(" + string.Join(", ", method.GetParameters().Select(p => $"{(p.IsOut ? "out " : "")}{TypeName(p.ParameterType)} {p.Name}")) + ")";

    private static bool UsesBcl(IEnumerable<Type> types) => types.Any(UsesBcl);

    private static bool UsesBcl(Type type)
    {
        while (true)
        {
            if (type.HasElementType)
            {
                type = type.GetElementType()!;
                continue;
            }

            if (type.IsGenericType)
                return type.GetGenericArguments().Any(UsesBcl);

            return BclInteropTypes.Contains(type.FullName ?? "") || 
                   type.Name.StartsWith("Bcl", StringComparison.Ordinal);
        }
    }

    private static string TypeName(Type type)
    {
        if (type.IsByRef)
            return TypeName(type.GetElementType()!);
        
        if (type.IsArray)
            return TypeName(type.GetElementType()!) + "[]";
        
        if (Nullable.GetUnderlyingType(type) is { } underlying)
            return TypeName(underlying) + "?";
        
        if (type.IsGenericType)
        {
            var name = type.Name[..type.Name.IndexOf('`')];
            return $"{name}<{string.Join(", ", type.GetGenericArguments().Select(TypeName))}>";
        }
        
        return type.FullName switch
        {
            "System.Int32" => "int",
            "System.Int64" => "long",
            "System.Double" => "double",
            "System.String" => "string",
            "System.Boolean" => "bool",
            "System.Void" => "void",
            "System.Object" => "object",
            "System.Char" => "char",
            "System.Byte" => "byte",
            _ => type.Name,
        };
    }
}
