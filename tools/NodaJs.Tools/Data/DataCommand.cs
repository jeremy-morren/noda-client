using NodaJs.Tools.Common;

namespace NodaJs.Tools.Data;

internal static class DataCommand
{
    /// <summary>In run order.</summary>
    public static readonly string[] Parts = ["enums", "constants", "calendars", "text-messages", "cultures", "tzdb", "api", "golden"];

    public static void Run(GeneratedFiles output, IReadOnlyCollection<string> parts, string tzdbSource, string? tzdataSource, string? cldrSource)
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
                case "tzdb": TzdbExport.Run(output, tzdbSource, tzdataSource, cldrSource); break;
                case "api": ApiExport.Run(output); break;
                case "golden": GoldenExports.Run(output); break;
            }
        }
    }
}
