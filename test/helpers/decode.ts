// Decodes values encoded by tools/NodaJs.Tools/Common/TsValueEncoder.cs (test scenarios, golden files)
// into noda-js values.

import * as noda from "../../src/noda-js/internal.ts";
import {
  AnnualDate,
  CalendarSystem,
  NodaCultureInfo,
  DateInterval,
  DateTimeZone,
  Duration,
  Era,
  Instant,
  Interval,
  IslamicEpoch,
  IslamicLeapYearPattern,
  LocalDate,
  LocalTime,
  NodaConstants,
  Offset,
  PeriodBuilder,
  YearMonth,
  ZoneInterval,
  PrecalculatedDateTimeZone,
  type IDateTimeZoneProvider,
} from "../../src/noda-js/internal.ts";
import { WindowsIdDateTimeZoneProvider } from "../../src/noda-js/entries/windows.ts";
import * as calendars from "../../src/noda-js/entries/calendars/all.ts";
import type { EncodedObject, EncodedValue } from "../scenarios/types.ts";
import { scenarioCultures } from "../scenarios/cultures.generated.ts";

/** Thrown when a value can't be represented in noda-js (e.g. a calendar other than ISO, Gregorian, Julian or Coptic; a BCL type). */
export class UnsupportedValue extends Error {
  override name = "UnsupportedValue";
}

/**
 * Values for static references to test-assembly members (e.g. "ZonedDateTimePatternTest.TestProvider"),
 * registered by the ported test files that define them.
 */
export const testStatics = new Map<string, () => unknown>();

/**
 * Zones defined by test classes (e.g. NodaTime.Testing zones), by ID. Encoded "custom" zones with a
 * registered ID decode to the registered instance, because zone equality is by reference in NodaTime.
 */
export const testZones = new Map<string, DateTimeZone>();
const customZoneCache = new Map<string, DateTimeZone>();

/** The tzdb provider used for { $: "DateTimeZone", provider: "tzdb" } values. Loaded on first use. */
let tzdbProvider: IDateTimeZoneProvider | undefined;
export async function loadTzdbProvider(): Promise<IDateTimeZoneProvider> {
  if (!tzdbProvider) {
    const module = await import("../../src/noda-js/entries/tzdb-bundled.ts");
    tzdbProvider = module.tzdb;
  }
  return tzdbProvider;
}

let windowsIdProvider: WindowsIdDateTimeZoneProvider | undefined;
/** The provider for { $: "DateTimeZone", provider: "bcl" } values: Windows zone IDs mapped to tzdb zones. */
export function windowsProvider(): WindowsIdDateTimeZoneProvider {
  if (!tzdbProvider) {
    throw new UnsupportedValue("Call loadTzdbProvider() before decoding Windows (BCL) zones");
  }
  return (windowsIdProvider ??= new WindowsIdDateTimeZoneProvider(tzdbProvider));
}

const cultureCache = new Map<string, NodaCultureInfo>();

/** The culture for a scenario culture key ("en-US", "Cultures.GenitiveNameTestCulture", ...). */
export function scenarioCulture(key: string): NodaCultureInfo {
  let culture = cultureCache.get(key);
  if (!culture) {
    const data = scenarioCultures[key];
    if (!data) {
      throw new UnsupportedValue(`No data for culture ${key}`);
    }
    culture = key === "Cultures.Invariant" || key === "" ? NodaCultureInfo.InvariantCulture : NodaCultureInfo.FromData(data);
    cultureCache.set(key, culture);
  }
  return culture;
}

/**
 * A C# long (or other integer) encoded as a bigint (beyond 2^53) becomes what noda-js APIs taking a C# long accept: a
 * number when it's a safe integer, otherwise its exact decimal string. (src/ has no bigint; see
 * docs/porting-conventions.md, "Numbers".) Expected results are compared as numbers instead: see decodeExpected.
 */
export function decodeLong(value: bigint): number | string {
  return value >= -9007199254740991n && value <= 9007199254740991n ? Number(value) : value.toString();
}

export function decode(value: EncodedValue | undefined): any {
  if (typeof value === "bigint") {
    return decodeLong(value);
  }
  if (value === null || value === undefined || typeof value !== "object") {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map(decode);
  }
  return decodeObject(value as EncodedObject);
}

function decodeObject(value: EncodedObject): any {
  const v = value as any;
  switch (value.$) {
    case "LocalDate":
      return date(v);
    case "LocalTime":
      return LocalTime.FromHourMinuteSecondNanosecond(v.hour, v.minute, v.second, v.nanosecond);
    case "LocalDateTime":
      return date(v).At(LocalTime.FromHourMinuteSecondNanosecond(v.hour, v.minute, v.second, v.nanosecond));
    case "Instant":
      return instant(v);
    case "Duration":
      return duration(v.days, v.nanoOfDay);
    case "Offset":
      return Offset.FromSeconds(v.seconds);
    case "OffsetDateTime":
      return date(v).At(LocalTime.FromHourMinuteSecondNanosecond(v.hour, v.minute, v.second, v.nanosecond)).WithOffset(Offset.FromSeconds(v.offsetSeconds));
    case "OffsetDate":
      return date(v).WithOffset(Offset.FromSeconds(v.offsetSeconds));
    case "OffsetTime":
      return LocalTime.FromHourMinuteSecondNanosecond(v.hour, v.minute, v.second, v.nanosecond).WithOffset(Offset.FromSeconds(v.offsetSeconds));
    case "ZonedDateTime": {
      const local = date(v).At(LocalTime.FromHourMinuteSecondNanosecond(v.hour, v.minute, v.second, v.nanosecond));
      // OffsetDateTime.InZone gives the ISO calendar (as in NodaTime), so pass the value's calendar explicitly.
      return local.WithOffset(Offset.FromSeconds(v.offsetSeconds)).ToInstant().InZone(zone(v.zone), local.Calendar);
    }
    case "YearMonth":
      return new YearMonth(v.year, v.month, calendar(v.calendar));
    case "AnnualDate":
      return new AnnualDate(v.month, v.day);
    case "Period": {
      const builder = new PeriodBuilder();
      for (const unit of ["years", "months", "weeks", "days", "hours", "minutes", "seconds", "milliseconds", "ticks", "nanoseconds"] as const) {
        if (v[unit] !== undefined) {
          (builder as any)[unit[0].toUpperCase() + unit.substring(1)] = decode(v[unit]);
        }
      }
      return builder.Build();
    }
    case "Interval":
      return new Interval(v.start === null ? null : instant(v.start), v.end === null ? null : instant(v.end));
    case "DateInterval":
      return new DateInterval(decode(v.start), decode(v.end));
    case "CalendarSystem":
      return calendar(v.id);
    case "Era":
      return era(v.name);
    case "DateTimeZone":
      return zone(v);
    case "ZoneInterval":
      return zoneInterval(v);
    case "CultureInfo":
      return scenarioCulture(v.key ?? v.name);
    case "enum":
      return v.value;
    case "Type":
      return v.name;
    case "Tuple":
      return (v.items as EncodedValue[]).map(decode);
    case "KeyValuePair":
      return [decode(v.key), decode(v.value)];
    case "Static":
      return staticReference(v.ref);
    case "Pattern":
      return pattern(v);
    case "NamedWrapper":
      // NamedWrapper<Era> (EraTest): the name is the Era property's name, which also identifies the eras that share
      // an abbreviation ("AM" is both AnnoMartyrum and AnnoMundi).
      if (v.value?.$ === "Era") {
        const namedEra = (Era as any)[v.name];
        if (!(namedEra instanceof Era) || namedEra.Name !== v.value.name) {
          throw new UnsupportedValue(`Era ${v.name} isn't available in noda-js`);
        }
        return { $: "NamedWrapper", value: namedEra, name: v.name };
      }
      // NamedWrapper<YearMonthDayCalculator> (YearMonthDayCalculatorTest): a calculator (internal, so encoded as
      // Unsupported) is identified by the wrapper's name; it's that calendar system's calculator.
      if (v.value?.$ === "Unsupported" && /^NodaTime\.Calendars\.\w+YearMonthDayCalculator(\+\w+)?$/.test(v.value.type)) {
        return { $: "NamedWrapper", value: CalculatorCalendar(v.name).YearMonthDayCalculator, name: v.name };
      }
      return { $: "NamedWrapper", value: decode(v.value), name: v.name };
    case "Bcl":
    case "Delegate":
    case "decimal":
    case "Unsupported":
      throw new UnsupportedValue(`${value.$} value${v.type ? ` (${v.type})` : ""} isn't supported by noda-js`);
    default: {
      // A test data object (e.g. "LocalDatePatternTest.Data"): decode its fields, keep the tag.
      const result: Record<string, unknown> = { $: value.$ };
      for (const [key, field] of Object.entries(value)) {
        if (key !== "$") {
          result[key] = decode(field as EncodedValue);
        }
      }
      return result;
    }
  }
}

/**
 * The calendar system whose calculator YearMonthDayCalculatorTest names: "Gregorian" (the ISO calendar's calculator),
 * a calendar property name ("Julian", "HebrewCivil", "PersianSimple", ...; "UmAlQura)" as NodaTime spells it), or
 * "Islamic;<epoch>;<leap year pattern>". (The non-core calendars are noda-js/calendars/all's exports.)
 */
function CalculatorCalendar(name: string): CalendarSystem {
  const islamic = /^Islamic;(\w+);(\w+)$/.exec(name);
  if (islamic) {
    return calendars.GetIslamicCalendar(
      IslamicLeapYearPattern[islamic[2] as keyof typeof IslamicLeapYearPattern],
      IslamicEpoch[islamic[1] as keyof typeof IslamicEpoch]);
  }
  const property = name === "Gregorian" ? "Iso" : name.replace(/\)$/, "");
  const calendar = (calendars as Record<string, unknown>)[property] ?? (CalendarSystem as unknown as Record<string, unknown>)[property];
  if (!(calendar instanceof CalendarSystem)) {
    throw new UnsupportedValue(`No calendar system for the calculator ${name}`);
  }
  return calendar;
}

function calendar(id: string | undefined): CalendarSystem {
  if (id === undefined) {
    return CalendarSystem.Iso;
  }
  if (!CalendarSystem.Ids.includes(id)) {
    throw new UnsupportedValue(`Calendar ${id} isn't supported by noda-js (${CalendarSystem.Ids.join(", ")} only)`);
  }
  return CalendarSystem.ForId(id);
}

function date(v: any): LocalDate {
  // The fields are the date's year, month and day in its own calendar (TsValueEncoder).
  return new LocalDate(v.year, v.month, v.day, calendar(v.calendar));
}

function era(name: string): Era {
  switch (name) {
    case "CE":
      return Era.Common;
    case "BCE":
      return Era.BeforeCommon;
    default:
      // "AM" is both AnnoMartyrum (Coptic) and AnnoMundi (Hebrew), so a bare era name can't say which; no scenario
      // passes a bare era name other than CE or BCE (EraTest uses NamedWrapper<Era>, decoded by property name).
      throw new UnsupportedValue(`Era ${name} can't be decoded from its name alone (only CE and BCE; other eras are decoded from NamedWrapper<Era>)`);
  }
}

function duration(days: number, nanoOfDay: number): Duration {
  return Duration.FromDays(days).Plus(Duration.FromNanoseconds(nanoOfDay));
}

function instant(v: any): Instant {
  if (v.iso === "StartOfTime") {
    return Instant.BeforeMinValue;
  }
  if (v.iso === "EndOfTime") {
    return Instant.AfterMaxValue;
  }
  return NodaConstants.UnixEpoch.Plus(duration(v.days, v.nanoOfDay));
}

function zoneInterval(v: any): ZoneInterval {
  return new ZoneInterval(
    v.name,
    v.start === null ? null : instant(v.start),
    v.end === null ? null : instant(v.end),
    Offset.FromSeconds(v.wallOffsetSeconds),
    Offset.FromSeconds(v.savingsSeconds),
  );
}

function zone(v: any): DateTimeZone {
  switch (v.provider) {
    case "fixed":
      return v.id === "UTC" ? DateTimeZone.Utc : DateTimeZone.ForOffset(Offset.FromSeconds(v.offsetSeconds));
    case "tzdb": {
      if (!tzdbProvider) {
        throw new UnsupportedValue("Call loadTzdbProvider() before decoding tzdb zones");
      }
      return tzdbProvider.GetZoneOrNull(v.id) ?? (() => { throw new UnsupportedValue(`Unknown tzdb zone ${v.id}`); })();
    }
    case "bcl": {
      // A Windows (BCL) zone ID: noda-js maps it to the tzdb zone CLDR gives for it (noda-js/windows).
      const zone = windowsProvider().GetZoneOrNull(v.id);
      if (zone === null) {
        throw new UnsupportedValue(`No tzdb zone for Windows zone ${v.id}`);
      }
      return zone;
    }
    default: {
      const registered = testZones.get(v.id);
      if (registered) {
        return registered;
      }
      // Same encoding → same instance, so equality (by reference) works between decoded values.
      const key = JSON.stringify(v, (_, x) => (typeof x === "bigint" ? x.toString() : x));
      let zone = customZoneCache.get(key);
      if (!zone) {
        zone = PrecalculatedDateTimeZone.NewIdIntervalsTailZone(v.id, (v.intervals as any[]).map(zoneInterval), null);
        customZoneCache.set(key, zone);
      }
      return zone;
    }
  }
}

/**
 * Decodes an expected result. A C# long result is compared as the nearest number (noda-js returns C# long results as
 * numbers); everything else decodes as {@link decode} does.
 */
export function decodeExpected(value: EncodedValue | undefined): any {
  return typeof value === "bigint" ? Number(value) : decode(value);
}

/** "Resolvers.StrictResolver" → noda.Resolvers.StrictResolver; test-assembly statics come from testStatics. */
function staticReference(ref: string): unknown {
  const registered = testStatics.get(ref);
  if (registered) {
    return registered();
  }
  if (ref === "DateTimeZoneProviders.Tzdb") {
    if (!tzdbProvider) {
      throw new UnsupportedValue("Call loadTzdbProvider() before decoding tzdb zones");
    }
    return tzdbProvider;
  }
  const dot = ref.lastIndexOf(".");
  const typeName = ref.substring(0, dot).replace(/\./g, "");
  const member = ref.substring(dot + 1);
  const type = (noda as any)[typeName];
  if (type === undefined || !(member in type)) {
    throw new UnsupportedValue(`Static reference ${ref} isn't available in noda-js`);
  }
  return type[member];
}

function pattern(v: any): unknown {
  const type = (noda as any)[v.type];
  if (type === undefined) {
    throw new UnsupportedValue(`Pattern type ${v.type} isn't available`);
  }
  const culture = v.culture ? decode(v.culture) : NodaCultureInfo.InvariantCulture;
  if (v.type === "ZonedDateTimePattern") {
    return type.Create(v.patternText, culture, decode(v.resolver), decode(v.zoneProvider), decode(v.templateValue));
  }
  let result = type.CreateWithInvariantCulture(v.patternText).WithCulture(culture);
  if (v.templateValue !== undefined) {
    result = result.WithTemplateValue(decode(v.templateValue));
  }
  return result;
}

/** The noda-js name of a C# member: see docs/porting-conventions.md. */
export function camelCase(name: string): string {
  const match = /^[A-Z]+/.exec(name);
  if (!match) {
    return name;
  }
  const run = match[0].length;
  if (run === 1 || run === name.length) {
    return name.substring(0, run).toLowerCase() + name.substring(run);
  }
  const lowerCount = /[a-z]/.test(name[run]!) ? run - 1 : run;
  return name.substring(0, lowerCount).toLowerCase() + name.substring(lowerCount);
}

/** Every tzdb zone ID referenced anywhere in a value, so callers know whether to load tzdb first. */
export function needsTzdb(value: unknown): boolean {
  if (value === null || typeof value !== "object") {
    return false;
  }
  if (Array.isArray(value)) {
    return value.some(needsTzdb);
  }
  const v = value as any;
  if ((v.$ === "DateTimeZone" && (v.provider === "tzdb" || v.provider === "bcl")) || (v.$ === "Static" && v.ref === "DateTimeZoneProviders.Tzdb")) {
    return true;
  }
  return Object.values(v).some(needsTzdb);
}
