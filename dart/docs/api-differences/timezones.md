# API differences: time zones

`DateTimeZone`, `ZonedDateTime`, providers and `TimeZones/**` (except the system source).

| C# member | Dart member | Why |
|---|---|---|
| `IDateTimeZoneProvider this[string id]`, `DateTimeZoneCache this[string id]` | `operator [](String id)` | Indexers |
| `IDateTimeZoneProvider.Ids` (`ReadOnlyCollection<string>`) | `List<String> get Ids` (unmodifiable) | Read-only collections |
| `DateTimeZone.GetZoneIntervals(Interval)`, `GetZoneIntervals(Interval, ZoneEqualityComparer.Options)` | `GetZoneIntervalsInterval(Interval interval, [ZoneEqualityComparerOptions? options])` | Overloads: `GetZoneIntervals(Instant, Instant)` is declared first; the two `Interval` overloads form a prefix chain |
| `DateTimeZone.ToJson`/`FromJson` (Serialization package) | `toJson()` / `factory DateTimeZone.fromJson(json, provider)` | JSON, as noda-js |
| `ZonedDateTime(Instant, DateTimeZone[, CalendarSystem])` | `ZonedDateTime(instant, zone, [calendar])` | Prefix chain |
| `ZonedDateTime(LocalDateTime, DateTimeZone, Offset)` | `ZonedDateTime.LocalDateTimeZoneOffset(...)` | Other public constructor overload |
| `ZonedDateTime operator -(ZonedDateTime, ZonedDateTime)`, `Minus(ZonedDateTime)` | `MinusZonedDateTime(other)` | Dart's `-` takes the first declared overload (`- Duration`) |
| `ZonedDateTime.Subtract(ZonedDateTime, ZonedDateTime)` | `SubtractZonedDateTime(end, start)` | Overloads |
| `ZonedDateTime.ToString(string, IFormatProvider)` | `ToStringPattern(patternText, [formatProvider])`; `toString()` uses the invariant culture | Dart's `toString` takes no parameters |
| `ZonedDateTime.Deconstruct(out ...)` | `(LocalDateTime, DateTimeZone, Offset) get Deconstruct` | Records |
| `ZonedDateTime.Comparer`, `.Comparer.Local`, `.Comparer.Instant` | `ZonedDateTimeComparer` (`.Local`, `.Instant`); the implementations are library-private | Nested types |
| `ZonedDateTime.Zone`'s `zone ?? DateTimeZone.Utc` fallback | dropped | No `default(ZonedDateTime)` in Dart |
| `ZonedDateTime.ToDateTimeUtc()`, `ToDateTimeUnspecified()` | return a UTC / local `core.DateTime` | As `Instant.ToDateTimeUtc()` (core.md) and `LocalDateTime.ToDateTimeUnspecified()` (local.md). |
| `ZonedDateTime.ToDateTimeOffset`, `FromDateTimeOffset` | not ported | Dart has no `DateTimeOffset`; `ToDateTimeUtc()` is the same instant. From a Dart `DateTime`: `dateTime.toUtc().ToInstant().InZone(zone)`. |
| `ZonedDateTime` XML serialization (`AddSchema`, `IXmlSerializable`) | not ported | XML |
| JSON | `ZonedDateTime.toJson()` / `factory ZonedDateTime.fromJson(json, provider, [calendar])` | JSON, as noda-js |
| `DateTimeZoneProviders.Tzdb` | same, over `TzdbDateTimeZoneSource.Default` (the bundled data, decoded on first use) | — |
| `DateTimeZoneProviders.Bcl` | not ported: the system library's provider over `SystemDateTimeZoneSource` | Keeps the core free of platform code |
| `DateTimeZoneProviders.Serialization` | not ported | Obsolete; XML |
| `TzdbDateTimeZoneSource.Default` | same, from `TimeZones/TzdbBundledData.generated.dart` (`nzdBytes`) instead of an assembly resource | No assembly resources |
| `TzdbDateTimeZoneSource.FromStream(Stream)` | `FromBytes(Uint8List)`, `FromBase64(String)` | No `System.IO.Stream` in Dart; as noda-js |
| `TzdbDateTimeZoneSource.Aliases` (`ILookup<string, string>`) | `Map<String, List<String>>` (unmodifiable; null, not empty, for an ID with no aliases) | No `ILookup`; as noda-js |
| `TzdbDateTimeZoneSource.CanonicalIdMap`, `TzdbToWindowsIds`, `WindowsToTzdbIds`, `WindowsZones.PrimaryMapping` | unmodifiable `Map<String, String>` | Read-only dictionaries |
| `TzdbDateTimeZoneSource.GetSystemDefaultId()` | honours `TZ` (Windows or IANA ID, ignoring case; an unknown value → `Etc/UTC`), else the platform's zone | AGENTS.md's TZ rules, as noda-js |
| `TzdbDateTimeZoneSource.MapTimeZoneInfoId(TimeZoneInfo)`, `GuessZoneIdByTransitionsUncached(TimeZoneInfo, ...)` (internal) | take an `IHostTimeZone` | No `TimeZoneInfo` in the core; as noda-js |
| `TzdbDateTimeZoneSource`'s `OrderBy` of zone IDs (current culture) | ordinal order | As noda-js |
| `TzdbZone1970Location.Country` | `TzdbZone1970LocationCountry` | Nested types |
| `TzdbZone1970Location(..., IEnumerable<Country>, ...)` | takes an `Iterable<TzdbZone1970LocationCountry>`; the null-entry check is null safety's | — |
| `ZoneEqualityComparer.Options` | `ZoneEqualityComparerOptions` (generated) | Nested types |
| `ZoneInterval.Contains(LocalInstant)` (internal) | `ContainsLocalInstant` | Overloads |
| `ZoneInterval(string, Instant?, Instant?, Offset, Offset)` | same; the internal constructor is `NewNameStartEndWallOffsetSavings` | Constructors |
| `operator ==`/`!=` on `ZoneInterval`, `Transition`, `MapZone`, `Country` | `operator ==` plus the typed `Equals`; `!=` is Dart's | Dart protocol |
| `DateTimeZoneCache`'s null checks of the source's version ID, IDs and zones (`InvalidDateTimeZoneSourceException`) | dropped | Null safety guarantees them |
| `DateTimeZoneNotFoundException : TimeZoneNotFoundException`, `InvalidDateTimeZoneSourceException` | `implements Exception` | No Dart base type |
| `Resolvers.*` static properties | `static final` function fields | Delegates are function types |
| `ZoneLocalMapping.Single`/`First`/`Last`'s `InvalidOperationException` | `StateError` | Exceptions |
| `TzdbStreamData.Builder`, `DateTimeZoneWriter.ZoneIntervalConstants` (internal) | `TzdbStreamDataBuilder`, `DateTimeZoneWriterZoneIntervalConstants` | Nested types |
| `TzdbStreamData.FromStream` (internal) | kept, plus `FromBytes(Uint8List)` | As noda-js |
| `TzdbStreamData.CreateZone`'s `KeyNotFoundException`; `ReadDictionary`'s duplicate key | `ArgumentError` with .NET's message | Exceptions |
