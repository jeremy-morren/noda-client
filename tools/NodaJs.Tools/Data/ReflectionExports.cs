using System.Globalization;
using System.Reflection;
using NodaJs.Tools.Common;
using NodaTime;

namespace NodaJs.Tools.Data;

/// <summary>
/// Code that can be generated straight from NodaTime's metadata: enums, constants and error messages.
/// </summary>
internal static class ReflectionExports
{
    internal static readonly Assembly NodaTimeAssembly = typeof(Instant).Assembly;
    private static readonly DocComments Docs = new(NodaTimeAssembly);

    // Namespaces whose code isn't ported (docs/api-differences.md).
    private static readonly string[] ExcludedNamespaces = ["NodaTime.Annotations", "NodaTime.HighPerformance", "NodaTime.Xml"];

    /// <summary>Where the TS file for a NodaTime type lives: "NodaTime.Text.Patterns.X" → "src/noda-js/Text/Patterns/X".</summary>
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
        return "src/noda-js/" + folder + string.Join(".", names);
    }

    // Enums of calendars that aren't ported (docs/api-differences.md); nothing in noda-js uses them.
    private static readonly string[] UnportedEnums =
        ["NodaTime.Calendars.HebrewMonthNumbering", "NodaTime.Calendars.IslamicEpoch", "NodaTime.Calendars.IslamicLeapYearPattern"];

    /// <summary>The TS name of a (possibly nested) type: "ZoneEqualityComparer+Options" → "ZoneEqualityComparerOptions".</summary>
    internal static string TsTypeName(Type type) => DocComments.TsTypeName(type);

    /// <summary>Whether noda-js has a TS file for the type (hand-written or generated).</summary>
    private static bool IsPorted(Type type)
    {
        var path = Path.Combine(ToolEnvironment.RepoRoot, SourcePath(type));
        return File.Exists(path + ".ts") || File.Exists(path + ".generated.ts");
    }

    public static void Enums(GeneratedFiles output)
    {
        var enums = NodaTimeAssembly.GetTypes()
            .Where(t => t.IsEnum && !ExcludedNamespaces.Contains(t.Namespace) && !UnportedEnums.Contains(t.FullName))
            .Where(t => !t.IsDefined(typeof(System.Runtime.CompilerServices.CompilerGeneratedAttribute)))
            .OrderBy(t => t.FullName, StringComparer.Ordinal);
        foreach (var type in enums)
        {
            var summary = Docs.Summary(type);
            var doc = summary?.Text ?? "";
            if (!(type.IsPublic || type.IsNestedPublic))
                doc += (doc.Length > 0 ? "\n" : "") + "@internal";
            if (type.IsDefined(typeof(FlagsAttribute)))
                doc += (doc.Length > 0 ? "\n" : "") + "This is a flags enum: combine values with `|`.";
            var fields = type.GetFields(BindingFlags.Public | BindingFlags.Static)
                .OrderBy(f => f.MetadataToken)
                .Select(f => (Field: f, Doc: Docs.Summary(f)))
                .ToList();

            var writer = new TypescriptWriter();
            // Types the docs link to, imported (type-only) so the links resolve.
            var linked = fields.Select(f => f.Doc).Append(summary)
                .SelectMany(d => d?.LinkedTypes ?? new HashSet<Type>())
                .Where(t => t != type && IsPorted(t))
                .Select(TsTypeName)
                .Distinct()
                .Order(StringComparer.Ordinal)
                .ToList();
            if (linked.Count > 0)
            {
                var depth = SourcePath(type).Count(c => c == '/') - "src/noda-js/".Count(c => c == '/');
                var internalModule = depth == 0 ? "./internal.ts" : string.Concat(Enumerable.Repeat("../", depth)) + "internal.ts";
                writer.WriteLine($"import type {{ {string.Join(", ", linked)} }} from \"{internalModule}\";", emptyLineAfter: true);
            }

            writer.DocComment(doc)
                .OpenBlock($"export enum {TsTypeName(type)} {{");
            foreach (var (field, fieldDoc) in fields)
            {
                var value = Convert.ToInt64(field.GetRawConstantValue(), CultureInfo.InvariantCulture);
                writer.DocComment(fieldDoc?.Text)
                    .WriteLine($"{field.Name} = {Ts.SourceInt(value)},");
            }
            writer.CloseBlock("}");
            output.Write(SourcePath(type) + ".generated.ts", "enums", writer,
                [$"Source: {type.FullName} (enum)"]);
        }
    }

    public static void Constants(GeneratedFiles output)
    {
        // NodaConstants: a leaf module of named exports (C# names), used by internal code, plus the values
        // the hand-ported NodaConstants class exposes in camelCase.
        var writer = new TypescriptWriter();
        foreach (var field in typeof(NodaConstants).GetFields(BindingFlags.Public | BindingFlags.Static)
                     .Where(f => f.IsLiteral).OrderBy(f => f.MetadataToken))
            writer.DocComment(Docs.Summary(field)?.Text)
                .WriteLine($"export const {field.Name} = {Literal(field.GetRawConstantValue()!)};");
        output.Write("src/noda-js/NodaConstants.generated.ts", "constants", writer,
            ["Source: NodaTime.NodaConstants (const fields)"]);
    }

    public static void TextErrorMessages(GeneratedFiles output)
    {
        var type = NodaTimeAssembly.GetType("NodaTime.Text.TextErrorMessages", throwOnError: true)!;
        var writer = new TypescriptWriter()
            .DocComment("Common error messages used when parsing or formatting.\n@internal")
            .OpenBlock("export class TextErrorMessages {")
            .WriteLine("private constructor() {}");
        foreach (var field in type.GetFields(BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static)
                     .Where(f => f.IsLiteral).OrderBy(f => f.Name, StringComparer.Ordinal))
            writer.WriteLine($"static readonly {field.Name} = {Ts.Str((string) field.GetRawConstantValue()!)};");
        writer.CloseBlock("}");
        output.Write("src/noda-js/Text/TextErrorMessages.generated.ts", "text-messages", writer,
            ["Source: NodaTime.Text.TextErrorMessages (internal const fields)"]);
    }

    internal static string Literal(object value) => value switch
    {
        string s => Ts.Str(s),
        char c => Ts.Str(c.ToString()),
        bool b => Ts.Bool(b),
        double d => Ts.Double(d),
        float f => Ts.Double(f),
        ulong u => Ts.SourceInt(u), // (src/ has no bigint: see Ts.SourceInt.)
        _ => Ts.SourceInt(Convert.ToInt64(value, CultureInfo.InvariantCulture)),
    };
}
