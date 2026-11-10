using System.Globalization;
using System.Reflection;
using NodaJs.Tools.Common;
using NodaTime;

namespace NodaJs.Tools.Data;

/// <summary>Enums, constants and error messages, from NodaTime's metadata.</summary>
internal static class ReflectionExports
{
    internal static readonly Assembly NodaTimeAssembly = typeof(Instant).Assembly;
    private static readonly DocComments Docs = new(NodaTimeAssembly);

    // Not ported (docs/api-differences.md).
    private static readonly string[] ExcludedNamespaces = ["NodaTime.Annotations", "NodaTime.HighPerformance", "NodaTime.Xml"];

    private const string FlagsNote = "Flags: combine values with `|`.";

    /// <summary>"NodaTime.TimeZones.ZoneEqualityComparer+Options" → "TimeZones/ZoneEqualityComparer.Options".</summary>
    internal static string SourcePath(Type type)
    {
        var outer = type;
        var names = new List<string>();
        while (outer.DeclaringType is not null)
        {
            names.Insert(0, outer.Name);
            outer = outer.DeclaringType;
        }
        names.Insert(0, outer.Name);
        var ns = outer.Namespace!;
        var folder = ns == "NodaTime" ? "" : ns["NodaTime.".Length..].Replace('.', '/') + "/";
        return folder + string.Join(".", names);
    }

    internal static string FlatTypeName(Type type) => DocComments.FlatTypeName(type);

    private static bool IsPortedToTypeScript(Type type)
    {
        var path = Path.Combine(ToolEnvironment.RepoRoot, LangTarget.TypeScript.SourceRoot + SourcePath(type));
        return File.Exists(path + ".ts") || File.Exists(path + ".generated.ts");
    }

    private sealed record EnumModel(Type Type, DocComment? Summary, bool IsInternal, bool IsFlags, IReadOnlyList<EnumMember> Members)
    {
        public string Name => FlatTypeName(Type);

        public IEnumerable<Type> LinkedTypes => Members.Select(m => m.Doc).Append(Summary)
            .SelectMany(d => d?.LinkedTypes ?? new HashSet<Type>())
            .Where(t => t != Type);

        public string[] HeaderLines => [$"Source: {Type.FullName} (enum)"];
    }

    private sealed record EnumMember(string Name, long Value, DocComment? Doc);

    public static void Enums(GeneratedFiles output)
    {
        var enums = NodaTimeAssembly.GetTypes()
            .Where(t => t.IsEnum && !ExcludedNamespaces.Contains(t.Namespace))
            .Where(t => !t.IsDefined(typeof(System.Runtime.CompilerServices.CompilerGeneratedAttribute)))
            .OrderBy(t => t.FullName, StringComparer.Ordinal);
        foreach (var type in enums)
        {
            var model = new EnumModel(
                type,
                Docs.Summary(type),
                !(type.IsPublic || type.IsNestedPublic),
                type.IsDefined(typeof(FlagsAttribute)),
                type.GetFields(BindingFlags.Public | BindingFlags.Static)
                    .OrderBy(f => f.MetadataToken)
                    .Select(f => new EnumMember(f.Name, Convert.ToInt64(f.GetRawConstantValue(), CultureInfo.InvariantCulture), Docs.Summary(f)))
                    .ToList());
            WriteTypeScriptEnum(output, model);
            WriteDartEnum(output, model);
        }
    }

    private static void WriteTypeScriptEnum(GeneratedFiles output, EnumModel model)
    {
        var doc = model.Summary ?? DocComment.Empty;
        if (model.IsInternal)
            doc = doc.AppendLine("@internal");
        if (model.IsFlags)
            doc = doc.AppendLine(FlagsNote);

        var writer = new TypescriptWriter();
        // So doc links resolve.
        var linked = model.LinkedTypes
            .Where(IsPortedToTypeScript)
            .Select(FlatTypeName)
            .Distinct()
            .Order(StringComparer.Ordinal)
            .ToList();
        if (linked.Count > 0)
        {
            var depth = SourcePath(model.Type).Count(c => c == '/');
            var internalModule = depth == 0 ? "./internal.ts" : string.Concat(Enumerable.Repeat("../", depth)) + "internal.ts";
            writer.WriteLine($"import type {{ {string.Join(", ", linked)} }} from \"{internalModule}\";", emptyLineAfter: true);
        }

        writer.DocComment(doc)
            .OpenBlock($"export enum {model.Name} {{");
        foreach (var member in model.Members)
            writer.DocComment(member.Doc)
                .WriteLine($"{member.Name} = {Ts.SourceInt(member.Value)},");
        writer.CloseBlock("}");
        output.Write(LangTarget.TypeScript.Source(SourcePath(model.Type)), "enums", writer, model.HeaderLines);
    }

    /// <summary>An extension type over <c>int</c> (dart/docs/porting-conventions.md).</summary>
    private static void WriteDartEnum(GeneratedFiles output, EnumModel model)
    {
        var name = model.Name;
        foreach (var member in model.Members)
        {
            if (member.Name is "Name" or "HasFlag" or "value")
                throw new InvalidOperationException($"{model.Type}.{member.Name} clashes with a member of the generated Dart extension type.");
            if (!Dart.IsSafeInteger(member.Value))
                throw new InvalidOperationException($"{model.Type}.{member.Name} = {member.Value} isn't a Dart constant on dart2js.");
        }

        var writer = new DartWriter();
        if (model.IsInternal)
            writer.WriteLine("import 'package:meta/meta.dart';", emptyLineAfter: true);
        var doc = model.Summary ?? DocComment.Empty;
        if (model.IsFlags)
            doc = doc.AppendLine(FlagsNote);
        writer.DocComment(doc);
        if (model.IsInternal)
            writer.WriteLine("@internal");
        writer.OpenBlock($"extension type const {name}(int value) implements Object {{");
        foreach (var member in model.Members)
            writer.DocComment(member.Doc)
                .WriteLine($"static const {name} {member.Name} = {name}({Dart.Int(member.Value)});", emptyLineAfter: true);

        // Sorted by unsigned value.
        var values = Enum.GetValuesAsUnderlyingType(model.Type).Cast<object>()
            .Select(v => Convert.ToInt64(v, CultureInfo.InvariantCulture)).ToList();
        var names = Enum.GetNames(model.Type);
        if (model.IsFlags)
            WriteDartFlagsName(writer, values, names);
        else
            WriteDartName(writer, model.Type, values);
        if (model.IsFlags)
        {
            writer.WriteLine()
                .DocComment("C#'s `|`.")
                .WriteLine($"{name} operator |({name} other) => {name}(value | other.value);", emptyLineAfter: true)
                .DocComment("C#'s `&`.")
                .WriteLine($"{name} operator &({name} other) => {name}(value & other.value);", emptyLineAfter: true)
                .DocComment("C#'s `~`.")
                .WriteLine($"{name} operator ~() => {name}(~value);", emptyLineAfter: true)
                .DocComment(".NET's `Enum.HasFlag`.")
                .WriteLine($"bool HasFlag({name} flag) => (value & flag.value) == flag.value;");
        }
        writer.CloseBlock("}");
        output.Write(LangTarget.Dart.Source(SourcePath(model.Type)), "enums", writer, model.HeaderLines);
    }

    private static void WriteDartName(CodeWriter writer, Type type, IReadOnlyList<long> values)
    {
        writer.DocComment("The value as .NET's `Enum.ToString()` formats it.")
            .OpenBlock("String get Name => switch (value) {");
        foreach (var value in values.Distinct())
            writer.WriteLine($"{Dart.Int(value)} => {Dart.Str(Enum.ToObject(type, value).ToString())},");
        writer.WriteLine("_ => value.toString(),")
            .CloseBlock("};");
    }

    /// <summary>dotnet/runtime's <c>Enum.FormatFlagNames</c>.</summary>
    private static void WriteDartFlagsName(CodeWriter writer, IReadOnlyList<long> values, IReadOnlyList<string> names)
    {
        writer.DocComment("The value as .NET's `Enum.ToString()` formats it.")
            .OpenBlock("String get Name {")
            .WriteLine($"const values = <int>{writer.List(values.Select(v => Dart.Int(v)))};")
            .WriteLine($"const names = <String>{writer.List(names.Select(Dart.Str))};")
            .WriteLine("if (value == 0)")
            .WriteLine("  return values[0] == 0 ? names[0] : '0';")
            .WriteLine("for (var i = values.length - 1; i >= 0; i--)")
            .WriteLine("  if (values[i] == value)")
            .WriteLine("    return names[i];")
            .WriteLine("var remaining = value;")
            .WriteLine("final found = <String>[];")
            .OpenBlock("for (var i = values.length - 1; i >= 0; i--) {")
            .WriteLine("final current = values[i];")
            .WriteLine("if (i == 0 && current == 0)")
            .WriteLine("  break;")
            .OpenBlock("if ((remaining & current) == current) {")
            .WriteLine("remaining &= ~current;")
            .WriteLine("found.add(names[i]);")
            .WriteLine("if (remaining == 0)")
            .WriteLine("  break;")
            .CloseBlock("}")
            .CloseBlock("}")
            .WriteLine("return remaining != 0 ? value.toString() : found.reversed.join(', ');")
            .CloseBlock("}");
    }

    private sealed record ConstantField(string Name, Type Type, object Value, DocComment? Doc);

    public static void Constants(GeneratedFiles output)
    {
        var fields = typeof(NodaConstants).GetFields(BindingFlags.Public | BindingFlags.Static)
            .Where(f => f.IsLiteral)
            .OrderBy(f => f.MetadataToken)
            .Select(f => new ConstantField(f.Name, f.FieldType, f.GetRawConstantValue()!, Docs.Summary(f)))
            .ToList();
        string[] header = ["Source: NodaTime.NodaConstants (const fields)"];

        var ts = new TypescriptWriter();
        foreach (var field in fields)
            ts.DocComment(field.Doc)
                .WriteLine($"export const {field.Name} = {Literal(field.Value)};");
        output.Write(LangTarget.TypeScript.Source("NodaConstants"), "constants", ts, header);

        var dart = new DartWriter();
        foreach (var field in fields)
        {
            var literal = DartLiteral(field.Value);
            dart.DocComment(field.Doc)
                .WriteLine($"{(Dart.IsConstant(literal) ? "const" : "final")} {Dart.TypeName(field.Type)} {field.Name} = {literal};");
        }
        output.Write(LangTarget.Dart.Source("NodaConstants"), "constants", dart, header);
    }

    private sealed record TextErrorMessage(string Name, string Value);

    public static void TextErrorMessages(GeneratedFiles output)
    {
        // Reflection: constants have no storage for NodaTimeInternals' accessors.
        var type = NodaTimeAssembly.GetType("NodaTime.Text.TextErrorMessages", throwOnError: true)!;
        var messages = type.GetFields(BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static)
            .Where(f => f.IsLiteral)
            .OrderBy(f => f.Name, StringComparer.Ordinal)
            .Select(f => new TextErrorMessage(f.Name, (string) f.GetRawConstantValue()!))
            .ToList();
        const string summary = "Common error messages used when parsing or formatting.";
        string[] header = ["Source: NodaTime.Text.TextErrorMessages (internal const fields)"];

        var ts = new TypescriptWriter()
            .DocComment(summary + "\n@internal")
            .OpenBlock("export class TextErrorMessages {")
            .WriteLine("private constructor() {}");
        foreach (var message in messages)
            ts.WriteLine($"static readonly {message.Name} = {Ts.Str(message.Value)};");
        ts.CloseBlock("}");
        output.Write(LangTarget.TypeScript.Source("Text/TextErrorMessages"), "text-messages", ts, header);

        var dart = new DartWriter()
            .WriteLine("import 'package:meta/meta.dart';", emptyLineAfter: true)
            .DocComment(summary)
            .WriteLine("@internal")
            .OpenBlock("abstract final class TextErrorMessages {");
        foreach (var message in messages)
            dart.WriteLine($"static const String {message.Name} = {Dart.Str(message.Value)};");
        dart.CloseBlock("}");
        output.Write(LangTarget.Dart.Source("Text/TextErrorMessages"), "text-messages", dart, header);
    }

    internal static string Literal(object value) => value switch
    {
        string s => Ts.Str(s),
        char c => Ts.Str(c.ToString()),
        bool b => Ts.Bool(b),
        double d => Ts.Double(d),
        float f => Ts.Double(f),
        ulong u => Ts.SourceInt(u),
        _ => Ts.SourceInt(Convert.ToInt64(value, CultureInfo.InvariantCulture)),
    };

    private static string DartLiteral(object value) => value switch
    {
        string s => Dart.Str(s),
        char c => Dart.Str(c.ToString()),
        bool b => Dart.Bool(b),
        double d => Dart.Double(d),
        float f => Dart.Double(f),
        ulong u => Dart.Int(u),
        _ => Dart.Int(Convert.ToInt64(value, CultureInfo.InvariantCulture)),
    };
}
