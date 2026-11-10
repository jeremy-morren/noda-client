# API differences from NodaTime

Names are NodaTime's, PascalCase included, with the mechanical changes in
[porting-conventions.md](porting-conventions.md): properties are getters, operators are named statics
(`Duration.Add`), indexers are `Get`/`Set`, exceptions are `NodaError`s, and JS protocol members are camelCase
(`toString`, `toJSON`/`fromJSON`, `valueOf`, `[Symbol.iterator]`). Everything else is below.
`test/api/api.test.ts` checks the API against NodaTime by reflection; its exceptions are in `test/api/differences.ts`.

## Not ported

| Area | Instead |
|---|---|
| `CalendarSystem.HebrewCivil`, `HebrewScriptural`, `GetHebrewCalendar`, `GetIslamicCalendar`, `IslamicBcl`, `PersianSimple`, `PersianArithmetic`, `PersianAstronomical`, `UmAlQura`, `Badi` | Same names from `noda-js/calendars/hebrew` (`/islamic`, `/persian`, `/umalqura`, `/badi`, `/all`), for tree shaking. Importing one registers it for `CalendarSystem.ForId` / `Ids`; `ForId` of an unloaded one throws `NotSupportedException`. |
| `DateTimeZoneProviders` | Import a provider: `tzdb` (`noda-js/tzdb/bundled`), `SystemDateTimeZoneProvider` (`noda-js/system`). |
| `BclDateTimeZone` on Unix (`FromUnixAdjustmentRule`, `FixUnixTransitions`, `AreWindowsStyleRules`) | `TimeZoneInfo` data is read only on Windows; elsewhere `Intl` ([Timezones.md](Timezones.md)). |
| BCL interop (`DateTime`, `DateTimeOffset`, `TimeSpan`, `DateOnly`, `TimeOnly`, `TimeProvider`, `Stopwatch`, `System.DayOfWeek`) | `Instant.FromJsDate(date)`, `instant.ToJsDate()` (millisecond precision). |
| `ClockExtensions.InTzdbSystemDefaultZone`, `InBclSystemDefaultZone` | `InZone(clock, tzdb.GetSystemDefault())`. |
| `XPattern.CreateWithCurrentCulture`, `NodaFormatInfo.CurrentInfo` | Pass a culture: from `noda-js/cultures`, or `NodaCultureInfo.CurrentCulture`. |
| `ToString()` with the current culture | `toString()` uses the invariant culture. |
| XML serialization, `TypeConverter`s, `HighPerformance`, `GetHashCode`, `Deconstruct` | .NET-specific. |
| `Duration.ToBigIntegerNanoseconds()`, `ToInt128Nanoseconds()`, `FromNanoseconds(BigInteger / Int128)` | `ToInt64Nanoseconds()`, `FromNanoseconds("<decimal string>")`, `TotalNanoseconds`. |

## Changed

| NodaTime | noda-js |
|---|---|
| `BclDateTimeZoneSource`, `BclDateTimeZone`, `DateTimeZoneProviders.Bcl` | `SystemDateTimeZoneSource`, `SystemDateTimeZone`, `SystemDateTimeZoneProvider` (`noda-js/system`): Windows' zones as on .NET (FFI or addon), else `Intl`'s. `VersionId` names the backend; `TZ` is honoured everywhere. See [Timezones.md](Timezones.md). |
| `TzdbDateTimeZoneSource.GetSystemDefaultId` | `TZ`'s zone, else `Intl`'s, guessing with `Date`'s offsets. See [Timezones.md](Timezones.md#the-system-default-zone). |
| Indexers `PeriodBuilder[PeriodUnits]`, `IDateTimeZoneProvider[string]` | `builder.Get(unit)` / `Set(unit, value)`, `provider.Get(id)` |
| `LocalDateTime.With(Func<LocalTime, LocalTime>)`, `OffsetDateTime.With(...)` | `WithTimeAdjuster(fn)` (indistinguishable at run time from the `LocalDate` overload). |
| `Instant.ToUnixTimeSecondsAndNanoseconds()` (tuple) | `{ seconds, nanoseconds }` |
| `long` results that can exceed 2⁵³ (`BclCompatibleTicks`, `ToInt64Nanoseconds()`, `ToUnixTimeTicks()`) | `number`: the nearest double beyond 2⁵³ (computed exactly, so overflow still throws). |
| `long` arguments (`Duration.FromTicks`, `FromNanoseconds`, `Instant.FromUnixTimeTicks`, `Period.FromHours`…, `PeriodBuilder` setters, ...) | `number \| string`: a decimal string is exact over the whole `long` range. Not a decimal integer → `FormatException`; out of range → `OverflowException`. |
| Overloads `FromDays(int)` / `FromDays(double)` etc. | One method: integers take the integer path. `Duration.Divide(d, 2)` truncates like `d / 2L`. |
| `Period`'s `long` fields | Stored and computed exactly; getters return the nearest `number` beyond 2⁵³ (`Period.MaxValue.Hours` is 2⁶³). |
| `Equals(T)` + `Equals(object)`; `CompareTo(T)` + `CompareTo(object)` | One `Equals` / `CompareTo` each. `Equals` is false for other types; `CompareTo(null)` is positive; another type throws `ArgumentException`. Built-in comparers behave the same. |
| `DateTimeZone.Equals` | `Equals(other)` (reference equality; `FixedDateTimeZone` overrides it). |
| Error messages printing flag enums | Print the numeric value. |
| Read-only collections (`CanonicalIdMap`, `Aliases`, `ZoneLocations`, `PrimaryMapping`, `TzdbIds`, ...) | `ReadonlyMap` (mutators throw `NotSupportedException`) / frozen `readonly T[]`. |
| .NET exceptions | `NodaError`s: `Codes` is the type then its bases (`["SkippedTimeException", "ArgumentOutOfRangeException", "ArgumentException", "SystemException"]`). Check with `IsNodaError(e, "ArgumentException")`, which matches derived types. NodaTime's own exceptions are classes. |
| `System.Globalization.CultureInfo` | `NodaCultureInfo` (`InvariantCulture`; others from `noda-js/cultures`). |

## Added

| Member | What |
|---|---|
| `toJSON()` / `static fromJSON()` | NodaTime.Serialization.SystemTextJson's formats. Intervals write camelCase and read either case. `ZonedDateTime.fromJSON` / `DateTimeZone.fromJSON` take a provider. Types with a calendar take an optional `calendar` (ISO by default). |
| `NodaCultureInfo.CurrentCulture`, `Register(...cultures)` | The registered culture best matching the host's languages (throws `InvalidOperationException` if none). `noda-js/cultures` exports register themselves when used. |
| `noda-js/cultures/all` | Bundles and registers every culture. |
| `valueOf()` | Throws `TypeError`, so `a < b` fails loudly. |
| `TzdbDateTimeZoneSource.FromBytes(Uint8Array)`, `FromBase64(text)` | Load NZD data. |
| `DateInterval[Symbol.iterator]` | C#'s `IEnumerable<LocalDate>`. |
| `noda-js/windows`: `WindowsIdDateTimeZoneProvider`, `GetCldrWindowsZones()` | Windows IDs mapped to tzdb zones. |
| `noda-js/tzdb/compiler`: `CompileTzdb`, `CompileTzdbToNzd`, `CompileTzdbSync`, `CompileTzdbToNzdSync` | NodaTime.TzdbCompiler as functions: an IANA `.tar.gz`/`.tar` (URL, bytes, `Blob`; async also `Request`, `Response`, streams) → a validated source, or NodaTime's NZD bytes. Options: `WindowsZones` (`-w`), `Log`. Not supported: single-zone and XML output, `.tar.lz`. |
