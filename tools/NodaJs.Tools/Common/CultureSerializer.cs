using System.Globalization;
using System.Resources;

namespace NodaJs.Tools.Common;

/// <summary>What NodaTime reads of a <see cref="CultureInfo"/>, as <c>CultureData</c>, with .NET's member names.</summary>
public static class CultureSerializer
{
    private static readonly ResourceManager PatternResources =
        new("NodaTime.Globalization.PatternResources", typeof(NodaTime.Instant).Assembly);

    public static IReadOnlyList<string> PatternResourceNames { get; } =
        PatternResources.GetResourceSet(CultureInfo.InvariantCulture, createIfNotExists: true, tryParents: false)!
            .Cast<System.Collections.DictionaryEntry>()
            .Where(e => e.Value is string)
            .Select(e => (string) e.Key)
            .Order(StringComparer.Ordinal)
            .ToList();

    public static string NeutralPatternResource(string name) =>
        PatternResources.GetString(name, CultureInfo.InvariantCulture)!;

    /// <summary>Writes the culture mid-line, with only the pattern resources that differ from the neutral ones.</summary>
    public static void Write(CodeWriter writer, CultureInfo culture)
    {
        var dtf = culture.DateTimeFormat;
        string Strings(IEnumerable<string> values) => writer.List(values.Select(writer.Str));
        string Str(string value) => writer.Str(value);
        string Int(int value) => value.ToString(CultureInfo.InvariantCulture);
        var eras = Enumerable.Range(1, dtf.Calendar.Eras.Length).ToList();

        writer.OpenObject("CultureData")
            .Property(nameof(culture.Name), Str(culture.Name))
            .OpenObjectLine("DateTimeFormatData", nameof(culture.DateTimeFormat))
            .Property(nameof(dtf.Calendar), Str(dtf.Calendar.GetType().Name))
            .Property(nameof(dtf.AMDesignator), Str(dtf.AMDesignator))
            .Property(nameof(dtf.PMDesignator), Str(dtf.PMDesignator))
            .Property(nameof(dtf.TimeSeparator), Str(dtf.TimeSeparator))
            .Property(nameof(dtf.DateSeparator), Str(dtf.DateSeparator))
            .Property(nameof(dtf.ShortDatePattern), Str(dtf.ShortDatePattern))
            .Property(nameof(dtf.LongDatePattern), Str(dtf.LongDatePattern))
            .Property(nameof(dtf.ShortTimePattern), Str(dtf.ShortTimePattern))
            .Property(nameof(dtf.LongTimePattern), Str(dtf.LongTimePattern))
            .Property(nameof(dtf.FullDateTimePattern), Str(dtf.FullDateTimePattern))
            .Property(nameof(dtf.MonthDayPattern), Str(dtf.MonthDayPattern))
            .Property(nameof(dtf.YearMonthPattern), Str(dtf.YearMonthPattern))
            .Property(nameof(dtf.SortableDateTimePattern), Str(dtf.SortableDateTimePattern))
            .Property(nameof(dtf.UniversalSortableDateTimePattern), Str(dtf.UniversalSortableDateTimePattern))
            .Property(nameof(dtf.RFC1123Pattern), Str(dtf.RFC1123Pattern))
            .Property(nameof(dtf.MonthNames), Strings(dtf.MonthNames))
            .Property(nameof(dtf.AbbreviatedMonthNames), Strings(dtf.AbbreviatedMonthNames))
            .Property(nameof(dtf.MonthGenitiveNames), Strings(dtf.MonthGenitiveNames))
            .Property(nameof(dtf.AbbreviatedMonthGenitiveNames), Strings(dtf.AbbreviatedMonthGenitiveNames))
            .Property(nameof(dtf.DayNames), Strings(dtf.DayNames))
            .Property(nameof(dtf.AbbreviatedDayNames), Strings(dtf.AbbreviatedDayNames))
            .Property(nameof(dtf.ShortestDayNames), Strings(dtf.ShortestDayNames))
            // No DateTimeFormatInfo property for these.
            .Property("EraNames", Strings(eras.Select(dtf.GetEraName)))
            .Property("AbbreviatedEraNames", Strings(eras.Select(dtf.GetAbbreviatedEraName)))
            .Property(nameof(dtf.FirstDayOfWeek), Int((int) dtf.FirstDayOfWeek))
            .Property(nameof(dtf.CalendarWeekRule), Int((int) dtf.CalendarWeekRule))
            .CloseObjectLine();

        var resources = PatternResourceNames
            .Select(name => new { Name = name, Value = PatternResources.GetString(name, culture) })
            .Where(r => r.Value is not null && r.Value != NeutralPatternResource(r.Name))
            .ToList();
        if (resources.Count > 0)
        {
            writer.OpenBlock("PatternResources: {");
            foreach (var r in resources)
                writer.Property(Str(r.Name), Str(r.Value!));
            writer.CloseBlock("},");
        }
        writer.CloseObject();
    }

    public static string Serialize(CultureInfo culture)
    {
        var writer = new TypescriptWriter();
        Write(writer, culture);
        return writer.ToString();
    }
}
