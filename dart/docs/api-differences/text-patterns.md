# API differences: type-specific text patterns (`lib/src/Text/*Pattern.dart`, `*PatternParser.dart`)

Covers `AnnualDatePattern`, `DurationPattern`, `InstantPattern`, `LocalDatePattern`, `LocalDateTimePattern`,
`LocalTimePattern`, `OffsetDatePattern`, `OffsetDateTimePattern`, `OffsetPattern`, `OffsetTimePattern`, `PeriodPattern`,
`YearMonthPattern`, `ZonedDateTimePattern` and their parsers.

| C# (NodaTime) | Dart (noda_dart) | Why |
|---|---|---|
| `XPattern.Create(string, CultureInfo)` / `Create(string, CultureInfo, X templateValue)` (Annual date, local date, local date/time, local time, year/month) | `XPattern.Create(patternText, NodaCultureInfo cultureInfo, [X? templateValue])` | Prefix chain → optional parameter (null → the default template value). |
| `XPattern.Create(string, CultureInfo, ...)` (Duration, Instant, Offset, OffsetDate, OffsetDateTime, OffsetTime, ZonedDateTime) | `XPattern.Create(patternText, NodaCultureInfo cultureInfo, ...)` | `CultureInfo` is noda_dart's `NodaCultureInfo` (as in noda-js). |
| internal `XPattern.Create(string, NodaFormatInfo, ...)` | `@internal XPattern.CreateNodaFormatInfo(...)` (private in C# → `_CreateNodaFormatInfo`) | Overload: name + parameter type. The public overload keeps `Create`, as in NodaTime's public API. |
| `IPattern<T>.AppendFormat(T, StringBuilder)` | `StringBuffer AppendFormat(T value, StringBuffer builder)` | `StringBuilder` → Dart's `StringBuffer`. |
| `XPattern.Patterns` (nested static class) | `XPatternPatterns` (`@internal`; `_XPatternPatterns` where C#'s is private) | Dart has no nested types. |
| `XPatternParser.XParseBucket` (nested class) | `XPatternParserXParseBucket` (`@internal`; `_...` where C#'s is private) | Dart has no nested types. |
| `LocalDateParseBucket.CalculateValue(usedFields, text)` / `CalculateValue(usedFields, text, Type)` (same on `LocalTimeParseBucket`) | `CalculateValue(usedFields, text, [Type eventualResultType = LocalDate])` | Overloads that differ by a trailing parameter → one method with an optional parameter. |
| `LocalTimeParseBucket.DetermineHour(..., out int hour, ...)` | returns `(ParseResult<LocalTime>?, int)` | `out` parameter → record. |
| `[Immutable]`, `[DebuggerStepThrough]` | comments | Attributes have no Dart equivalent. |
| `Parse([SpecialNullHandling] string text)` → `ParseResult.ArgumentNull` for `null` (`PeriodPattern`) | `Parse(String text)` | Null safety: `text` can't be null. |
