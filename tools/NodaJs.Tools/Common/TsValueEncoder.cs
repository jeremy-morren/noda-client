using System.Collections;
using System.Globalization;
using System.Numerics;
using System.Reflection;
using System.Text;
using NodaTime;
using NodaTime.Calendars;
using NodaTime.Text;
using NodaTime.TimeZones;

namespace NodaJs.Tools.Common;

/// <summary>
/// Encodes .NET values (NodaTime values, test data objects, primitives, collections) as TypeScript
/// literals. NodaTime values are written as tagged objects built from their components
/// (<c>{ $: "LocalDate", year: 2024, month: 3, day: 1 }</c>), not as text, so tests of core types don't
/// depend on text parsing. The tags are decoded by test/helpers/decode.ts; the shapes are the
/// <c>Encoded*</c> types in test/scenarios/types.ts.
/// </summary>
public sealed class TsValueEncoder
{
    private const int MaxDepth = 12;
    private const int MaxItems = 20000;

    private static readonly BindingFlags AllInstance = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;

    /// <summary>
    /// Optional hook, tried first for every non-null value. Returns the encoded text, or null to use the
    /// default encoding.
    /// </summary>
    public Func<object, string?>? Override { get; init; }

    /// <summary>
    /// Assemblies whose own types (e.g. test data classes) are encoded field by field.
    /// </summary>
    public HashSet<Assembly> StructuralAssemblies { get; } = [];

    public string Encode(object? value) => Encode(value, 0);

    private string Encode(object? value, int depth)
    {
        if (value is null)
            return "null";
        if (depth > MaxDepth)
            return Unsupported(value, "maximum depth exceeded");
        if (Override?.Invoke(value) is string overridden)
            return overridden;
        switch (value)
        {
            case string s: return Ts.Str(s);
            case char c: return Ts.Str(c.ToString());
            case bool b: return Ts.Bool(b);
            case int or short or byte or sbyte or ushort or uint or long:
                return Ts.Int(Convert.ToInt64(value, CultureInfo.InvariantCulture));
            case ulong u: return Ts.Int(u);
            case double d: return Ts.Double(d);
            case float f: return Ts.Double(f);
            case decimal m: return Tag("decimal", ("value", Ts.Str(m.ToString(CultureInfo.InvariantCulture))));
            case BigInteger big: return Ts.BigInt(big);
            case Int128 i128: return i128.ToString(CultureInfo.InvariantCulture) + "n";
            case Enum e: return EncodeEnum(e);
            case Type t: return Tag(nameof(Type), ("name", Ts.Str(t.FullName)));

            // NodaTime values
            case LocalDate d: return Tag(nameof(LocalDate), DateParts(d));
            case LocalTime t: return Tag(nameof(LocalTime), TimeParts(t));
            case LocalDateTime ldt: return Tag(nameof(LocalDateTime), [.. DateParts(ldt.Date), .. TimeParts(ldt.TimeOfDay)]);
            case Instant i: return EncodeInstant(i);
            case Duration d: return Tag(nameof(Duration), DurationParts(d));
            case Offset o: return Tag(nameof(Offset), ("seconds", Ts.Int(o.Seconds)));
            case OffsetDateTime odt:
                return Tag(nameof(OffsetDateTime), [.. DateParts(odt.Date), .. TimeParts(odt.TimeOfDay), ("offsetSeconds", Ts.Int(odt.Offset.Seconds))]);
            case OffsetDate od: return Tag(nameof(OffsetDate), [.. DateParts(od.Date), ("offsetSeconds", Ts.Int(od.Offset.Seconds))]);
            case OffsetTime ot: return Tag(nameof(OffsetTime), [.. TimeParts(ot.TimeOfDay), ("offsetSeconds", Ts.Int(ot.Offset.Seconds))]);
            case ZonedDateTime zdt:
                return Tag(nameof(ZonedDateTime), [.. DateParts(zdt.Date), .. TimeParts(zdt.TimeOfDay),
                    ("offsetSeconds", Ts.Int(zdt.Offset.Seconds)), ("zone", Encode(zdt.Zone, depth + 1))]);
            case YearMonth ym: return Tag(nameof(YearMonth), [("year", Ts.Int(ym.Year)), ("month", Ts.Int(ym.Month)), .. CalendarPart(ym.Calendar)]);
            case AnnualDate ad: return Tag(nameof(AnnualDate), ("month", Ts.Int(ad.Month)), ("day", Ts.Int(ad.Day)));
            case Period p: return EncodePeriod(p);
            case Interval interval:
                return Tag(nameof(Interval),
                    ("start", interval.HasStart ? EncodeInstant(interval.Start) : "null"),
                    ("end", interval.HasEnd ? EncodeInstant(interval.End) : "null"));
            case DateInterval di: return Tag(nameof(DateInterval), ("start", Encode(di.Start, depth + 1)), ("end", Encode(di.End, depth + 1)));
            case CalendarSystem calendar: return Tag(nameof(CalendarSystem), ("id", Ts.Str(calendar.Id)));
            case Era era: return Tag(nameof(Era), ("name", Ts.Str(era.Name)));
            case DateTimeZone zone: return EncodeZone(zone, depth);
            case ZoneInterval zi: return EncodeZoneInterval(zi);
            case CultureInfo culture: return Tag(nameof(CultureInfo), ("name", Ts.Str(culture.Name)));
            case IFormattable when IsBclDateTimeType(value.GetType()):
                return Tag("Bcl", ("type", Ts.Str(value.GetType().Name)), ("text", Ts.Str(((IFormattable) value).ToString(BclRoundtripFormat(value), CultureInfo.InvariantCulture))));
            case Delegate del:
                return Tag(nameof(Delegate), ("method", Ts.Str($"{del.Method.DeclaringType?.Name}.{del.Method.Name}")));
        }

        var type = value.GetType();
        if (IsPattern(type))
            return EncodePattern(value, depth);
        if (type.IsGenericType && type.FullName!.StartsWith("System.ValueTuple`", StringComparison.Ordinal) ||
            type.FullName!.StartsWith("System.Tuple`", StringComparison.Ordinal))
        {
            var items = type.GetFields().Select(f => f.GetValue(value)).Concat(
                type.GetProperties().Where(p => p.Name.StartsWith("Item", StringComparison.Ordinal)).Select(p => p.GetValue(value)));
            return Tag("Tuple", ("items", "[" + string.Join(", ", items.Select(i => Encode(i, depth + 1))) + "]"));
        }
        if (type.IsGenericType && type.GetGenericTypeDefinition() == typeof(KeyValuePair<,>))
            return Tag("KeyValuePair",
                ("key", Encode(type.GetProperty("Key")!.GetValue(value), depth + 1)),
                ("value", Encode(type.GetProperty("Value")!.GetValue(value), depth + 1)));
        if (value is IEnumerable enumerable)
        {
            var items = new List<string>();
            foreach (var item in enumerable)
            {
                if (items.Count >= MaxItems)
                    return Unsupported(value, $"more than {MaxItems} items");
                items.Add(Encode(item, depth + 1));
            }
            return "[" + string.Join(", ", items) + "]";
        }
        if (StructuralAssemblies.Contains(type.Assembly))
            return EncodeStructurally(value, type, depth);
        return Unsupported(value, null);
    }

    public static string Tag(string tag, params (string Name, string Value)[] parts)
    {
        var builder = new StringBuilder();
        builder.Append("{ $: ").Append(Ts.Str(tag));
        foreach (var (name, value) in parts)
        {
            builder.Append(", ").Append(name).Append(": ").Append(value);
        }
        builder.Append(" }");
        return builder.ToString();
    }

    public static string Unsupported(object value, string? reason)
    {
        string text;
        try
        {
            text = value.ToString() ?? "";
        }
        catch (Exception e)
        {
            text = $"<ToString threw {e.GetType().Name}>";
        }
        var parts = new List<(string, string)> { ("type", Ts.Str(value.GetType().FullName)), ("text", Ts.Str(text)) };
        if (reason is not null)
            parts.Add(("reason", Ts.Str(reason)));
        return Tag("Unsupported", [.. parts]);
    }

    private string EncodeEnum(Enum e)
    {
        var type = e.GetType();
        var name = type.IsDefined(typeof(FlagsAttribute)) || Enum.IsDefined(type, e) ? e.ToString() : "";
        var typeName = type.Namespace?.StartsWith("NodaTime", StringComparison.Ordinal) == true ? TsTypeName(type) : type.FullName!;
        return Tag("enum", ("type", Ts.Str(typeName)), ("name", Ts.Str(name)), ("value", Ts.Int(Convert.ToInt64(e, CultureInfo.InvariantCulture))));
    }

    private static string TsTypeName(Type type) => type.DeclaringType is null ? type.Name : TsTypeName(type.DeclaringType) + type.Name;

    private static (string, string)[] CalendarPart(CalendarSystem calendar) =>
        calendar == CalendarSystem.Iso ? [] : [("calendar", Ts.Str(calendar.Id))];

    private static (string, string)[] DateParts(LocalDate date) =>
        [("year", Ts.Int(date.Year)), ("month", Ts.Int(date.Month)), ("day", Ts.Int(date.Day)), .. CalendarPart(date.Calendar)];

    private static (string, string)[] TimeParts(LocalTime time) =>
        [("hour", Ts.Int(time.Hour)), ("minute", Ts.Int(time.Minute)), ("second", Ts.Int(time.Second)), ("nanosecond", Ts.Int(time.NanosecondOfSecond))];

    private static readonly PropertyInfo DurationFloorDays = typeof(Duration).GetProperty("FloorDays", AllInstance)!;
    private static readonly PropertyInfo DurationNanoOfFloorDay = typeof(Duration).GetProperty("NanosecondOfFloorDay", AllInstance)!;

    private static (string, string)[] DurationParts(Duration duration) =>
        [("days", Ts.Int((int) DurationFloorDays.GetValue(duration)!)), ("nanoOfDay", Ts.Int((long) DurationNanoOfFloorDay.GetValue(duration)!))];

    private static readonly PropertyInfo InstantTimeSinceEpoch = typeof(Instant).GetProperty("TimeSinceEpoch", AllInstance)!;

    public static string EncodeInstant(Instant instant)
    {
        var sinceEpoch = (Duration) InstantTimeSinceEpoch.GetValue(instant)!;
        var text = InstantPattern.ExtendedIso.Format(instant);
        return Tag(nameof(Instant), [.. DurationParts(sinceEpoch), ("iso", Ts.Str(text))]);
    }

    private static string EncodePeriod(Period period)
    {
        var parts = new List<(string, string)>();
        void Add(string name, long value)
        {
            if (value != 0)
                parts.Add((name, Ts.Int(value)));
        }
        Add("years", period.Years);
        Add("months", period.Months);
        Add("weeks", period.Weeks);
        Add("days", period.Days);
        Add("hours", period.Hours);
        Add("minutes", period.Minutes);
        Add("seconds", period.Seconds);
        Add("milliseconds", period.Milliseconds);
        Add("ticks", period.Ticks);
        Add("nanoseconds", period.Nanoseconds);
        return Tag(nameof(Period), [.. parts]);
    }

    private string EncodeZone(DateTimeZone zone, int depth)
    {
        // A Windows (BCL) zone, by its Windows ID: noda-js maps it to a tzdb zone (noda-js/windows).
        if (zone is BclDateTimeZone)
            return Tag(nameof(DateTimeZone), ("id", Ts.Str(zone.Id)), ("provider", Ts.Str("bcl")));
        // tzdb first: tzdb also has fixed zones (e.g. Etc/GMT-12) whose IDs differ from DateTimeZone.ForOffset's.
        if (DateTimeZoneProviders.Tzdb.GetZoneOrNull(zone.Id) == zone)
            return Tag(nameof(DateTimeZone), ("id", Ts.Str(zone.Id)), ("provider", Ts.Str("tzdb")));
        if (zone == DateTimeZone.Utc || zone.GetType().Name == "FixedDateTimeZone")
            return Tag(nameof(DateTimeZone), ("id", Ts.Str(zone.Id)), ("provider", Ts.Str("fixed")),
                ("offsetSeconds", Ts.Int(zone.MinOffset.Seconds)));
        // Anything else (e.g. NodaTime.Testing zones): describe the zone by all its intervals.
        var intervals = zone.GetZoneIntervals(Instant.MinValue, Instant.MaxValue).Take(1000).Select(EncodeZoneInterval);
        return Tag(nameof(DateTimeZone), ("id", Ts.Str(zone.Id)), ("provider", Ts.Str("custom")), ("type", Ts.Str(zone.GetType().Name)),
            ("intervals", "[" + string.Join(", ", intervals) + "]"));
    }

    public static string EncodeZoneInterval(ZoneInterval interval) =>
        Tag(nameof(ZoneInterval),
            ("name", Ts.Str(interval.Name)),
            ("start", interval.HasStart ? EncodeInstant(interval.Start) : "null"),
            ("end", interval.HasEnd ? EncodeInstant(interval.End) : "null"),
            ("wallOffsetSeconds", Ts.Int(interval.WallOffset.Seconds)),
            ("savingsSeconds", Ts.Int(interval.Savings.Seconds)));

    private static bool IsPattern(Type type) =>
        type.Namespace == "NodaTime.Text" && type.GetInterfaces().Any(i => i.IsGenericType && i.GetGenericTypeDefinition() == typeof(IPattern<>));

    private string EncodePattern(object pattern, int depth)
    {
        var type = pattern.GetType();
        var parts = new List<(string, string)> { ("type", Ts.Str(type.Name)) };
        if (type.GetProperty("PatternText") is { } patternText)
            parts.Add(("patternText", Ts.Str((string?) patternText.GetValue(pattern))));
        // FormatInfo is internal; its CultureInfo tells us which culture the pattern uses.
        if (type.GetProperty("FormatInfo", AllInstance)?.GetValue(pattern) is { } formatInfo &&
            formatInfo.GetType().GetProperty("CultureInfo")?.GetValue(formatInfo) is CultureInfo culture)
            parts.Add(("culture", Encode(culture, depth + 1)));
        if (type.GetProperty("TemplateValue") is { } template)
            parts.Add(("templateValue", Encode(template.GetValue(pattern), depth + 1)));
        // ZonedDateTimePattern also needs its resolver and zone provider to be recreated.
        foreach (var name in new[] { "Resolver", "ZoneProvider" })
        {
            if (type.GetProperty(name) is { } property)
                parts.Add((Ts.CamelCase(name), Encode(property.GetValue(pattern), depth + 1)));
        }
        return Tag("Pattern", [.. parts]);
    }

    private static bool IsBclDateTimeType(Type type) =>
        type == typeof(DateTime) || type == typeof(DateTimeOffset) || type == typeof(TimeSpan) ||
        type == typeof(DateOnly) || type == typeof(TimeOnly);

    private static string BclRoundtripFormat(object value) => value is TimeSpan ? "c" : "o";

    /// <summary>
    /// Encodes an object by its instance fields (including auto-property backing fields), named in camelCase.
    /// Fields with null values are omitted.
    /// </summary>
    private string EncodeStructurally(object value, Type type, int depth)
    {
        var parts = new List<(string, string)>();
        var seen = new HashSet<string>();
        for (var t = type; t is not null && t != typeof(object); t = t.BaseType)
            foreach (var field in t.GetFields(AllInstance | BindingFlags.DeclaredOnly).OrderBy(f => f.MetadataToken))
            {
                var name = field.Name;
                if (name.StartsWith('<'))
                {
                    var end = name.IndexOf('>');
                    if (!name.EndsWith("k__BackingField", StringComparison.Ordinal))
                        continue;
                    name = name[1..end];
                }
                name = Ts.CamelCase(name.TrimStart('_'));
                if (!seen.Add(name))
                    continue;
                var fieldValue = field.GetValue(value);
                if (fieldValue is null || fieldValue is ICollection { Count: 0 })
                    continue;
                parts.Add((name, Encode(fieldValue, depth + 1)));
            }
        return Tag(NestedName(type), [.. parts]);
    }

    /// <summary>"NodaTime.Test.Text.LocalDatePatternTest+Data" → "LocalDatePatternTest.Data".</summary>
    public static string NestedName(Type type)
    {
        var name = type.Name;
        var backtick = name.IndexOf('`');
        if (backtick >= 0)
            name = name[..backtick];
        return type.DeclaringType is null ? name : NestedName(type.DeclaringType) + "." + name;
    }
}
