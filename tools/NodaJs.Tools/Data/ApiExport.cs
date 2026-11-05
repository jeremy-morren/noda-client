using System.Reflection;
using NodaJs.Tools.Common;
// ReSharper disable MemberHidesStaticFromOuterClass

namespace NodaJs.Tools.Data;

/// <summary>
/// NodaTime's public API, by reflection: every public type and member, with its kind (property vs
/// method, static vs instance) and signatures. test/api/api.test.ts checks noda-js against it, so a C#
/// property must be a TS getter, a method must be a method, and nothing goes missing unnoticed.
/// </summary>
internal static class ApiExport
{
    private static readonly string[] ExcludedNamespaces = ["NodaTime.Annotations", "NodaTime.HighPerformance", "NodaTime.Xml"];

    // Types from .NET that noda-js deliberately doesn't interoperate with (docs/api-differences.md).
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
            .OrderBy(t => t.FullName, StringComparer.Ordinal);
        var body = new TypescriptWriter()
            .WriteLine("import type { ApiType } from \"./types.ts\";", emptyLineAfter: true)
            .OpenBlock("export const NodaTimeApi: readonly ApiType[] = [");
        foreach (var type in types)
        {
            body.OpenBlock("{")
                .Property("name", Ts.Str(ReflectionExports.TsTypeName(type)))
                .Property("fullName", Ts.Str(type.FullName))
                .Property("kind", Ts.Str(Kind(type)));
            if (type.IsEnum)
            {
                body.Property("members", "[]")
                    .CloseBlock("},");
                continue;
            }
            body.OpenBlock("members: [");
            foreach (var member in Members(type))
                body.WriteLine("{ " +
                               $"name: {Ts.Str(member.Name)}, " +
                               $"csName: {Ts.Str(member.CsName)}, " +
                               $"kind: {Ts.Str(member.Kind)}, " +
                               $"isStatic: {Ts.Bool(member.IsStatic)}, " +
                               $"signatures: [{string.Join(", ", member.Signatures.Select(Ts.Str))}]" +
                               (member.BclInterop ? ", bclInterop: true" : "") +
                               " },");
            body.CloseBlock("],")
                .CloseBlock("},");
        }
        body.CloseBlock("];");
        output.Write("test/api/nodatime-api.generated.ts", "api", body,
            ["Source: public types and members of the NodaTime assembly, by reflection."]);
    }

    private static string Kind(Type type) =>
        type.IsEnum ? "enum" :
        type.IsInterface ? "interface" :
        type.IsValueType ? "struct" :
        typeof(Delegate).IsAssignableFrom(type) ? "delegate" :
        type.IsAbstract && type.IsSealed ? "static class" :
        "class";

    private sealed record Member(string Name, string CsName, string Kind, bool IsStatic, List<string> Signatures, bool BclInterop);

    private static IEnumerable<Member> Members(Type type)
    {
        var members = new Dictionary<(string, string, bool), Member>();
        void Add(string csName, string kind, bool isStatic, string signature, bool bcl)
        {
            // noda-js members keep their C# (PascalCase) names.
            var name = kind == "constructor" ? "constructor" : csName;
            var key = (name, kind, isStatic);
            if (!members.TryGetValue(key, out var member))
            {
                member = new Member(name, csName, kind, isStatic, [], true);
                members[key] = member;
            }
            member.Signatures.Add(signature);
            // A member is BCL-interop only if every overload is.
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
