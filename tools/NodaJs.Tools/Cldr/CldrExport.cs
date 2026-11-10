using NodaJs.Tools.Common;

namespace NodaJs.Tools.Cldr;

/// <summary>
/// <c>cldr</c>: CLDR's Windows ↔ tzdb ID mapping, parsed by NodaTime's CldrWindowsZonesParser.
/// </summary>
internal static class CldrExport
{
    public static void Run(GeneratedFiles output, string? source)
    {
        var file = CldrWindowsZonesFile.Load(source);
        var zones = NodaTimeInternals.ParseCldrWindowsZones(null, file.Document, "windowsZones.xml");

        foreach (var port in LangTarget.All)
        {
            var body = port.NewWriter();
            switch (body)
            {
                case TypescriptWriter:
                    body.WriteLine("import type { WindowsZonesData } from \"./CldrWindowsZones.ts\";", emptyLineAfter: true)
                        .DocComment("CLDR's mapping between Windows time zone IDs and IANA (tzdb) IDs.")
                        .AppendIndent()
                        .AppendOnLine("export const cldrWindowsZones: WindowsZonesData = ");
                    break;
                case DartWriter:
                    body.WriteLine("import 'CldrWindowsZones.dart';", emptyLineAfter: true)
                        .DocComment("CLDR's mapping between Windows time zone IDs and IANA (tzdb) IDs.")
                        .AppendIndent()
                        .AppendOnLine("final WindowsZonesData cldrWindowsZones = ");
                    break;
                default:
                    body.ThrowUnknown();
                    break;
            }
            body.OpenObject("WindowsZonesData")
                .Property(nameof(zones.Version), body.Str(zones.Version))
                .Property(nameof(zones.TzdbVersion), body.Str(zones.TzdbVersion))
                .Property(nameof(zones.WindowsVersion), body.Str(zones.WindowsVersion))
                .OpenBlock($"{nameof(zones.MapZones)}: [");
            foreach (var mapZone in zones.MapZones)
                body.WriteLine(body.Object("", new
                {
                    WindowsId = body.Str(mapZone.WindowsId),
                    Territory = body.Str(mapZone.Territory),
                    TzdbIds = body.List(mapZone.TzdbIds.Select(body.Str)),
                }) + ",");
            body.CloseBlock("],")
                .CloseObject()
                .AppendOnLine(";")
                .AppendNewline();
            output.Write(port.Source("Bcl/CldrWindowsZones"),
                "cldr",
                body,
                [$"Source: {file.Origin}", "CLDR data is under the Unicode License (see NOTICE.txt)."]);
        }

    }
}
