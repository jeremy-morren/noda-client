# API differences: LocalDate, LocalTime, LocalDateTime, YearMonth, AnnualDate, DateAdjusters, TimeAdjusters, DateInterval

| C# (NodaTime) | Dart (noda_dart) | Why |
|---|---|---|
| `LocalDate(int, int, int)` / `LocalDate(int, int, int, CalendarSystem)` | `LocalDate(year, month, day, [CalendarSystem? calendar])` | Prefix chain → optional parameter (null → ISO). |
| `LocalDate(Era, int, int, int)` / `(Era, int, int, int, CalendarSystem)` | `LocalDate.EraYearOfEraMonthDay(era, yearOfEra, month, day, [CalendarSystem? calendar])` | Other constructor overload: named for its parameters. |
| `YearMonth(int, int)` / `YearMonth(int, int, CalendarSystem)` | `YearMonth(year, month, [CalendarSystem? calendar])` | Prefix chain. |
| `YearMonth(Era, int, int)` / `(Era, int, int, CalendarSystem)` | `YearMonth.EraYearOfEraMonth(era, yearOfEra, month, [CalendarSystem? calendar])` | Other constructor overload. |
| `LocalTime(int, int)`, `(int, int, int)`, `(int, int, int, int)` | `LocalTime(hour, minute, [second = 0, millisecond = 0])` | Prefix chain. |
| `LocalDateTime(y, m, d, h, min)`, `(..., s)`, `(..., s, ms)`, `(..., s, ms, CalendarSystem)` | `LocalDateTime(year, month, day, hour, minute, [second = 0, millisecond = 0, CalendarSystem? calendar])` | Prefix chain. |
| `LocalDateTime(y, m, d, h, min, CalendarSystem)` | `LocalDateTime.YearMonthDayHourMinuteCalendar(...)` | Other constructor overload. |
| `LocalDateTime(y, m, d, h, min, s, CalendarSystem)` | `LocalDateTime.YearMonthDayHourMinuteSecondCalendar(...)` | Other constructor overload. |
| `static LocalDate operator +(LocalDate, Period)`, `operator -(LocalDate, Period)`; same on `LocalTime`, `LocalDateTime` | `operator +(Period)`, `operator -(Period)` | Dart operators are instance members. |
| `LocalDate operator +(LocalDate, LocalTime)` | `LocalDate.At(LocalTime)` (no operator) | Dart's `+` takes the first declared overload (`+ Period`). |
| `Period operator -(LocalDate, LocalDate)`; `LocalDate.Subtract(LocalDate, LocalDate)`; `LocalDate.Minus(LocalDate)` | `LocalDate.SubtractLocalDate(lhs, rhs)`, `MinusLocalDate(LocalDate)` (no operator) | Dart's `-` takes `- Period`; overload: name + parameter type. |
| `Period operator -(LocalTime, LocalTime)`; `LocalTime.Subtract(LocalTime, LocalTime)`; `Minus(LocalTime)` | `LocalTime.SubtractLocalTime(lhs, rhs)`, `MinusLocalTime(LocalTime)` | As above. |
| `Period operator -(LocalDateTime, LocalDateTime)`; `Subtract(LocalDateTime, LocalDateTime)`; `Minus(LocalDateTime)` | `LocalDateTime.SubtractLocalDateTime(lhs, rhs)`, `MinusLocalDateTime(LocalDateTime)` | As above. |
| `LocalDateTime.With(Func<LocalTime, LocalTime>)` | `WithTimeAdjuster(LocalTime Function(LocalTime))` | Overload; noda-js's name. |
| `DateInterval.Contains(DateInterval)` | `ContainsDateInterval(DateInterval)` | Overload: name + parameter type. |
| `==`, `!=`, `Equals(object)`, `GetHashCode()` (all types) | `operator ==`, `hashCode` (typed `Equals(T)` kept) | Dart protocol. |
| `IComparable<T>.CompareTo(T)` | `compareTo(T)` (`Comparable<T>`) | Dart protocol. |
| `IComparable.CompareTo(object)` (explicit) on `LocalDate`, `LocalTime`, `LocalDateTime`, `YearMonth`, `AnnualDate` | `int CompareTo(Object? obj)` | Public in Dart (no explicit interface implementation). |
| `ToString()` | `toString()` with the invariant culture | NodaTime uses the current culture; Dart has none. |
| `ToString(string?, IFormatProvider?)` | `ToStringPattern(String? patternText, [IFormatProvider? formatProvider])` | Dart's `toString` takes no parameters. |
| `LocalDate.Deconstruct(out int, out int, out int)` | `(int, int, int) get Deconstruct` | `out` → record. |
| `LocalDate.Deconstruct(out int, out int, out int, out CalendarSystem)` | `(int, int, int, CalendarSystem) get DeconstructCalendarSystem` | Overload: name + parameter type. |
| `LocalTime.Deconstruct(out int, out int, out int)` | `(int, int, int) get Deconstruct` | `out` → record. |
| `LocalDateTime.Deconstruct(out LocalDate, out LocalTime)`, `DateInterval.Deconstruct(out LocalDate, out LocalDate)` | `get Deconstruct` (records) | `out` → record. |
| `LocalDate.ToDateTimeUnspecified()`, `LocalDateTime.ToDateTimeUnspecified()` | return a local `core.DateTime` (`isUtc` false) with the same ISO date and time of day, truncated to the microsecond | Dart has no unspecified kind (a skipped local time moves forward). Before 0001-01-01: `StateError` (`LocalDateTime`), `RangeError` (`LocalDate`). |
| `LocalDate.FromDateTime(DateTime)` / `(DateTime, CalendarSystem)`; same on `LocalDateTime` | `FromDateTime(core.DateTime dateTime, [CalendarSystem? calendar])` | Prefix chain. Uses the `DateTime`'s fields; validated (Dart's range is wider). |
| `LocalDate.ToDateOnly()`, `FromDateOnly(DateOnly)`; `LocalTime.ToTimeOnly()`, `FromTimeOnly(TimeOnly)` | not ported | Dart has no `DateOnly`/`TimeOnly`. |
| `IXmlSerializable`, `AddSchema`, `[TypeConverter]` (all types) | not ported | XML serialization / type converters. |
| `DateAdjusters`, `TimeAdjusters` properties (`Func<LocalDate, LocalDate>`) | `static final LocalDate Function(LocalDate)` fields | Function types. |
| `DateInterval : IEnumerable<LocalDate>` | `DateInterval extends Iterable<LocalDate>` (`iterator`) | Dart protocol. |
| (none) | `toJson()`, `fromJson(String json, [CalendarSystem? calendar])` on `LocalDate` (`Iso`), `LocalTime` (`ExtendedIso`, no calendar), `LocalDateTime` (`ExtendedIso`), `YearMonth` (`Iso`), `AnnualDate` (`Iso`, no calendar) | JSON, as NodaTime.Serialization.SystemTextJson; the calendar isn't in the JSON. |
| (none) | `DateInterval.toJson()` → `{"start": ..., "end": ...}`; `DateInterval.fromJson(Map<String, Object?> json, [CalendarSystem? calendar])` (property names matched case-insensitively) | JSON, as noda-js (camelCase, as ASP.NET Core's default naming policy). |
