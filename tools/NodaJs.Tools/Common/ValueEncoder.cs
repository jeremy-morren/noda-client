using System.Collections;
using System.Globalization;
using System.Numerics;
using System.Reflection;
using NodaTime;
using NodaTime.Calendars;
using NodaTime.Text;
using NodaTime.TimeZones;
using Part = NodaJs.Tools.Common.NamedValue<NodaJs.Tools.Common.EncodedValue>;

namespace NodaJs.Tools.Common;

/// <summary>
/// Encodes .NET values as <see cref="EncodedValue"/>s. NodaTime values are encoded by component, not as text, so tests of
/// core types don't depend on parsing.
/// </summary>
public sealed class ValueEncoder
{
    private const int MaxDepth = 12;
    private const int MaxItems = 20000;

    private static readonly BindingFlags AllInstance = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;

    /// <summary>Tried first for every non-null value; null for the default encoding.</summary>
    public Func<object, EncodedValue?>? Override { get; init; }

    /// <summary>Assemblies whose types are encoded field by field.</summary>
    public HashSet<Assembly> StructuralAssemblies { get; } = [];

    public EncodedValue Encode(object? value) => Encode(value, 0);

    private EncodedValue Encode(object? value, int depth)
    {
        if (value is null)
            return EncodedValue.Null;
        if (depth > MaxDepth)
            return Unsupported(value, "maximum depth exceeded");
        if (Override?.Invoke(value) is { } overridden)
            return overridden;
        switch (value)
        {
            case string s: return EncodedValue.String(s);
            case char c: return EncodedValue.String(c.ToString());
            case bool b: return EncodedValue.Bool(b);
            case int or short or byte or sbyte or ushort or uint or long:
                return EncodedValue.Int(Convert.ToInt64(value, CultureInfo.InvariantCulture));
            case ulong u: return new EncodedValue.IntegerValue(u, false);
            case double d: return EncodedValue.Double(d);
            case float f: return EncodedValue.Double(f);
            case decimal m: return EncodedValue.Tag("decimal", new { value = Str(m.ToString(CultureInfo.InvariantCulture)) });
            case BigInteger big: return EncodedValue.BigInt(big);
            case Int128 i128: return EncodedValue.BigInt(i128);
            case Enum e: return EncodeEnum(e);
            case Type t: return EncodedValue.Tag(nameof(Type), new { name = Str(t.FullName) });

            case LocalDate d: return EncodedValue.Tag(nameof(LocalDate), DateParts(d));
            case LocalTime t: return EncodedValue.Tag(nameof(LocalTime), TimeParts(t));
            case LocalDateTime ldt: return EncodedValue.Tag(nameof(LocalDateTime), [.. DateParts(ldt.Date), .. TimeParts(ldt.TimeOfDay)]);
            case Instant i: return EncodeInstant(i);
            case Duration d: return EncodedValue.Tag(nameof(Duration), DurationParts(d));
            case Offset o: return EncodedValue.Tag(nameof(Offset), new { seconds = Int(o.Seconds) });
            case OffsetDateTime odt:
                return EncodedValue.Tag(nameof(OffsetDateTime), [.. DateParts(odt.Date), .. TimeParts(odt.TimeOfDay), new("offsetSeconds", Int(odt.Offset.Seconds))]);
            case OffsetDate od: return EncodedValue.Tag(nameof(OffsetDate), [.. DateParts(od.Date), new("offsetSeconds", Int(od.Offset.Seconds))]);
            case OffsetTime ot: return EncodedValue.Tag(nameof(OffsetTime), [.. TimeParts(ot.TimeOfDay), new("offsetSeconds", Int(ot.Offset.Seconds))]);
            case ZonedDateTime zdt:
                return EncodedValue.Tag(nameof(ZonedDateTime), [.. DateParts(zdt.Date), .. TimeParts(zdt.TimeOfDay),
                    new("offsetSeconds", Int(zdt.Offset.Seconds)), new("zone", Encode(zdt.Zone, depth + 1))]);
            case YearMonth ym: return EncodedValue.Tag(nameof(YearMonth), new { year = Int(ym.Year), month = Int(ym.Month), calendar = Calendar(ym.Calendar) });
            case AnnualDate ad: return EncodedValue.Tag(nameof(AnnualDate), new { month = Int(ad.Month), day = Int(ad.Day) });
            case Period p: return EncodePeriod(p);
            case Interval interval:
                return EncodedValue.Tag(nameof(Interval), new
                {
                    start = interval.HasStart ? EncodeInstant(interval.Start) : EncodedValue.Null,
                    end = interval.HasEnd ? EncodeInstant(interval.End) : EncodedValue.Null,
                });
            case DateInterval di: return EncodedValue.Tag(nameof(DateInterval), new { start = Encode(di.Start, depth + 1), end = Encode(di.End, depth + 1) });
            case CalendarSystem calendar: return EncodedValue.Tag(nameof(CalendarSystem), new { id = Str(calendar.Id) });
            case Era era: return EncodedValue.Tag(nameof(Era), new { name = Str(era.Name) });
            case DateTimeZone zone: return EncodeZone(zone, depth);
            case ZoneInterval zi: return EncodeZoneInterval(zi);
            case CultureInfo culture: return EncodedValue.Tag(nameof(CultureInfo), new { name = Str(culture.Name) });
            case IFormattable when IsBclDateTimeType(value.GetType()):
                return EncodedValue.Tag("Bcl", new
                {
                    type = Str(value.GetType().Name),
                    text = Str(((IFormattable) value).ToString(BclRoundtripFormat(value), CultureInfo.InvariantCulture)),
                });
            case Delegate del:
                return EncodeDelegate(del, depth);
        }

        var type = value.GetType();
        if (IsPattern(type))
            return EncodePattern(value, depth);
        if (type.IsGenericType && type.FullName!.StartsWith("System.ValueTuple`", StringComparison.Ordinal) ||
            type.FullName!.StartsWith("System.Tuple`", StringComparison.Ordinal))
        {
            var items = type.GetFields().Select(f => f.GetValue(value)).Concat(
                type.GetProperties().Where(p => p.Name.StartsWith("Item", StringComparison.Ordinal)).Select(p => p.GetValue(value)));
            return EncodedValue.Tag("Tuple", new { items = EncodedValue.List(items.Select(i => Encode(i, depth + 1))) });
        }
        if (type.IsGenericType && type.GetGenericTypeDefinition() == typeof(KeyValuePair<,>))
            return EncodedValue.Tag("KeyValuePair", new
            {
                key = Encode(type.GetProperty("Key")!.GetValue(value), depth + 1),
                value = Encode(type.GetProperty("Value")!.GetValue(value), depth + 1),
            });
        if (value is IEnumerable enumerable)
        {
            var items = new List<EncodedValue>();
            foreach (var item in enumerable)
            {
                if (items.Count >= MaxItems)
                    return Unsupported(value, $"more than {MaxItems} items");
                items.Add(Encode(item, depth + 1));
            }
            return EncodedValue.List(items);
        }
        if (StructuralAssemblies.Contains(type.Assembly))
            return EncodeStructurally(value, type, depth);
        return Unsupported(value, null);
    }

    private static EncodedValue Str(string? value) => EncodedValue.String(value);

    private static EncodedValue Int(long value) => EncodedValue.Int(value);

    public static EncodedValue Unsupported(object value, string? reason)
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
        return EncodedValue.Tag("Unsupported", new
        {
            type = Str(value.GetType().FullName),
            text = Str(text),
            reason = reason is null ? null : Str(reason),
        });
    }

    private static EncodedValue EncodeEnum(Enum e)
    {
        var type = e.GetType();
        var name = type.IsDefined(typeof(FlagsAttribute)) || Enum.IsDefined(type, e) ? e.ToString() : "";
        var typeName = type.Namespace?.StartsWith("NodaTime", StringComparison.Ordinal) == true ? DocComments.FlatTypeName(type) : type.FullName!;
        return EncodedValue.Tag("enum", new { type = Str(typeName), name = Str(name), value = Int(Convert.ToInt64(e, CultureInfo.InvariantCulture)) });
    }

    /// <summary>The calendar's ID; null (left out) for ISO.</summary>
    private static EncodedValue? Calendar(CalendarSystem calendar) => calendar == CalendarSystem.Iso ? null : Str(calendar.Id);

    private static IReadOnlyList<Part> DateParts(LocalDate date) =>
        Part.FromObject(new { year = Int(date.Year), month = Int(date.Month), day = Int(date.Day), calendar = Calendar(date.Calendar) });

    private static IReadOnlyList<Part> TimeParts(LocalTime time) =>
        Part.FromObject(new { hour = Int(time.Hour), minute = Int(time.Minute), second = Int(time.Second), nanosecond = Int(time.NanosecondOfSecond) });

    private static readonly PropertyInfo DurationFloorDays = typeof(Duration).GetProperty("FloorDays", AllInstance)!;
    private static readonly PropertyInfo DurationNanoOfFloorDay = typeof(Duration).GetProperty("NanosecondOfFloorDay", AllInstance)!;

    private static IReadOnlyList<Part> DurationParts(Duration duration) =>
        Part.FromObject(new { days = Int((int) DurationFloorDays.GetValue(duration)!), nanoOfDay = Int((long) DurationNanoOfFloorDay.GetValue(duration)!) });

    private static readonly PropertyInfo InstantTimeSinceEpoch = typeof(Instant).GetProperty("TimeSinceEpoch", AllInstance)!;

    public static EncodedValue EncodeInstant(Instant instant)
    {
        var sinceEpoch = (Duration) InstantTimeSinceEpoch.GetValue(instant)!;
        var text = InstantPattern.ExtendedIso.Format(instant);
        return EncodedValue.Tag(nameof(Instant), [.. DurationParts(sinceEpoch), new("iso", Str(text))]);
    }

    private static EncodedValue EncodePeriod(Period period)
    {
        // Zero units are left out.
        EncodedValue? Unit(long value) => value == 0 ? null : Int(value);
        return EncodedValue.Tag(nameof(Period), new
        {
            years = Unit(period.Years),
            months = Unit(period.Months),
            weeks = Unit(period.Weeks),
            days = Unit(period.Days),
            hours = Unit(period.Hours),
            minutes = Unit(period.Minutes),
            seconds = Unit(period.Seconds),
            milliseconds = Unit(period.Milliseconds),
            ticks = Unit(period.Ticks),
            nanoseconds = Unit(period.Nanoseconds),
        });
    }

    /// <summary>A static method, or a lambda a NodaTime factory returned, as that call with its captured arguments.</summary>
    private EncodedValue EncodeDelegate(Delegate del, int depth)
    {
        var method = del.Method;
        var closure = del.Target;
        var lambdaOf = System.Text.RegularExpressions.Regex.Match(method.Name, @"^<(\w+)>b__");
        var outerType = method.DeclaringType?.DeclaringType;
        if (closure is not null && lambdaOf.Success && outerType is not null)
        {
            var factoryName = lambdaOf.Groups[1].Value;
            var fields = closure.GetType().GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            var factory = outerType
                .GetMethods(BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic)
                .Where(m => m.Name == factoryName)
                .FirstOrDefault(m => m.GetParameters().Length == fields.Length &&
                    m.GetParameters().All(p => fields.Any(f => f.Name == p.Name)));
            if (factory is not null)
            {
                var args = factory.GetParameters()
                    .Select(p => Encode(fields.Single(f => f.Name == p.Name).GetValue(closure), depth + 1));
                return EncodedValue.Tag(nameof(Delegate), new { method = Str($"{outerType.Name}.{factoryName}"), args = EncodedValue.List(args) });
            }
        }
        return EncodedValue.Tag(nameof(Delegate), new { method = Str($"{method.DeclaringType?.Name}.{method.Name}") });
    }

    private EncodedValue EncodeZone(DateTimeZone zone, int depth)
    {
        if (zone is BclDateTimeZone)
            return EncodedValue.Tag(nameof(DateTimeZone), new { id = Str(zone.Id), provider = Str("bcl") });
        // tzdb first: tzdb also has fixed zones (e.g. Etc/GMT-12) whose IDs differ from DateTimeZone.ForOffset's.
        if (DateTimeZoneProviders.Tzdb.GetZoneOrNull(zone.Id) == zone)
            return EncodedValue.Tag(nameof(DateTimeZone), new { id = Str(zone.Id), provider = Str("tzdb") });
        if (zone == DateTimeZone.Utc || zone.GetType().Name == "FixedDateTimeZone")
            return EncodedValue.Tag(nameof(DateTimeZone), new { id = Str(zone.Id), provider = Str("fixed"), offsetSeconds = Int(zone.MinOffset.Seconds) });
        // E.g. NodaTime.Testing zones.
        var intervals = zone.GetZoneIntervals(Instant.MinValue, Instant.MaxValue).Take(1000).Select(EncodeZoneInterval);
        return EncodedValue.Tag(nameof(DateTimeZone), new
        {
            id = Str(zone.Id),
            provider = Str("custom"),
            type = Str(zone.GetType().Name),
            intervals = EncodedValue.List(intervals),
        });
    }

    public static EncodedValue EncodeZoneInterval(ZoneInterval interval) =>
        EncodedValue.Tag(nameof(ZoneInterval), new
        {
            name = Str(interval.Name),
            start = interval.HasStart ? EncodeInstant(interval.Start) : EncodedValue.Null,
            end = interval.HasEnd ? EncodeInstant(interval.End) : EncodedValue.Null,
            wallOffsetSeconds = Int(interval.WallOffset.Seconds),
            savingsSeconds = Int(interval.Savings.Seconds),
        });

    private static bool IsPattern(Type type) =>
        type.Namespace == "NodaTime.Text" && type.GetInterfaces().Any(i => i.IsGenericType && i.GetGenericTypeDefinition() == typeof(IPattern<>));

    private EncodedValue EncodePattern(object pattern, int depth)
    {
        var type = pattern.GetType();
        var formatInfo = type.GetProperty("FormatInfo", AllInstance)?.GetValue(pattern);
        var culture = formatInfo?.GetType().GetProperty("CultureInfo")?.GetValue(formatInfo) as CultureInfo;
        // Null (left out) where the pattern has no such property.
        EncodedValue? Property(string name) =>
            type.GetProperty(name) is { } property ? Encode(property.GetValue(pattern), depth + 1) : null;
        return EncodedValue.Tag("Pattern", new
        {
            type = Str(type.Name),
            patternText = type.GetProperty("PatternText") is { } patternText ? Str((string?) patternText.GetValue(pattern)) : null,
            culture = culture is null ? null : Encode(culture, depth + 1),
            templateValue = Property("TemplateValue"),
            resolver = Property("Resolver"),
            zoneProvider = Property("ZoneProvider"),
        });
    }

    private static bool IsBclDateTimeType(Type type) =>
        type == typeof(DateTime) || type == typeof(DateTimeOffset) || type == typeof(TimeSpan) ||
        type == typeof(DateOnly) || type == typeof(TimeOnly);

    private static string BclRoundtripFormat(object value) => value is TimeSpan ? "c" : "o";

    /// <summary>By instance fields (backing fields included), camelCase, omitting nulls and empty collections.</summary>
    private EncodedValue EncodeStructurally(object value, Type type, int depth)
    {
        var parts = new List<Part>();
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
                parts.Add(new Part(name, Encode(fieldValue, depth + 1)));
            }
        return EncodedValue.Tag(NestedName(type), parts);
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
