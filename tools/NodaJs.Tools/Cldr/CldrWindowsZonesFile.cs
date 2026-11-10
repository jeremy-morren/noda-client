using System.Xml;
using System.Xml.Linq;
using NodaJs.Tools.Common;

namespace NodaJs.Tools.Cldr;

/// <summary>
/// CLDR's windowsZones.xml: a given file, or the one NodaTime's TzdbCompiler picks from its data/cldr.
/// </summary>
internal static class CldrWindowsZonesFile
{
    /// <summary>A loaded windowsZones.xml, and where it came from (for generated files' headers).</summary>
    public sealed record CldrFile(XDocument Document, string Origin);

    private sealed record ParsedFile(string File, XDocument Document);

    /// <summary>
    /// Load a windowsZones.xml file, or the one NodaTime's TzdbCompiler picks from its data/cldr.
    /// </summary>
    public static CldrFile Load(string? file)
    {
        if (file is not null)
            return new CldrFile(Parse(file), Path.GetFullPath(file));
        // As TzdbCompiler picks from a directory: the newest TZDB version, then the later file name.
        var picked = Directory.GetFiles(Path.Combine(ToolEnvironment.NodaTimeRoot, "data", "cldr"), "*.xml")
            .OrderByDescending(f => f)
            .Select(f => new ParsedFile(f, Parse(f)))
            .OrderByDescending(p =>
                NodaTimeInternals.ParseCldrWindowsZones(null, p.Document, Path.GetFileName(p.File)).TzdbVersion)
            .First();
        var latest = picked.File;
        var document = picked.Document;
        // Recent CLDR files have an empty "$Revision$":
        // use the release from the file name (windowsZones-48-2.xml → 48.2), as nodatime.org's NZD files do.
        var number = document.Root?.Element("version")?.Attribute("number");
        if (number is { Value: "$Revision$" })
            number.Value = $"$Revision: {Path.GetFileNameWithoutExtension(latest)["windowsZones-".Length..].Replace('-', '.')} $";
        return new CldrFile(document, $"NodaTime's data/cldr/{Path.GetFileName(latest)}");
    }

    // No DTD processing: CLDR files name a DTD by a relative path.
    private static XDocument Parse(string file)
    {
        using var reader = XmlReader.Create(file, new XmlReaderSettings { DtdProcessing = DtdProcessing.Ignore });
        return XDocument.Load(reader);
    }
}
