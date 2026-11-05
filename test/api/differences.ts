// Deliberate differences between NodaTime's public API and noda-js, used by api.test.ts.
// Keep in sync with docs/api-differences.md.

/** Types ("Type") and members ("Type.CSharpMember") that aren't ported, with the reason. */
export const notPorted: Readonly<Record<string, string>> = {
  // Not ported (docs/api-differences.md)
  BclDateTimeZone: "no TimeZoneInfo in JS; Windows IDs are supported via noda-js/windows",
  BclDateTimeZoneSource: "no TimeZoneInfo in JS; Windows IDs are supported via noda-js/windows",
  DateTimeZoneProviders: "no global provider registry; import noda-js/tzdb/bundled or noda-js/browser",
  DateTimeExtensions: "BCL interop",
  DateTimeOffsetExtensions: "BCL interop",
  DateOnlyExtensions: "BCL interop",
  TimeOnlyExtensions: "BCL interop",
  TimeSpanExtensions: "BCL interop",
  StopwatchExtensions: "BCL interop",
  TimeProviderExtensions: "BCL interop",
  DayOfWeekExtensions: "BCL interop (System.DayOfWeek)",
  BclConversions: "BCL interop",
  TypeConverterSettings: ".NET TypeConverters",
  HebrewMonthNumbering: "non-ISO calendars",
  IslamicEpoch: "non-ISO calendars",
  IslamicLeapYearPattern: "non-ISO calendars",
  "CalendarSystem.Badi": "non-ISO calendars",
  "CalendarSystem.HebrewCivil": "non-ISO calendars",
  "CalendarSystem.HebrewScriptural": "non-ISO calendars",
  "CalendarSystem.IslamicBcl": "non-ISO calendars",
  "CalendarSystem.PersianSimple": "non-ISO calendars",
  "CalendarSystem.PersianArithmetic": "non-ISO calendars",
  "CalendarSystem.PersianAstronomical": "non-ISO calendars",
  "CalendarSystem.UmAlQura": "non-ISO calendars",
  "CalendarSystem.GetHebrewCalendar": "non-ISO calendars",
  "CalendarSystem.GetIslamicCalendar": "non-ISO calendars",
  "Era.AnnoHegirae": "non-ISO calendars",
  "Era.AnnoMundi": "non-ISO calendars",
  "Era.AnnoPersico": "non-ISO calendars",
  "Era.Bahai": "non-ISO calendars",
  "LocalDatePattern.CreateWithCurrentCulture": "no current culture in JS",
  "LocalTimePattern.CreateWithCurrentCulture": "no current culture in JS",
  "LocalDateTimePattern.CreateWithCurrentCulture": "no current culture in JS",
  "InstantPattern.CreateWithCurrentCulture": "no current culture in JS",
  "DurationPattern.CreateWithCurrentCulture": "no current culture in JS",
  "OffsetPattern.CreateWithCurrentCulture": "no current culture in JS",
  "OffsetDatePattern.CreateWithCurrentCulture": "no current culture in JS",
  "OffsetTimePattern.CreateWithCurrentCulture": "no current culture in JS",
  "OffsetDateTimePattern.CreateWithCurrentCulture": "no current culture in JS",
  "YearMonthPattern.CreateWithCurrentCulture": "no current culture in JS",
  "AnnualDatePattern.CreateWithCurrentCulture": "no current culture in JS",
  "ZonedDateTimePattern.CreateWithCurrentCulture": "no current culture in JS",
  "NodaFormatInfo.CurrentInfo": "no current culture in JS",
  "TzdbDateTimeZoneSource.Default": "no data in the class; use tzdbSource from noda-js/tzdb/bundled",
  "TzdbDateTimeZoneSource.FromStream": "no streams; use TzdbDateTimeZoneSource.fromBytes / fromBase64",
  "ClockExtensions.InTzdbSystemDefaultZone": "core can't depend on tzdb; use clock.inZone(tzdb.getSystemDefault())",
  "ClockExtensions.InBclSystemDefaultZone": "BCL interop",
  // No BigInt (noda-js targets ES2015); toInt64Nanoseconds and fromNanoseconds with a decimal string are exact within
  // the long range. (The FromNanoseconds(BigInteger) and FromNanoseconds(Int128) overloads aren't ported either.)
  "Duration.ToBigIntegerNanoseconds": "no BigInt in ES2015; use toInt64Nanoseconds (exact as a C# long) or totalNanoseconds",
  "Duration.ToInt128Nanoseconds": "no BigInt in ES2015; use toInt64Nanoseconds (exact as a C# long) or totalNanoseconds",
  // Abstract in C#: the TS abstract members are compile-time only; the implementations are checked through
  // the instances NodaTime exposes (OffsetDateTime.Comparer.local etc.) by tsc.
  "OffsetDateTimeComparer.Compare": "abstract (implemented by Comparer.local / Comparer.instant)",
  "OffsetDateTimeComparer.Equals": "abstract (implemented by Comparer.local / Comparer.instant)",
  "ZonedDateTimeComparer.Compare": "abstract (implemented by Comparer.local / Comparer.instant)",
  "ZonedDateTimeComparer.Equals": "abstract (implemented by Comparer.local / Comparer.instant)",
  "DateTimeZone.GetZoneInterval": "abstract (implemented by every zone class)",
};

/** Members whose noda-js name isn't the mechanical camelCase of the C# name ("Type.CSharpMember" → name). */
export const renamed: Readonly<Record<string, string>> = {};
