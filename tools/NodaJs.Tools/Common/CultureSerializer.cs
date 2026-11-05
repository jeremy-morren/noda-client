using System.Globalization;
using System.Resources;

namespace NodaJs.Tools.Common;

/// <summary>
/// Serializes the parts of a <see cref="CultureInfo"/> that NodaTime reads into a TS object literal
/// matching the <c>CultureData</c> interface in src/noda-js/Globalization/NodaCultureInfo.ts. Member names are the
/// .NET property names, so ported code can read them as it reads the .NET objects.
/// </summary>
public static class CultureSerializer
{
    // NodaTime's own localizable resources (offset patterns and era names).
    private static readonly ResourceManager PatternResources =
        new("NodaTime.Globalization.PatternResources", typeof(NodaTime.Instant).Assembly);

    /// <summary>Names of all string resources in NodaTime's neutral PatternResources.</summary>
    public static IReadOnlyList<string> PatternResourceNames { get; } =
        PatternResources.GetResourceSet(CultureInfo.InvariantCulture, createIfNotExists: true, tryParents: false)!
            .Cast<System.Collections.DictionaryEntry>()
            .Where(e => e.Value is string)
            .Select(e => (string) e.Key)
            .Order(StringComparer.Ordinal)
            .ToList();

    public static string NeutralPatternResource(string name) =>
        PatternResources.GetString(name, CultureInfo.InvariantCulture)!;

    /// <summary>
    /// Writes the culture as a TS object literal, starting on the writer's current line: <c>{</c>, the properties
    /// indented one level, and <c>}</c>, leaving the caller to finish the line. Pattern resources are only included
    /// where the culture has a value different from the neutral resources.
    /// </summary>
    public static void Write(TypescriptWriter writer, CultureInfo culture)
    {
        var dtf = culture.DateTimeFormat;
        string Strings(IEnumerable<string> values) => "[" + string.Join(", ", values.Select(Ts.Str)) + "]";
        string Int(int value) => value.ToString(CultureInfo.InvariantCulture);
        // GetEraName(1) / GetAbbreviatedEraName(1) are what NodaFormatInfo reads, for Gregorian calendars.
        var eras = Enumerable.Range(1, dtf.Calendar.Eras.Length).ToList();

        writer.OpenInline("{")
            .Property(nameof(culture.Name), Ts.Str(culture.Name))
            // DateTimeFormatInfo members keep their C# names, as in noda-js.
            .OpenBlock($"{nameof(culture.DateTimeFormat)}: {{")
            .Property(nameof(dtf.Calendar), Ts.Str(dtf.Calendar.GetType().Name))
            .Property(nameof(dtf.AMDesignator), Ts.Str(dtf.AMDesignator))
            .Property(nameof(dtf.PMDesignator), Ts.Str(dtf.PMDesignator))
            .Property(nameof(dtf.TimeSeparator), Ts.Str(dtf.TimeSeparator))
            .Property(nameof(dtf.DateSeparator), Ts.Str(dtf.DateSeparator))
            .Property(nameof(dtf.ShortDatePattern), Ts.Str(dtf.ShortDatePattern))
            .Property(nameof(dtf.LongDatePattern), Ts.Str(dtf.LongDatePattern))
            .Property(nameof(dtf.ShortTimePattern), Ts.Str(dtf.ShortTimePattern))
            .Property(nameof(dtf.LongTimePattern), Ts.Str(dtf.LongTimePattern))
            .Property(nameof(dtf.FullDateTimePattern), Ts.Str(dtf.FullDateTimePattern))
            .Property(nameof(dtf.MonthDayPattern), Ts.Str(dtf.MonthDayPattern))
            .Property(nameof(dtf.YearMonthPattern), Ts.Str(dtf.YearMonthPattern))
            .Property(nameof(dtf.SortableDateTimePattern), Ts.Str(dtf.SortableDateTimePattern))
            .Property(nameof(dtf.UniversalSortableDateTimePattern), Ts.Str(dtf.UniversalSortableDateTimePattern))
            .Property(nameof(dtf.RFC1123Pattern), Ts.Str(dtf.RFC1123Pattern))
            .Property(nameof(dtf.MonthNames), Strings(dtf.MonthNames))
            .Property(nameof(dtf.AbbreviatedMonthNames), Strings(dtf.AbbreviatedMonthNames))
            .Property(nameof(dtf.MonthGenitiveNames), Strings(dtf.MonthGenitiveNames))
            .Property(nameof(dtf.AbbreviatedMonthGenitiveNames), Strings(dtf.AbbreviatedMonthGenitiveNames))
            .Property(nameof(dtf.DayNames), Strings(dtf.DayNames))
            .Property(nameof(dtf.AbbreviatedDayNames), Strings(dtf.AbbreviatedDayNames))
            .Property(nameof(dtf.ShortestDayNames), Strings(dtf.ShortestDayNames))
            // No DateTimeFormatInfo property: GetEraName(n) / GetAbbreviatedEraName(n) for each era.
            .Property("EraNames", Strings(eras.Select(dtf.GetEraName)))
            .Property("AbbreviatedEraNames", Strings(eras.Select(dtf.GetAbbreviatedEraName)))
            .Property(nameof(dtf.FirstDayOfWeek), Int((int) dtf.FirstDayOfWeek))
            .Property(nameof(dtf.CalendarWeekRule), Int((int) dtf.CalendarWeekRule))
            .CloseBlock("},");

        var resources = PatternResourceNames
            .Select(name => (Name: name, Value: PatternResources.GetString(name, culture)))
            .Where(r => r.Value is not null && r.Value != NeutralPatternResource(r.Name))
            .ToList();
        if (resources.Count > 0)
        {
            writer.OpenBlock("PatternResources: {");
            foreach (var (name, value) in resources)
                writer.Property(Ts.Str(name), Ts.Str(value));
            writer.CloseBlock("},");
        }
        writer.CloseInline("}");
    }

    /// <summary>The culture as a TS object literal on its own (see <see cref="Write"/>).</summary>
    public static string Serialize(CultureInfo culture)
    {
        var writer = new TypescriptWriter();
        Write(writer, culture);
        return writer.ToString();
    }
}
