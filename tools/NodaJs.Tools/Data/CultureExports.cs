using System.Globalization;
using NodaJs.Tools.Common;

namespace NodaJs.Tools.Data;

/// <summary>
/// Culture data: one module per culture listed in tools/cultures.txt, plus the invariant culture
/// (in core) and NodaTime's neutral PatternResources.
/// </summary>
internal static class CultureExports
{
    private static readonly string[] DataSourceNote =
    [
        "Culture data comes from ICU/CLDR via .NET's globalization layer (Unicode License; see NOTICE.txt).",
    ];

    public static IReadOnlyList<string> ListedCultures() =>
        File.ReadAllLines(Path.Combine(ToolEnvironment.RepoRoot, "tools", "cultures.txt"))
            .Select(l => l.Split('#')[0].Trim())
            .Where(l => l.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .ToList();

    public static void Run(GeneratedFiles output)
    {
        var invariant = new TypescriptWriter()
            .WriteLine("import type { CultureData } from \"./NodaCultureInfo.ts\";", emptyLineAfter: true)
            .DocComment("Data for NodaCultureInfo.InvariantCulture. @internal")
            .AppendIndent()
            .AppendOnLine("export const invariantCultureData: CultureData = ");
        CultureSerializer.Write(invariant, CultureInfo.InvariantCulture);
        invariant.AppendOnLine(";").AppendNewline();
        output.Write("src/noda-js/Globalization/InvariantCultureData.generated.ts", "cultures", invariant, DataSourceNote);

        var resources = new TypescriptWriter()
            .DocComment("""
                NodaTime's neutral (culture-independent) pattern resources: offset patterns and era names.
                Culture-specific values, if NodaTime ever has any, are in each culture's `PatternResources`.
                @internal
                """)
            .OpenBlock("export const PatternResources: Readonly<Record<string, string>> = {");
        foreach (var name in CultureSerializer.PatternResourceNames)
            resources.Property(name, Ts.Str(CultureSerializer.NeutralPatternResource(name)));
        resources.CloseBlock("};");
        output.Write("src/noda-js/Globalization/PatternResources.generated.ts", "cultures", resources,
            ["Source: NodaTime/Globalization/PatternResources.resx"]);

        // noda-js/cultures: every culture as a named export. With "sideEffects": false and the /*#__PURE__*/
        // constructions below, bundlers keep only the cultures an app imports.
        var barrel = new TypescriptWriter()
            .Comment("""
                Every culture as a named export: `import { enAU } from "noda-js/cultures"`. Bundlers keep only the cultures
                you import (the package has "sideEffects": false and each culture is a pure construction).
                The invariant culture is always available, as NodaCultureInfo.InvariantCulture in the core.
                """)
            .WriteLine();

        foreach (var name in ListedCultures())
        {
            var culture = CultureInfo.GetCultureInfo(name);
            if (culture.Name != name)
                throw new InvalidOperationException($"Culture '{name}' resolved to '{culture.Name}'; fix tools/cultures.txt.");
            var identifier = Ts.CultureIdentifier(name);
            barrel.WriteLine($"export {{ {identifier} }} from \"./{name}.generated.ts\";");

            var body = new TypescriptWriter()
                .WriteLine("import { NodaCultureInfo } from \"../Globalization/NodaCultureInfo.ts\";", emptyLineAfter: true)
                .DocComment($"The {culture.EnglishName} ({name}) culture, as .NET sees it.")
                .AppendIndent()
                .AppendOnLine($"export const {identifier}: NodaCultureInfo = /*#__PURE__*/ NodaCultureInfo.FromData(");
            CultureSerializer.Write(body, culture);
            body.AppendOnLine(");").AppendNewline()
                .WriteLine()
                .WriteLine($"export default {identifier};");
            output.Write($"src/noda-js/Cultures/{name}.generated.ts", "cultures", body, DataSourceNote);
        }
        output.Write("src/noda-js/Cultures/index.generated.ts", "cultures", barrel, DataSourceNote);
        output.DeleteStale("src/noda-js/Cultures");
    }
}
