using System.Globalization;
using NodaJs.Tools.Common;
using NodaTime;
using NodaTime.Text;
using NodaTime.TimeZones;

namespace NodaJs.Tools.Data;

/// <summary>
/// Golden vectors produced by running NodaTime itself:
/// <list type="bullet">
/// <item>formatting: sample values formatted with every standard pattern and some custom patterns, per culture
/// (test/golden/formatting/&lt;culture&gt;.generated.ts);</item>
/// <item>compare: the culture-aware case-insensitive comparisons NodaTime's parsers make on culture text
/// (test/golden/compare/&lt;culture&gt;.generated.ts).</item>
/// </list>
/// </summary>
internal static class GoldenExports
{
    private static readonly TsValueEncoder Encoder = new();

    private const string StandardChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

    private static readonly LocalDate[] Dates = [
        new(2024, 3, 1), 
        new(1, 1, 1),
        new(9999, 12, 31), 
        new(1976, 6, 19), 
        new(-50, 11, 2), 
        new(2011, 10, 9)
    ];
    private static readonly LocalTime[] Times = [
        LocalTime.Midnight, 
        new(13, 45, 30),
        LocalTime.FromHourMinuteSecondNanosecond(9, 5, 7, 123456789), 
        new(23, 59, 59, 999), 
        new(12, 0)
    ];
    private static readonly Offset[] Offsets = [
        Offset.Zero, 
        Offset.FromHours(10), 
        Offset.FromHoursAndMinutes(-5, -30), 
        Offset.FromSeconds(3723),
        Offset.FromSeconds(-61)
    ];
    private static readonly Duration[] Durations = [
        Duration.Zero,
        Duration.FromHours(36),
        Duration.FromNanoseconds(-1), 
        Duration.FromSeconds(1234567) + Duration.FromNanoseconds(987654321), 
        Duration.FromDays(-400)
    ];

    private static readonly string[] CustomDatePatterns =
        ["uuuu-MM-dd", "dddd, d MMMM yyyy", "ddd d MMM yy", "MMMM", "MMM", "d/M/yyyy g", "yyyy gg", "dd'.'MM'.'uuuu", "dddd"];
    
    private static readonly string[] CustomTimePatterns = 
        ["HH:mm:ss.fff", "h:mm tt", "hh:mm:ss t", "H:m:s", "HH:mm:ss.FFFFFFFFF", "tt", "HH':'mm"];
    
    private static readonly string[] CustomDateTimePatterns = 
        ["uuuu-MM-dd'T'HH:mm:ss", "dddd, MMMM d, yyyy h:mm tt", "d MMM yyyy HH:mm", "G' 'yyyy ddd"];
    
    private static readonly string[] CustomOffsetPatterns = 
        ["+HH:mm", "-HH", "+HH:mm:ss", "+H", "z"];
    
    private static readonly string[] CustomDurationPatterns = 
        ["-D:hh:mm:ss.fff", "-H:mm", "M:ss", "-S.FFFFFFFFF", "D'd 'h'h'"];

    public static void Run(GeneratedFiles output)
    {
        var cultures = new List<CultureInfo> { CultureInfo.InvariantCulture };
        cultures.AddRange(CultureExports.ListedCultures().Select(CultureInfo.GetCultureInfo));
        foreach (var culture in cultures)
        {
            var fileName = culture.Name == "" ? "invariant" : culture.Name;
            WriteFormatting(output, culture, fileName);
            WriteCompare(output, culture, fileName);
        }
        JsonGoldenExports.Run(output);
        CalendarGoldenExports.Run(output);
        output.DeleteStale("test/golden");
    }

    private static void WriteFormatting(GeneratedFiles output, CultureInfo culture, string fileName)
    {
        var body = new TypescriptWriter()
            .WriteLine("import type { FormattingGolden } from \"../types.ts\";", emptyLineAfter: true)
            .OpenBlock("export const golden: FormattingGolden = {")
            .Property("culture", Ts.Str(culture.Name))
            .OpenBlock("cases: [");

        Cases("LocalDate", 
            p => LocalDatePattern.Create(p, culture), 
            Dates, 
            CustomDatePatterns);
        
        Cases("LocalTime", 
            p => LocalTimePattern.Create(p, culture), 
            Times, 
            CustomTimePatterns);
        
        Cases("LocalDateTime", 
            p => LocalDateTimePattern.Create(p, culture),
            Dates.Take(4).SelectMany(d => Times.Take(3).Select(d.At)), 
            CustomDateTimePatterns);
        
        Cases("Offset", 
            p => OffsetPattern.Create(p, culture), 
            Offsets, 
            CustomOffsetPatterns);
        
        Cases("Duration", 
            p => DurationPattern.Create(p, culture), 
            Durations, 
            CustomDurationPatterns);
        
        Cases("Instant", 
            p => InstantPattern.Create(p, culture),
            [Instant.FromUtc(2024, 3, 1, 12, 34, 56), NodaConstants.UnixEpoch, Instant.FromUnixTimeTicks(-1)], 
            ["uuuu-MM-dd'T'HH:mm:ss'Z'"]);
        
        Cases("YearMonth", 
            p => YearMonthPattern.Create(p, culture), 
            Dates.Take(4).Select(d => d.ToYearMonth()), 
            ["MMMM yyyy", "uuuu-MM"]);
        
        Cases("AnnualDate", 
            p => AnnualDatePattern.Create(p, culture), 
            [new AnnualDate(2, 29), new AnnualDate(12, 31)], 
            ["MMMM d", "dd MMM"]);
        
        Cases("OffsetDateTime", 
            p => OffsetDateTimePattern.Create(p, culture, default),
            Dates.Take(3).SelectMany(d => Offsets.Take(3).Select(o => d.At(Times[2]).WithOffset(o))), 
            ["uuuu-MM-dd'T'HH:mm:sso<g>", "dddd HH:mm o<+HH:mm>"]);
        
        Cases("OffsetDate",
            p => OffsetDatePattern.Create(p, culture, default),
            Dates.Take(3).SelectMany(d => Offsets.Take(3).Select(d.WithOffset)),
            ["d MMMM uuuu o<g>"]);
        
        Cases("OffsetTime", 
            p => OffsetTimePattern.Create(p, culture, default),
            Times.Take(3).SelectMany(t => Offsets.Take(3).Select(t.WithOffset)), 
            ["h:mm tt o<g>"]);
        
        var zone = DateTimeZoneProviders.Tzdb["Europe/London"];
        Cases("ZonedDateTime",
            p => ZonedDateTimePattern.Create(p, culture, Resolvers.StrictResolver, DateTimeZoneProviders.Tzdb, default(ZonedDateTime)),
            [new LocalDateTime(2024, 3, 1, 12, 0).InZoneLeniently(zone), new LocalDateTime(2024, 7, 1, 1, 30).InZoneLeniently(zone)],
            ["uuuu-MM-dd'T'HH:mm:ss z '('o<g>')'", "dddd HH:mm x"]);

        body.CloseBlock("],")
            .CloseBlock("};");
        output.Write($"test/golden/formatting/{fileName}.generated.ts", "golden", body,
            ["Each case: NodaTime's output formatting `value` with `pattern` in this culture, and whether parsing it gives the value back."]);

        return;
        
        void Cases<T>(string type, Func<string, IPattern<T>> create, IEnumerable<T> values, IEnumerable<string> custom)
        {
            var patterns = StandardChars.Select(c => c.ToString()).Concat(custom);
            foreach (var patternText in patterns)
            {
                IPattern<T> pattern;
                try
                {
                    pattern = create(patternText);
                }
                catch (InvalidPatternException)
                {
                    continue; // not a valid standard pattern for this type
                }
                foreach (var value in values)
                {
                    string text;
                    try
                    {
                        text = pattern.Format(value);
                    }
                    catch (Exception e)
                    {
                        body.WriteLine("{ " +
                                       $"type: {Ts.Str(type)}, " +
                                       $"pattern: {Ts.Str(patternText)}, " +
                                       $"value: {Encoder.Encode(value)}, " +
                                       $"error: {Ts.Str(e.GetType().Name)} " +
                                       "},");
                        continue;
                    }
                    var parsed = pattern.Parse(text);
                    var roundTrip = parsed.Success ? (Equals(parsed.Value, value) ? "true" : "false") : "false";
                    body.WriteLine("{ " +
                                   $"type: {Ts.Str(type)}, " +
                                   $"pattern: {Ts.Str(patternText)}, " +
                                   $"value: {Encoder.Encode(value)}, " +
                                   $"text: {Ts.Str(text)}, " +
                                   $"roundTrips: {roundTrip} " +
                                   "},");
                }
            }
        }
    }

    private static void WriteCompare(GeneratedFiles output, CultureInfo culture, string fileName)
    {
        var dtf = culture.DateTimeFormat;
        var lists = new Dictionary<string, string[]>
        {
            ["monthNames"] = dtf.MonthNames,
            ["abbreviatedMonthNames"] = dtf.AbbreviatedMonthNames,
            ["monthGenitiveNames"] = dtf.MonthGenitiveNames,
            ["abbreviatedMonthGenitiveNames"] = dtf.AbbreviatedMonthGenitiveNames,
            ["dayNames"] = dtf.DayNames,
            ["abbreviatedDayNames"] = dtf.AbbreviatedDayNames,
            ["designators"] = [dtf.AMDesignator, dtf.PMDesignator],
        };
        var seen = new HashSet<(string, string)>();
        var body = new TypescriptWriter()
            .WriteLine("import type { CompareGolden } from \"../types.ts\";", emptyLineAfter: true)
            .OpenBlock("export const golden: CompareGolden = {")
            .Property("culture", Ts.Str(culture.Name))
            .Comment("""
                [text, candidate, equal]: CompareInfo.Compare(text, candidate, CompareOptions.IgnoreCase) == 0,
                as ValueCursor.MatchCaseInsensitive does with text of the candidate's length.
                """)
            .OpenBlock("cases: [");
        var compareInfo = culture.CompareInfo;
        foreach (var names in lists.Values)
        {
            var candidates = names.Where(n => !string.IsNullOrEmpty(n)).Distinct().ToList();
            var texts = candidates.SelectMany(n => new[] { n, n.ToUpper(culture), n.ToLower(culture), n.ToUpperInvariant() }).Distinct().ToList();
            foreach (var candidate in candidates)
            {
                foreach (var text in texts)
                {
                    if (text.Length < candidate.Length)
                        continue;
                    var sub = text[..candidate.Length];
                    if (sub == candidate || !seen.Add((sub, candidate)))
                        continue;
                    var equal = compareInfo.Compare(sub, candidate, CompareOptions.IgnoreCase) == 0;
                    body.WriteLine($"[{Ts.Str(sub)}, {Ts.Str(candidate)}, {Ts.Bool(equal)}],");
                }
            }
        }
        body.CloseBlock("],")
            .CloseBlock("};");
        output.Write($"test/golden/compare/{fileName}.generated.ts", "golden", body);
    }
}
