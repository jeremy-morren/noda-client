# API differences: Period, PeriodBuilder, OffsetDate, OffsetTime, OffsetDateTime

| C# (NodaTime) | Dart (noda_dart) | Why |
|---|---|---|
| `Period.Between(LocalDateTime, LocalDateTime, PeriodUnits)` / `Between(LocalDateTime, LocalDateTime)` | `Period.Between(start, end, [units = PeriodUnits.DateAndTime])` | Prefix chain → optional parameter. |
| `Period.Between(LocalDate, LocalDate, PeriodUnits)` / `Between(LocalDate, LocalDate)` | `Period.BetweenLocalDate(start, end, [units = PeriodUnits.YearMonthDay])` | Overload: name + parameter type. |
| `Period.Between(LocalTime, LocalTime, PeriodUnits)` / `Between(LocalTime, LocalTime)` | `Period.BetweenLocalTime(start, end, [units = PeriodUnits.AllTimeUnits])` | Overload: name + parameter type. |
| `Period.Between(YearMonth, YearMonth, PeriodUnits)` / `Between(YearMonth, YearMonth)` | `Period.BetweenYearMonth(start, end, [PeriodUnits? units])` (null → `Years \| Months`) | Overload; defaults must be constant. |
| `static Period operator +(Period, Period)`, binary/unary `operator -` | `Period operator +(Period)`, `operator -(Period)`, `operator -()` | Dart operators are instance members. |
| `static Period operator +(Period)` (unary plus) | not ported | Dart has no unary `+`. |
| `Period.NormalizingEqualityComparer` / `CreateComparer` | return `IEqualityComparer<Period?>` / `IComparer<Period?>` (`Utility/Comparers.dart`) | .NET's comparer interfaces. |
| `Period.Equals(object)`, `==`, `!=`, `GetHashCode()` | `operator ==`, `hashCode` (typed `Equals(Period?)` kept) | Dart protocol. |
| (none) | `Period.toJson()`, `Period.fromJson(String)` | JSON (`PeriodPattern.Roundtrip`, as NodaTime.Serialization.SystemTextJson). |
| `PeriodBuilder()` / `PeriodBuilder(Period)` | `PeriodBuilder([Period? period])` | Prefix chain. |
| `PeriodBuilder.this[PeriodUnits]` (get/set) | `operator [](PeriodUnits)`, `operator []=(PeriodUnits, int)` | Indexer. |
| `PeriodBuilder` `IXmlSerializable`, `AddSchema`; same on `OffsetDate`, `OffsetTime`, `OffsetDateTime` | not ported | XML serialization. |
| `OffsetDate/OffsetTime/OffsetDateTime.ToString()` | `toString()` with the invariant culture | NodaTime uses the current culture. |
| `ToString(string?, IFormatProvider?)` | `ToStringPattern(String? patternText, [IFormatProvider? formatProvider])` | Dart's `toString` takes no parameters. |
| `OffsetDate.Deconstruct(out LocalDate, out Offset)` | `(LocalDate, Offset) get Deconstruct` | `out` → record. |
| `OffsetTime.Deconstruct(out LocalTime, out Offset)` | `(LocalTime, Offset) get Deconstruct` | `out` → record. |
| `OffsetDateTime.Deconstruct(out LocalDateTime, out Offset)` | `(LocalDateTime, Offset) get Deconstruct` | `out` → record. |
| `OffsetDateTime.Deconstruct(out LocalDate, out LocalTime, out Offset)` | `(LocalDate, LocalTime, Offset) get DeconstructLocalDateLocalTimeOffset` | Overload: name + parameter types. |
| `OffsetDateTime.With(Func<LocalTime, LocalTime>)` | `WithTimeAdjuster(LocalTime Function(LocalTime))` | Overload; noda-js's name. |
| `OffsetDateTime operator -(OffsetDateTime, OffsetDateTime)` | `MinusOffsetDateTime(OffsetDateTime)` (no operator) | Dart's `-` takes the first declared overload, `- Duration`. |
| `OffsetDateTime.Minus(OffsetDateTime)` | `MinusOffsetDateTime(OffsetDateTime)` | Overload: name + parameter type. |
| `OffsetDateTime.Subtract(OffsetDateTime, OffsetDateTime)` | `OffsetDateTime.SubtractOffsetDateTime(end, start)` | Overload: name + parameter type. |
| `OffsetDateTime.ToDateTimeOffset()`, `FromDateTimeOffset(DateTimeOffset)` | not ported | No `DateTimeOffset`; use `dateTime.toUtc().ToInstant().WithOffset(Offset.FromCoreDuration(dateTime.timeZoneOffset))`. |
| (none) | `OffsetDateTime.ToDateTimeUtc()` → `core.DateTime` (UTC) | Stand-in for `ToDateTimeOffset()`: the same instant, without the offset. |
| `OffsetDateTime.Comparer` (`Local`, `Instant`) | `OffsetDateTimeComparer` (`Local`, `Instant`) | Nested type → `OuterInner`. |
| (none) | `toJson()`, `fromJson(String json, [CalendarSystem? calendar])` on `OffsetDate` (`GeneralIso`), `OffsetTime` (`ExtendedIso`), `OffsetDateTime` (`Rfc3339`) | JSON, as NodaTime.Serialization.SystemTextJson; the calendar isn't in the JSON. |
