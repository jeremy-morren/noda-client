using System.Text.Json;
using NodaJs.Tools.Common;
using NodaTime;
using NodaTime.Serialization.SystemTextJson;
using NodaTime.Text;
using NodaTime.TimeZones;

namespace NodaJs.Tools.Data;

/// <summary>
/// Golden JSON (test/golden/json/&lt;calendar&gt;.generated.ts): an object with a property for every type
/// NodaTime.Serialization.SystemTextJson handles (two for each zoned type: a tzdb zone and a BCL zone), serialized by
/// it, with each property's value encoded for the tests to compare with.
/// <para>
/// The ISO file uses the default converters. The Julian and Coptic files hold the same values converted to those
/// calendars, serialized with converters whose patterns use that calendar: JSON doesn't record the calendar, so the
/// reader has to be given it (noda-js: <c>fromJSON(json, calendar)</c>).
/// </para>
/// </summary>
internal static class JsonGoldenExports
{
    private static readonly TsValueEncoder Encoder = new();

    // NodaConverters.CreateZonedDateTimeConverter's pattern.
    private const string ZonedDateTimePatternText = "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z";

    public static void Run(GeneratedFiles output)
    {
        foreach (var calendar in new[] { CalendarSystem.Iso, CalendarSystem.Julian, CalendarSystem.Coptic })
            Write(output, calendar);
    }

    private static void Write(GeneratedFiles output, CalendarSystem calendar)
    {
        var sample = Sample.Create(calendar);
        var options = new JsonSerializerOptions().ConfigureForNodaTime(Settings(calendar));
        var json = JsonSerializer.Serialize(sample, options);

        var body = new TypescriptWriter()
            .WriteLine("import type { JsonGolden } from \"../types.ts\";", emptyLineAfter: true)
            .OpenBlock("export const golden: JsonGolden = {")
            .Property("calendar", Ts.Str(calendar.Id))
            .Property("json", Ts.Str(json))
            .OpenBlock("properties: [");
        foreach (var property in typeof(Sample).GetProperties())
            body.WriteLine("{ " +
                           $"name: {Ts.Str(property.Name)}, " +
                           $"type: {Ts.Str(property.PropertyType.Name)}, " +
                           $"value: {Encoder.Encode(property.GetValue(sample))} " +
                           "},");
        body.CloseBlock("],")
            .CloseBlock("};");
        output.Write($"test/golden/json/{calendar.Id.ToLowerInvariant()}.generated.ts", "golden", body,
            ["NodaTime.Serialization.SystemTextJson's output for one value of each type, and the values it serialized."]);
    }

    /// <summary>
    /// The default converters, with a provider that throws (zones are only looked up when deserializing); for a non-ISO
    /// calendar, converters whose patterns use it for the types that have a calendar.
    /// </summary>
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
        // YearMonthPattern has no WithCalendar: the calendar comes from the template value.
        settings.YearMonthConverter = new NodaPatternConverter<YearMonth>(YearMonthPattern.Iso.WithTemplateValue(new YearMonth(2000, 1, calendar)));
        settings.ZonedDateTimeConverter = new NodaPatternConverter<ZonedDateTime>(
            ZonedDateTimePattern.CreateWithInvariantCulture(ZonedDateTimePatternText, provider).WithCalendar(calendar));
        return settings;
    }

    /// <summary>One value of each type, in the given calendar where the type has one.</summary>
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
            // A Windows zone ID ("AUS Eastern Standard Time"): noda-js reads it with noda-js/windows.
            var bclZone = BclDateTimeZone.FromTimeZoneInfo(TimeZoneInfo.FindSystemTimeZoneById("AUS Eastern Standard Time"));
            var period = new PeriodBuilder { Years = 1, Months = 2, Weeks = 3, Days = 4, Hours = 5, Minutes = 6, Seconds = 7, Milliseconds = 8 }.Build();
            return new Sample(
                Instant: instant,
                LocalDate: date.WithCalendar(calendar),
                LocalTime: time,
                LocalDateTime: date.At(time).WithCalendar(calendar),
                AnnualDate: new AnnualDate(2, 29),
                // The month containing 1 February 2024 (ISO) in the calendar.
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

    /// <summary>A provider that throws: serialization never looks zones up, so any call is a bug.</summary>
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
