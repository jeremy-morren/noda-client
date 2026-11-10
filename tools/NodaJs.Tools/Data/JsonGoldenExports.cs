using System.Text.Json;
using NodaJs.Tools.Common;
using NodaTime;
using NodaTime.Serialization.SystemTextJson;
using NodaTime.Text;
using NodaTime.TimeZones;

namespace NodaJs.Tools.Data;

/// <summary>
/// Per calendar, NodaTime.Serialization.SystemTextJson's output for a value of each type it handles, and the values.
/// Non-ISO files use converters with that calendar: JSON doesn't record it.
/// </summary>
internal static class JsonGoldenExports
{
    private static readonly ValueEncoder Encoder = new();

    // NodaConverters.CreateZonedDateTimeConverter's pattern.
    private const string ZonedDateTimePatternText = "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z";

    public static void Run(GeneratedFiles output)
    {
        foreach (var calendar in CalendarSystem.Ids.OrderBy(id => id, StringComparer.Ordinal).Select(CalendarSystem.ForId))
            Write(output, calendar);
    }

    private static void Write(GeneratedFiles output, CalendarSystem calendar)
    {
        var sample = Sample.Create(calendar);
        var options = new JsonSerializerOptions().ConfigureForNodaTime(Settings(calendar));
        var json = JsonSerializer.Serialize(sample, options);

        var properties = typeof(Sample).GetProperties()
            .Select(p => new GoldenProperty(p.Name, p.PropertyType.Name, Encoder.Encode(p.GetValue(sample))))
            .ToList();

        foreach (var port in LangTarget.All)
        {
            var body = port.NewWriter();
            body.OpenConstObject("golden", "JsonGolden", "../types", properties.All(p => p.Value.IsDartConstant))
                .Property("calendar", body.Str(calendar.Id))
                .Property("json", body.Str(json))
                .OpenBlock("properties: [");
            foreach (var p in properties)
                body.WriteLine(body.Object("JsonGoldenProperty", new { name = body.Str(p.Name), type = body.Str(p.Type), value = body.Value(p.Value) }) + ",");
            body.CloseBlock("],")
                .CloseConstObject();
            output.Write(port.Test($"golden/json/{CalendarGoldenExports.FileName(calendar)}"), "golden", body,
                ["NodaTime.Serialization.SystemTextJson's output for a value of each type, and the values."]);
        }
    }

    /// <summary>A property of <see cref="Sample"/>: its name, type name and value.</summary>
    private sealed record GoldenProperty(string Name, string Type, EncodedValue Value);

    private static NodaJsonSettings Settings(CalendarSystem calendar)
    {
        var provider = new SerializeOnlyProvider();
        var settings = new NodaJsonSettings(provider);
        if (calendar == CalendarSystem.Iso)
            return settings;
        settings.LocalDateConverter = new NodaPatternConverter<LocalDate>(LocalDatePattern.Iso.WithCalendar(calendar));
        settings.LocalDateTimeConverter = new NodaPatternConverter<LocalDateTime>(LocalDateTimePattern.ExtendedIso.WithCalendar(calendar));
        settings.OffsetDateConverter = new NodaPatternConverter<OffsetDate>(OffsetDatePattern.GeneralIso.WithCalendar(calendar));
        settings.OffsetDateTimeConverter = new NodaPatternConverter<OffsetDateTime>(OffsetDateTimePattern.Rfc3339.WithCalendar(calendar));
        // YearMonthPattern has no WithCalendar: use the template value (2000-01-01 is in every calendar's range).
        settings.YearMonthConverter = new NodaPatternConverter<YearMonth>(
            YearMonthPattern.Iso.WithTemplateValue(new LocalDate(2000, 1, 1).WithCalendar(calendar).ToYearMonth()));
        settings.ZonedDateTimeConverter = new NodaPatternConverter<ZonedDateTime>(
            ZonedDateTimePattern.CreateWithInvariantCulture(ZonedDateTimePatternText, provider).WithCalendar(calendar));
        return settings;
    }

    private sealed record Sample(
        Instant Instant,
        LocalDate LocalDate,
        LocalTime LocalTime,
        LocalDateTime LocalDateTime,
        AnnualDate AnnualDate,
        YearMonth YearMonth,
        Offset Offset,
        OffsetDate OffsetDate,
        OffsetTime OffsetTime,
        OffsetDateTime OffsetDateTime,
        ZonedDateTime TzdbZonedDateTime,
        ZonedDateTime BclZonedDateTime,
        DateTimeZone TzdbZone,
        DateTimeZone BclZone,
        Duration Duration,
        Period Period,
        Interval Interval,
        DateInterval DateInterval)
    {
        public static Sample Create(CalendarSystem calendar)
        {
            var instant = Instant.FromUtc(2024, 3, 31, 14, 30, 15).PlusNanoseconds(123_456_789);
            var date = new LocalDate(2024, 2, 29);
            var time = new LocalTime(13, 45, 30).PlusNanoseconds(987_654_321);
            var tzdbZone = DateTimeZoneProviders.Tzdb["Europe/London"];
            var bclZone = BclDateTimeZone.FromTimeZoneInfo(TimeZoneInfo.FindSystemTimeZoneById("AUS Eastern Standard Time"));
            var period = new PeriodBuilder { Years = 1, Months = 2, Weeks = 3, Days = 4, Hours = 5, Minutes = 6, Seconds = 7, Milliseconds = 8 }.Build();
            return new Sample(
                Instant: instant,
                LocalDate: date.WithCalendar(calendar),
                LocalTime: time,
                LocalDateTime: date.At(time).WithCalendar(calendar),
                AnnualDate: new AnnualDate(2, 29),
                YearMonth: new LocalDate(2024, 2, 1).WithCalendar(calendar).ToYearMonth(),
                Offset: Offset.FromHoursAndMinutes(5, 30),
                OffsetDate: date.WithOffset(Offset.FromHours(-5)).WithCalendar(calendar),
                OffsetTime: time.WithOffset(Offset.FromHoursAndMinutes(9, 45)),
                OffsetDateTime: date.At(time).WithOffset(Offset.FromHoursAndMinutes(-3, -30)).WithCalendar(calendar),
                TzdbZonedDateTime: instant.InZone(tzdbZone, calendar),
                BclZonedDateTime: instant.InZone(bclZone, calendar),
                TzdbZone: DateTimeZoneProviders.Tzdb["America/New_York"],
                BclZone: bclZone,
                Duration: Duration.FromDays(1) + Duration.FromHours(2) + Duration.FromMinutes(3) + Duration.FromNanoseconds(4_005),
                Period: period,
                Interval: new Interval(instant, instant + Duration.FromHours(36)),
                DateInterval: new DateInterval(date.WithCalendar(calendar), date.PlusDays(10).WithCalendar(calendar)));
        }
    }

    /// <summary>Serialization never looks zones up.</summary>
    private sealed class SerializeOnlyProvider : IDateTimeZoneProvider
    {
        private static InvalidOperationException Unused() =>
            new("The JSON golden files only serialize; a zone provider is only used to deserialize.");

        public string VersionId => throw Unused();
        public System.Collections.ObjectModel.ReadOnlyCollection<string> Ids => throw Unused();
        public DateTimeZone GetSystemDefault() => throw Unused();
        public DateTimeZone? GetZoneOrNull(string id) => throw Unused();
        public DateTimeZone this[string id] => throw Unused();
    }
}
