# API differences from NodaTime

noda-js follows NodaTime's public API with the mechanical changes in
[porting-conventions.md](porting-conventions.md).

**Names are the same as NodaTime's, PascalCase included**: types, methods, properties and enum members are
spelled exactly as in C# (`LocalDate.PlusDays`, `Duration.TotalSeconds`, `CalendarSystem.Iso`), so NodaTime code
and documentation carry over as written. The only camelCase members are the ones JavaScript itself calls by name:
`toString()`, `toJSON()`, `static fromJSON()`, `valueOf()` and `[Symbol.iterator]`; C# indexers are `get(...)` /
`set(...)`. Properties are getters, operators are named static methods (`Duration.Add`, `Instant.Subtract`), and
`Exception`s are `Error`s. This page lists everything else. The API test
(`test/api/api.test.ts`) checks the API shape against NodaTime by reflection, and its exceptions live
in `test/api/differences.ts`.

## Not ported

| Area | Reason / replacement |
|---|---|
| Non-ISO calendars other than Gregorian, Julian and Coptic (`CalendarSystem.Hebrew*`, `Islamic*`, `Persian*`, `UmAlQura`, `Badi`, `GetHebrewCalendar`, `GetIslamicCalendar`, their `Era`s and enums) | Not ported. `CalendarSystem`, `WithCalendar`, `Era` exist with the ISO, Gregorian, Julian and Coptic calendars (`CalendarSystem.Iso`, `Gregorian`, `Julian`, `Coptic`; `Era.AnnoMartyrum`). |
| `BclDateTimeZone`, `BclDateTimeZoneSource`, `DateTimeZoneProviders.Bcl` | There is no `TimeZoneInfo` in JS, and Windows' zone rules have no redistributable source. Windows zone **IDs** are supported via `noda-js/windows` (CLDR mapping to tzdb zones). `noda-js/browser` provides zones from `Intl`. |
| `DateTimeZoneProviders` (static registry) | No global registry (tree shaking). Import a ready provider: `tzdb` from `noda-js/tzdb/bundled`, `browser` from `noda-js/browser`. |
| BCL interop: `DateTime`, `DateTimeOffset`, `TimeSpan`, `DateOnly`, `TimeOnly`, `TimeProvider`, `Stopwatch`, `System.DayOfWeek` members and extension classes | Replaced by JS `Date` interop: `Instant.FromJsDate(date)`, `instant.ToJsDate()` (millisecond precision). |
| `ClockExtensions.InTzdbSystemDefaultZone`, `InBclSystemDefaultZone` | Core can't depend on tzdb; use `InZone(clock, tzdb.GetSystemDefault())`. |
| `XPattern.CreateWithCurrentCulture`, `NodaFormatInfo.CurrentInfo` | JS has no current culture. Pass a culture explicitly (`import { enAU } from "noda-js/cultures"`). |
| `ToString()` using the current culture | `toString()` uses the invariant culture; `toString(pattern, culture)` for anything else. |
| XML serialization, `TypeConverter`s, `HighPerformance` (`Instant64`, `Duration64`), `GetHashCode`, `Deconstruct` | .NET-specific. |
| `Duration.ToBigIntegerNanoseconds()`, `ToInt128Nanoseconds()`, `FromNanoseconds(BigInteger)`, `FromNanoseconds(Int128)` | No `BigInt` (the runtime baseline is ES2015). Within the `long` range, `ToInt64Nanoseconds()` and `FromNanoseconds("<decimal string>")` cover them; `TotalNanoseconds` gives the nearest double for any duration. |

## Changed

| NodaTime | noda-js | Why |
|---|---|---|
| Indexer `PeriodBuilder[PeriodUnits]` | `builder.get(unit)` / `builder.set(unit, value)` | No indexers in JS. |
| Indexer `IDateTimeZoneProvider[string]` | `provider.get(id)` | No indexers in JS. |
| `LocalDateTime.With(Func<LocalTime, LocalTime>)`, `OffsetDateTime.With(Func<LocalTime, LocalTime>)` | `WithTimeAdjuster(fn)` | Can't be told apart at runtime from `With(Func<LocalDate, LocalDate>)`, which keeps the name `With`. |
| `Instant.ToUnixTimeSecondsAndNanoseconds()` (tuple) | returns `{ seconds, nanoseconds }` | No tuples in JS. |
| C# `long` results that can exceed 2⁵³: `Duration.BclCompatibleTicks`, `ToInt64Nanoseconds()`, `Instant.ToUnixTimeTicks()` | `number`: exact up to 2⁵³, the nearest double beyond (the value is computed exactly, so overflow still throws `OverflowError` where C# does) | No `BigInt` in ES2015. |
| C# `long` arguments (`Duration.FromTicks`, `FromNanoseconds`, `Instant.FromUnixTimeTicks`, `PlusTicks`, `PlusNanoseconds`, `Period.FromHours` … `FromNanoseconds`, `PeriodBuilder` setters, `LocalTime.FromNanosecondsSinceMidnight`, `Offset.FromTicks`, ...) | accept `number \| string`: a safe integer, or a decimal string for an exact value anywhere in the `long` range (`Duration.FromNanoseconds("9223372036854775807")`). A string that isn't a decimal integer throws `FormatError`; one outside the `long` range throws `OverflowError`. | No `BigInt` in ES2015. |
| Overloads `Duration.FromDays(int)` / `FromDays(double)` etc. | one method; an integer argument takes the integer path, otherwise the `double` path | JS has one number type. `Duration.Divide(d, 2)` truncates like C# `d / 2L`. |
| `Period`'s `long` fields (hours … nanoseconds) | `number`; exact up to 2⁵³ | Values are stored exactly (as a 64-bit `Long` only beyond 2⁵³) and arithmetic is exact and checked, so overflow throws and formatting, parsing (`PT9223372036854775807H`), JSON and equality match C#, but the getters read values beyond 2⁵³ back as the nearest number (e.g. `Period.MaxValue.Hours` is 2⁶³). |
| `DateTimeZone.Equals` (reference equality from `object`) | `Equals(other)` | Explicit in JS; `FixedDateTimeZone` overrides it as NodaTime does. |
| `Equals(T)` and `Equals(object)`; `CompareTo(T)` and the explicit `IComparable.CompareTo(object)` | one `Equals(other)` / `CompareTo(other)` each, with a typed overload and an `unknown` one. `Equals` is false for anything that isn't the same type (never throws); `CompareTo` is positive for `null`/`undefined` and throws `ArgumentError` (C#'s message) for anything else. The built-in comparers (`OffsetDateTime.Comparer`, `ZonedDateTime.Comparer`, `Period.NormalizingEqualityComparer`, `Period.CreateComparer`, `ZoneEqualityComparer`) likewise return `false` from `Equals` and throw `ArgumentError` from `Compare` for a value of the wrong type. | JS can't overload on static types; C# accepts the `object` overloads too. |
| Error messages that print flag enums (`PeriodUnits`, `ZoneEqualityComparer.Options`) | print the numeric value | TS enums have no flag-name formatting. |
| Read-only collections (`TzdbDateTimeZoneSource.CanonicalIdMap`, `Aliases`, `ZoneLocations`, `WindowsZones.PrimaryMapping`, `MapZone.TzdbIds`, ...) | `ReadonlyMap` / `readonly T[]` that are also read-only at runtime: map mutators throw `NotSupportedError` (as .NET's `ReadOnlyDictionary` does); arrays are frozen, so mutating them throws a `TypeError` | |
| `System.DivideByZeroException` | `DivideByZeroError` (extends `RangeError`) | |
| `System.Globalization.CultureInfo` | `NodaCultureInfo` (`NodaCultureInfo.InvariantCulture`; the other cultures come from `noda-js/cultures`) | Holds only the data NodaTime reads, and the prefix keeps a generic BCL name out of app code and auto-imports. |

## Added

| Member | What |
|---|---|
| `toJSON()` / `static fromJSON()` on every value type | NodaTime.Serialization.SystemTextJson's formats. `Interval`/`DateInterval` write camelCase `start`/`end` and accept either case. `ZonedDateTime.fromJSON` and `DateTimeZone.fromJSON` take a provider. JSON doesn't record the calendar system, so `fromJSON` on `LocalDate`, `LocalDateTime`, `OffsetDate`, `OffsetDateTime`, `YearMonth`, `ZonedDateTime` and `DateInterval` takes an optional `calendar` (ISO if omitted), matching NodaTime converters built from a pattern with `WithCalendar`. A provider wrapped in `WindowsIdDateTimeZoneProvider` (`noda-js/windows`) reads the Windows zone IDs that .NET's `BclDateTimeZone` writes. |
| `valueOf()` on value types | Throws `TypeError`, so `a < b` fails loudly. Use `CompareTo`/`Equals`. |
| `TzdbDateTimeZoneSource.FromBytes(Uint8Array)`, `FromBase64(text)` | Load NZD data (e.g. fetched from nodatime.org at runtime). |
| `DateInterval[Symbol.iterator]` | C#'s `IEnumerable<LocalDate>`. |
| `noda-js/windows`: `WindowsIdDateTimeZoneProvider`, `GetCldrWindowsZones()` | Accept Windows zone IDs, mapped to tzdb zones. |
