using System.Globalization;
using NodaJs.Tools.Common;
using NodaTime;
using NodaTime.Text;
using NodaTime.TimeZones;

namespace NodaJs.Tools.Data;

/// <summary>Per culture: NodaTime formatting sample values, and its parsers' case-insensitive comparisons.</summary>
internal static class GoldenExports
{
    private static readonly ValueEncoder Encoder = new();

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
        foreach (var port in LangTarget.All)
            output.DeleteStale(port.TestRoot + "golden", port.GeneratedPattern);
    }

    private sealed record FormattingCase(string Type, string Pattern, EncodedValue Value, string? Text, bool RoundTrips, string? Error);

    private static void WriteFormatting(GeneratedFiles output, CultureInfo culture, string fileName)
    {
        var cases = new List<FormattingCase>();

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

        foreach (var port in LangTarget.All)
        {
            var body = port.NewWriter();
            body.OpenConstObject("golden", "FormattingGolden", "../types", cases.All(c => c.Value.IsDartConstant))
                .Property("culture", body.Str(culture.Name))
                .OpenBlock("cases: [");
            foreach (var c in cases)
            {
                // An error, or the text and whether it round-trips.
                var parts = new
                {
                    type = body.Str(c.Type),
                    pattern = body.Str(c.Pattern),
                    value = body.Value(c.Value),
                    error = c.Error is null ? null : body.Str(c.Error),
                    text = c.Error is null ? body.Str(c.Text) : null,
                    roundTrips = c.Error is null ? body.Bool(c.RoundTrips) : null,
                };
                body.WriteLine(body.Object("FormattingCase", parts) + ",");
            }
            body.CloseBlock("],")
                .CloseConstObject();
            output.Write(port.Test($"golden/formatting/{fileName}"), "golden", body,
                ["NodaTime formatting `value` with `pattern`, and whether parsing round-trips."]);
        }

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
                    continue;
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
                        cases.Add(new FormattingCase(type, patternText, Encoder.Encode(value), null, false, e.GetType().Name));
                        continue;
                    }
                    var parsed = pattern.Parse(text);
                    var roundTrips = parsed.Success && Equals(parsed.Value, value);
                    cases.Add(new FormattingCase(type, patternText, Encoder.Encode(value), text, roundTrips, null));
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
        // Equal follows from the text and candidate, so the set holds each pair once.
        var seen = new HashSet<CompareCase>();
        var cases = new List<CompareCase>();
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
                    if (sub == candidate)
                        continue;
                    var compareCase = new CompareCase(sub, candidate, compareInfo.Compare(sub, candidate, CompareOptions.IgnoreCase) == 0);
                    if (seen.Add(compareCase))
                        cases.Add(compareCase);
                }
            }
        }

        foreach (var port in LangTarget.All)
        {
            var body = port.NewWriter();
            body.OpenConstObject("golden", "CompareGolden", "../types", constant: true)
                .Property("culture", body.Str(culture.Name))
                .Comment("[text, candidate, CompareInfo.Compare(text, candidate, IgnoreCase) == 0], as ValueCursor.MatchCaseInsensitive.")
                .OpenBlock("cases: [");
            foreach (var c in cases)
                body.WriteLine(body.Tuple([body.Str(c.Text), body.Str(c.Candidate), body.Bool(c.Equal)]) + ",");
            body.CloseBlock("],")
                .CloseConstObject();
            output.Write(port.Test($"golden/compare/{fileName}"), "golden", body);
        }
    }

    private sealed record CompareCase(string Text, string Candidate, bool Equal);
}
