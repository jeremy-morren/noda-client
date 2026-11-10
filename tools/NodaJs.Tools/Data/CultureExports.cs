using System.Globalization;
using NodaJs.Tools.Common;

namespace NodaJs.Tools.Data;

/// <summary>A module per culture in tools/cultures.txt, the invariant culture, and NodaTime's PatternResources.</summary>
internal static class CultureExports
{
    private static readonly string[] DataSourceNote =
    [
        "Source: ICU/CLDR via .NET (Unicode License; see NOTICE.txt).",
    ];

    public static IReadOnlyList<string> ListedCultures() =>
        File.ReadAllLines(Path.Combine(ToolEnvironment.RepoRoot, "tools", "cultures.txt"))
            .Select(l => l.Split('#')[0].Trim())
            .Where(l => l.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .ToList();

    public static void Run(GeneratedFiles output)
    {
        var cultures = ListedCultures().Select(name =>
        {
            var culture = CultureInfo.GetCultureInfo(name);
            if (culture.Name != name)
                throw new InvalidOperationException($"Culture '{name}' resolved to '{culture.Name}'; fix tools/cultures.txt.");
            return new ListedCulture(culture, Ts.CultureIdentifier(name));
        }).ToList();

        WriteTypeScript(output, cultures);
        WriteDart(output, cultures);
    }

    /// <summary>A culture of tools/cultures.txt, and its exported identifier.</summary>
    private sealed record ListedCulture(CultureInfo Culture, string Identifier);

    private const string PatternResourcesDoc = "NodaTime's neutral pattern resources (offset patterns and era names).";

    private static void WriteTypeScript(GeneratedFiles output, IReadOnlyList<ListedCulture> cultures)
    {
        var port = LangTarget.TypeScript;
        var invariant = new TypescriptWriter()
            .WriteLine("import type { CultureData } from \"./NodaCultureInfo.ts\";", emptyLineAfter: true)
            .DocComment("Data for NodaCultureInfo.InvariantCulture. @internal")
            .AppendIndent()
            .AppendOnLine("export const invariantCultureData: CultureData = ");
        CultureSerializer.Write(invariant, CultureInfo.InvariantCulture);
        invariant.AppendOnLine(";").AppendNewline();
        output.Write(port.Source("Globalization/InvariantCultureData"), "cultures", invariant, DataSourceNote);

        var resources = new TypescriptWriter()
            .DocComment(PatternResourcesDoc + "\n@internal")
            .OpenBlock("export const PatternResources: Readonly<Record<string, string>> = {");
        foreach (var name in CultureSerializer.PatternResourceNames)
            resources.Property(name, Ts.Str(CultureSerializer.NeutralPatternResource(name)));
        resources.CloseBlock("};");
        output.Write(port.Source("Globalization/PatternResources"), "cultures", resources,
            ["Source: NodaTime/Globalization/PatternResources.resx"]);

        var barrel = new TypescriptWriter()
            .Comment("Every culture; bundlers keep only those imported (each is /*#__PURE__*/).")
            .WriteLine();

        foreach (var listed in cultures)
        {
            var culture = listed.Culture;
            var identifier = listed.Identifier;
            barrel.WriteLine($"export {{ {identifier} }} from \"./{culture.Name}.generated.ts\";");

            var body = new TypescriptWriter()
                .WriteLine("import { NodaCultureInfo } from \"../Globalization/NodaCultureInfo.ts\";", emptyLineAfter: true)
                .DocComment($"The {culture.EnglishName} ({culture.Name}) culture, as .NET sees it.")
                .AppendIndent()
                .AppendOnLine($"export const {identifier}: NodaCultureInfo = /*#__PURE__*/ NodaCultureInfo.FromDataRegistered(");
            CultureSerializer.Write(body, culture);
            body.AppendOnLine(");").AppendNewline()
                .WriteLine()
                .WriteLine($"export default {identifier};");
            output.Write(port.Source($"Cultures/{culture.Name}"), "cultures", body, DataSourceNote);
        }
        output.Write(port.Source("Cultures/index"), "cultures", barrel, DataSourceNote);

        // The package's only module with a side effect (package.json "sideEffects").
        var identifiers = cultures.Select(c => c.Identifier).ToList();
        var all = new TypescriptWriter()
            .Comment("Registers every culture for NodaCultureInfo.CurrentCulture.")
            .WriteLine()
            .WriteLine("import { NodaCultureInfo } from \"../Globalization/NodaCultureInfo.ts\";")
            .OpenBlock("import {")
            .WriteLines(identifiers.Select(i => i + ","))
            .CloseBlock("} from \"./index.generated.ts\";", emptyLineAfter: true)
            .OpenBlock("NodaCultureInfo.Register(")
            .WriteLines(identifiers.Select(i => i + ","))
            .CloseBlock(");");
        output.Write(port.Source("Cultures/all"), "cultures", all, DataSourceNote);
        output.DeleteStale(port.SourceRoot + "Cultures", port.GeneratedPattern);
    }

    // Each culture a lazy top-level final; Dart imports have no side effects, so all.generated.dart is a function.
    private static void WriteDart(GeneratedFiles output, IReadOnlyList<ListedCulture> cultures)
    {
        var port = LangTarget.Dart;
        var invariant = new DartWriter()
            .WriteLine("import 'package:meta/meta.dart';", emptyLineAfter: true)
            .WriteLine("import 'NodaCultureInfo.dart';", emptyLineAfter: true)
            .DocComment("Data for NodaCultureInfo.InvariantCulture.")
            .WriteLine("@internal")
            .AppendIndent()
            .AppendOnLine("final CultureData invariantCultureData = ");
        CultureSerializer.Write(invariant, CultureInfo.InvariantCulture);
        invariant.AppendOnLine(";").AppendNewline();
        output.Write(port.Source("Globalization/InvariantCultureData"), "cultures", invariant, DataSourceNote);

        var resources = new DartWriter()
            .WriteLine("import 'package:meta/meta.dart';", emptyLineAfter: true)
            .DocComment(PatternResourcesDoc)
            .WriteLine("@internal")
            .OpenBlock("const Map<String, String> PatternResources = {");
        foreach (var name in CultureSerializer.PatternResourceNames)
            resources.Property(Dart.Str(name), Dart.Str(CultureSerializer.NeutralPatternResource(name)));
        resources.CloseBlock("};");
        output.Write(port.Source("Globalization/PatternResources"), "cultures", resources,
            ["Source: NodaTime/Globalization/PatternResources.resx"]);

        var barrel = new DartWriter()
            .Comment("Every culture; compilers keep only those used.")
            .WriteLine();

        foreach (var listed in cultures)
        {
            var culture = listed.Culture;
            var identifier = listed.Identifier;
            barrel.WriteLine($"export {Dart.Str(culture.Name + ".generated.dart")} show {identifier};");

            var body = new DartWriter()
                .WriteLine("import '../Globalization/NodaCultureInfo.dart';", emptyLineAfter: true)
                .DocComment($"The {culture.EnglishName} ({culture.Name}) culture, as .NET sees it.")
                .AppendIndent()
                .AppendOnLine($"final NodaCultureInfo {identifier} = NodaCultureInfo.FromDataRegistered(");
            CultureSerializer.Write(body, culture);
            body.AppendOnLine(");").AppendNewline();
            output.Write(port.Source($"Cultures/{culture.Name}"), "cultures", body, DataSourceNote);
        }
        output.Write(port.Source("Cultures/index"), "cultures", barrel, DataSourceNote);

        var all = new DartWriter()
            .WriteLine("import '../Globalization/NodaCultureInfo.dart';")
            .WriteLine("import 'index.generated.dart';", emptyLineAfter: true)
            .DocComment("Every culture (tools/cultures.txt).")
            .OpenBlock("final List<NodaCultureInfo> AllCultures = [")
            .WriteLines(cultures.Select(c => c.Identifier + ","))
            .CloseBlock("];", emptyLineAfter: true)
            .DocComment("Registers every culture for NodaCultureInfo.CurrentCulture.")
            .WriteLine("void RegisterAllCultures() => NodaCultureInfo.Register(AllCultures);");
        output.Write(port.Source("Cultures/all"), "cultures", all, DataSourceNote);
        output.DeleteStale(port.SourceRoot + "Cultures", port.GeneratedPattern);
    }
}
