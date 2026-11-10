# API differences: core (Duration, Instant, Offset, Interval, clocks, NodaConstants, Extensions, Utility)

| C# member | Dart member | Why |
|---|---|---|
| `Duration.FromDays(double)`, `FromHours(double)`, `FromMinutes(double)`, `FromSeconds(double)`, `FromMilliseconds(double)`, `FromTicks(double)`, `FromNanoseconds(double)` | `FromDaysDouble`, `FromHoursDouble`, `FromMinutesDouble`, `FromSecondsDouble`, `FromMillisecondsDouble`, `FromTicksDouble`, `FromNanosecondsDouble` | Overloads: the first declared (`int`/`long`) keeps the name |
| `Duration.FromNanoseconds(BigInteger)`, `FromNanoseconds(Int128)` | `FromNanosecondsBigInteger(BigInt)` | Overload; Dart has no Int128 (BigInt covers it) |
| `Duration.ToBigIntegerNanoseconds()`, `ToInt128Nanoseconds()` | `ToBigIntegerNanoseconds()` (BigInt) | Dart has no Int128 |
| internal `Duration.FromNanoseconds(decimal)`, `ToDecimalNanoseconds()`, `MinDecimalNanoseconds` | `FromDecimalNanoseconds(BigInt)`, `ToDecimalNanoseconds()` (BigInt), `MinDecimalNanoseconds` (BigInt) | Integral decimals are BigInt; decimal overflow/rounding in `Utility/DecimalArithmetic.dart` (noda-js's name) |
| `Duration operator /(Duration, long)` | `operator /(int)` | First declared `/` overload |
| `Duration operator /(Duration, double)`, `Divide(Duration, double)` | `Duration.DivideDouble(Duration, double)` | Dart has one `/` per class |
| `Duration operator /(Duration, Duration)`, `Divide(Duration, Duration)` | `Duration.DivideDuration(Duration, Duration)` | Dart has one `/` per class |
| `Duration operator *(Duration, long)` | `operator *(int)` | The exact overload, so `d * intVariable` compiles |
| `Duration operator *(Duration, double)`, `Multiply(Duration, double)` | `Duration.MultiplyDouble(Duration, double)` | Dart has one `*` per class |
| `operator *(long, Duration)`, `Multiply(long, Duration)` | `Duration.MultiplyInt64Duration(int, Duration)` | Dart operators belong to the left operand |
| `operator *(double, Duration)`, `Multiply(double, Duration)` | `Duration.MultiplyDoubleDuration(double, Duration)` | Dart operators belong to the left operand |
| `Duration`/`Offset` unary `operator +` | not ported | Dart has no unary `+` |
| `Duration.FromTimeSpan(TimeSpan)`, `ToTimeSpan()` | `FromCoreDuration(core.Duration)`, `ToCoreDuration()` | Dart's Duration counts microseconds: `ToCoreDuration` truncates towards zero and throws `OverflowException` beyond `TimeSpan`'s range; `FromCoreDuration` throws `RangeError` beyond ±2^24 days. |
| `Offset.FromTimeSpan(TimeSpan)`, `ToTimeSpan()` | `FromCoreDuration(core.Duration)`, `ToCoreDuration()` | As above; `FromCoreDuration` truncates to seconds, `RangeError` beyond ±18 hours. |
| `Instant operator -(Instant, Duration)`, `Minus(Duration)` | `Instant.MinusDuration(Duration)` | `operator -` and `Minus` take C#'s first declared overload (`Instant - Instant`) |
| `Instant.Subtract(Instant, Duration)` | `Instant.SubtractDuration(Instant, Duration)` | Overload; `Subtract(Instant, Instant)` is declared first |
| internal `Instant.Plus(Offset)` → `LocalInstant` | `Instant.PlusOffset(Offset)` (`@internal`) | Overload; the public `Plus(Duration)` keeps the name |
| `Instant.FromUtc(5 args)`, `FromUtc(6 args)` | `FromUtc(..., [int secondOfMinute = 0])` | Prefix chain |
| `Instant.InZone(zone)`, `InZone(zone, calendar)`; `WithOffset(offset)`, `WithOffset(offset, calendar)` | `InZone(zone, [calendar])`, `WithOffset(offset, [calendar])` | Prefix chains |
| `Instant.ToUnixTimeSecondsAndNanoseconds()` → `(long seconds, int nanoseconds)` | `({int seconds, int nanoseconds})` | Named record |
| `Instant.ToDateTimeUtc()`, `FromDateTimeUtc(DateTime)` | `ToDateTimeUtc()` → `core.DateTime` (UTC), `FromDateTimeUtc(core.DateTime)` (must be `isUtc`) | A local `DateTime` throws `ArgumentError` (use `.toUtc()`). `ToDateTimeUtc` truncates to the microsecond and throws `StateError` before 0001-01-01; `FromDateTimeUtc` accepts years -9998 to 9999. |
| `Instant.ToDateTimeOffset()` | not ported | No `DateTimeOffset`; use `ToDateTimeUtc()`. |
| `Instant.FromDateTimeOffset(DateTimeOffset)` | not ported | No `DateTimeOffset`; use `Instant.FromDateTimeUtc(dateTime.toUtc())`. |
| `ToString(string?, IFormatProvider?)` (Duration, Instant, Offset) | `ToStringPattern(String?, [IFormatProvider?])`; `toString()` uses the invariant culture | Dart's `toString` takes no parameters |
| `IComparable<T>.CompareTo` / `IComparable.CompareTo(object)` | `compareTo(T)` / `CompareTo(Object?)` | Dart's Comparable |
| `Interval(Instant, Instant)`, `Interval(Instant?, Instant?)` | `Interval(Instant?, Instant?)` | One constructor |
| `Interval.Deconstruct(out, out)` | `(Instant?, Instant?) get Deconstruct` | Records |
| JSON (Interval) | `Map<String, String> toJson()` / `Interval.fromJson(Map<String, Object?>)` (camelCase `start`/`end`, read case-insensitively) | An object in NodaTime.Serialization, as noda-js |
| JSON (Duration, Instant, Offset) | `toJson()` / `fromJson(String)` with `DurationPattern.JsonRoundtrip`, `InstantPattern.ExtendedIso`, `OffsetPattern.GeneralInvariant` | Conventions |
| `ClockExtensions.InZone(clock, zone)`, `InZone(clock, zone, calendar)` | `clock.InZone(zone, [calendar])` | Prefix chain |
| `ClockExtensions.InBclSystemDefaultZone` | not ported | `DateTimeZoneProviders.Bcl` is the system library |
| `TimeSpanExtensions` (on TimeSpan) | `extension TimeSpanExtensions on core.Duration` | BCL interop |
| `DateTimeExtensions` (on DateTime) | `extension DateTimeExtensions on core.DateTime` | BCL interop |
| `StopwatchExtensions` (on Stopwatch) | `extension StopwatchExtensions on core.Stopwatch` (`ElapsedDuration()`) | BCL interop: Dart's `Stopwatch.elapsed` is a Dart `Duration` (microseconds) |
| `DateTimeOffsetExtensions` (`ToOffsetDateTime`, `ToZonedDateTime`, `ToInstant`) | not ported | No `DateTimeOffset`; use `dateTime.toUtc().ToInstant().WithOffset(Offset.FromCoreDuration(dateTime.timeZoneOffset))`. |
| `DateOnlyExtensions`, `TimeOnlyExtensions`, `TimeProviderExtensions` | not ported | No Dart types |
| `DayOfWeekExtensions` | not ported | Dart has no DayOfWeek type (an extension on `int` would pollute every int) |
| `IsoDayOfWeekExtensions.ToDayOfWeek()`, `BclConversions.ToDayOfWeek/ToIsoDayOfWeek` | return / take `int` (0 = Sunday … 6 = Saturday) | Dart has no DayOfWeek type |
| `IXmlSerializable`, `AddSchema`, `TypeConverter` | not ported | Conventions |
| internal `HashCodeHelper.Hash(t1, t2)`, `Hash(t1, t2, t3)` | `HashCodeHelper.HashStatic(t1, t2, [t3])` | Static/instance name clash with the instance `Hash` |
| internal `Preconditions.CheckArgumentRange(string, double, double, double)` | `CheckArgumentRangeDouble` | int and long overloads are one (`int`); double is distinct |
| internal `Preconditions.CheckArgument` (0, 1 or 2 message args) | `CheckArgument(expr, param, message, [arg1, arg2])` | Prefix chain |
| `ArgumentOutOfRangeException(param, message)` without a numeric value | `RangeError("message (Parameter 'param')")` | Dart's RangeError only records numeric values |
