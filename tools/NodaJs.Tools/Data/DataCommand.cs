using NodaJs.Tools.Common;

namespace NodaJs.Tools.Data;

/// <summary>
/// The <c>data</c> command: everything noda-js can take from .NET and NodaTime by reflection, as TypeScript files.
/// </summary>
internal static class DataCommand
{
    /// <summary>The parts of the data export, in the order <c>data</c> (with no parts) runs them.</summary>
    public static readonly string[] Parts = ["enums", "constants", "calendars", "text-messages", "cultures", "tzdb", "api", "golden"];

    public static async Task Run(GeneratedFiles output, IReadOnlyCollection<string> parts, string tzdbSource, string? tzdataSource, string? cldrSource)
    {
        foreach (var part in Parts.Where(p => parts.Count == 0 || parts.Contains(p)))
        {
            Console.WriteLine($"[{part}]");
            switch (part)
            {
                case "enums": ReflectionExports.Enums(output); break;
                case "constants": ReflectionExports.Constants(output); break;
                case "calendars": CalendarDataExports.Run(output); break;
                case "text-messages": ReflectionExports.TextErrorMessages(output); break;
                case "cultures": CultureExports.Run(output); break;
                case "tzdb": await TzdbExport.Run(output, tzdbSource, tzdataSource, cldrSource); break;
                case "api": ApiExport.Run(output); break;
                case "golden": GoldenExports.Run(output); break;
            }
        }
    }
}
