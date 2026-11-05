// noda-js-zod: the schemas. Each one is a zod codec between NodaTime's JSON wire format (as written by
// NodaTime.Serialization.SystemTextJson, and by noda-js's toJSON()) and the noda-js value:
// `.parse(json)` decodes with the type's fromJSON(), `.encode(value)` encodes with toJSON().
//
// The schemas are named exports, so a bundler drops the ones an app doesn't use; index.ts default-exports this
// module's namespace as `NodaZ`. Every schema is created with a /* @__PURE__ */ call, and pattern texts are only
// read when an error message is built, so an unused schema leaves nothing behind.

import * as z from "zod";
import {
  AnnualDate as NodaAnnualDate,
  AnnualDatePattern,
  ArgumentNullError,
  CalendarSystem,
  DateInterval as NodaDateInterval,
  DateTimeZone as NodaDateTimeZone,
  Duration as NodaDuration,
  DurationPattern,
  Instant as NodaInstant,
  InstantPattern,
  Interval as NodaInterval,
  LocalDate as NodaLocalDate,
  LocalDatePattern,
  LocalDateTime as NodaLocalDateTime,
  LocalDateTimePattern,
  LocalTime as NodaLocalTime,
  LocalTimePattern,
  Offset as NodaOffset,
  OffsetDate as NodaOffsetDate,
  OffsetDatePattern,
  OffsetDateTime as NodaOffsetDateTime,
  OffsetDateTimePattern,
  OffsetPattern,
  OffsetTime as NodaOffsetTime,
  OffsetTimePattern,
  Period as NodaPeriod,
  YearMonth as NodaYearMonth,
  YearMonthPattern,
  ZonedDateTime as NodaZonedDateTime,
  type IDateTimeZoneProvider,
} from "noda-js";

// #region Types

/** A schema for a value carried as a JSON string: `.parse(string)` gives a `T`, `.encode(T)` gives the string. */
export type TextSchema<T> = z.ZodCodec<z.ZodString, z.ZodCustom<T, T>>;

/** A schema for a value carried as a JSON object `J`: `.parse(object)` gives a `T`, `.encode(T)` gives the object. */
export type ObjectSchema<J, T> = z.ZodCodec<z.ZodCustom<J, J>, z.ZodCustom<T, T>>;

/**
 * A schema for a type with a calendar system. JSON doesn't record the calendar, so the reader has to know it: this
 * schema reads values in the ISO calendar, and `.WithCalendar(calendar)` returns a new schema (this one is unchanged)
 * that reads them in `calendar`, as NodaTime.Serialization.SystemTextJson does with a converter whose pattern uses
 * that calendar.
 */
export type CalendarSchema<S> = S & {
  /** A schema like this one that reads values in the given calendar system (this schema is unchanged). */
  WithCalendar(calendar: CalendarSystem): CalendarSchema<S>;
};

/** The JSON form of an Interval: a property is omitted when the interval is unbounded in that direction. */
export interface IntervalJson {
  start?: string;
  end?: string;
}

/** The JSON form of a DateInterval (both dates inclusive). */
export interface DateIntervalJson {
  start: string;
  end: string;
}

// #endregion

// #region Helpers

// The class of a noda-js type, as the right-hand side of instanceof. (z.instanceof needs a public constructor; most
// noda-js classes don't have one.)
type NodaClass<T> = Function & { prototype: T };

/** What a wrong input was, for error messages, with zod's names (`null`, `array`, `number`, ...). */
function receivedType(input: unknown): string {
  if (input === null) {
    return "null";
  }
  if (Array.isArray(input)) {
    return "array";
  }
  return typeof input;
}

/** E.g. `an Instant string in the format <pattern text>`. */
function stringInFormat(description: string, format: string): string {
  return `${description} string in the format ${format}`;
}

/** E.g. `Expected an Instant string in the format <pattern text>, but received number`. */
function expectedMessage(expected: string, input: unknown): string {
  return `Expected ${expected}, but received ${receivedType(input)}`;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** The output side of a codec: an instance of the given noda-js class. */
function instanceOf<T>(type: NodaClass<T>, description: string): z.ZodCustom<T, T> {
  return z.custom<T>((value) => value instanceof type, {
    error: (issue) => expectedMessage(`${description} value`, issue.input),
  });
}

/**
 * A codec between a JSON string and a noda-js value.
 *
 * @param type The noda-js class.
 * @param description The type's name with its article ("an Instant"), for error messages.
 * @param expected What the input should be ("an Instant string in the format ..."), for the wrong-type message.
 *   Only called when a message is built.
 * @param issueFormat The `format` of the `invalid_format` issue for an unparsable string: the type's name.
 * @param pattern The `pattern` of that issue (the pattern text), if the type has one. Only called on failure.
 * @param fromJSON The core's parser. It throws (usually an UnparsableValueError) when the string is invalid, and its
 *   message becomes the issue's message.
 */
function textSchema<T extends { toJSON(): string }>(
  type: NodaClass<T>,
  description: string,
  expected: () => string,
  issueFormat: string,
  pattern: (() => string) | null,
  fromJSON: (json: string) => T,
): TextSchema<T> {
  return z.codec(
    z.string({ error: (issue) => expectedMessage(expected(), issue.input) }),
    instanceOf(type, description),
    {
      decode: (json, payload) => {
        try {
          return fromJSON(json);
        } catch (error) {
          const message = errorMessage(error);
          payload.issues.push(
            pattern === null
              ? { code: "invalid_format", format: issueFormat, input: json, message }
              : { code: "invalid_format", format: issueFormat, pattern: pattern(), input: json, message },
          );
          return z.NEVER;
        }
      },
      encode: (value) => value.toJSON(),
    },
  );
}

/**
 * A {@link textSchema} for a type whose fromJSON parses with a pattern; the pattern's text is the expected format
 * (and the calendar, if it isn't ISO: see {@link calendarNote}).
 */
function patternSchema<T extends { toJSON(): string }>(
  type: NodaClass<T>,
  name: string,
  description: string,
  patternText: () => string,
  fromJSON: (json: string) => T,
  calendar?: CalendarSystem,
): TextSchema<T> {
  return textSchema(
    type, description, () => stringInFormat(description, patternText()) + calendarNote(calendar), name, patternText, fromJSON,
  );
}

/**
 * A codec between a `{ start, end }` object and an interval type. Property names are matched case-insensitively, as
 * the core's fromJSON does (so `{ Start, End }`, as written without a naming policy, is accepted too). Each bound is
 * checked with the bound's schema first, so its issues have the property's path; then the core's fromJSON builds
 * the value.
 *
 * @param boundsRequired Whether both properties must be present (DateInterval) or each is optional (Interval).
 * @param bound The schema of each bound.
 * @param boundExpected What each bound should be ("an Instant string in the format ..."), for error messages.
 */
function boundsSchema<J extends IntervalJson, T extends { toJSON(): J }>(
  type: NodaClass<T>,
  description: string,
  boundsRequired: boolean,
  bound: z.ZodType,
  boundExpected: () => string,
  fromJSON: (json: J) => T,
): ObjectSchema<J, T> {
  // The input side accepts anything: decode checks it, so that each issue can have the right path.
  return z.codec(z.custom<J>(), instanceOf(type, description), {
    decode: (json, payload) => {
      const input: unknown = json;
      if (typeof input !== "object" || input === null || Array.isArray(input)) {
        const bounds = boundsRequired ? "start and end properties" : "optional start and end properties";
        const message = expectedMessage(`${description} object with ${bounds}, each ${boundExpected()}`, input);
        payload.issues.push({ code: "invalid_type", expected: "object", input, message });
        return z.NEVER;
      }
      const issueCount = payload.issues.length;
      const seen: { [key: string]: boolean } = {};
      for (const key of Object.keys(input)) {
        const lowerKey = key.toLowerCase();
        if (lowerKey !== "start" && lowerKey !== "end") {
          continue;
        }
        seen[lowerKey] = true;
        const value: unknown = (input as { [key: string]: unknown })[key];
        const result = bound.safeParse(value);
        if (!result.success) {
          for (const issue of result.error.issues) {
            // (`value` is the input the issue is about: the bound schema only has issues at its root.)
            payload.issues.push({ ...issue, input: value, path: [key, ...issue.path] } as z.core.$ZodRawIssue);
          }
        }
      }
      if (boundsRequired) {
        for (const key of ["start", "end"]) {
          if (!seen[key]) {
            const message = expectedMessage(boundExpected(), undefined);
            payload.issues.push({ code: "invalid_type", expected: "string", input: undefined, path: [key], message });
          }
        }
      }
      if (payload.issues.length !== issueCount) {
        return z.NEVER;
      }
      try {
        return fromJSON(json);
      } catch (error) {
        // E.g. a DateInterval whose end is before its start.
        payload.issues.push({ code: "custom", input, message: errorMessage(error) });
        return z.NEVER;
      }
    },
    encode: (value) => value.toJSON(),
  });
}

/**
 * A schema for a type with a calendar: `create(undefined)` reads ISO values (the type's fromJSON default), and
 * WithCalendar builds a fresh schema with `create(calendar)`.
 */
function calendarSchema<S extends z.ZodType>(
  create: (calendar: CalendarSystem | undefined) => S,
  calendar?: CalendarSystem,
): CalendarSchema<S> {
  const schema = create(calendar) as CalendarSchema<S>;
  // Not enumerable, so the schema object looks the same as zod's own (e.g. when logged).
  Object.defineProperty(schema, "WithCalendar", {
    value: (next: CalendarSystem): CalendarSchema<S> => {
      if (next === null || next === undefined) {
        throw new ArgumentNullError("calendar");
      }
      return calendarSchema(create, next);
    },
  });
  return schema;
}

/** What an expected value adds for a non-ISO calendar: ", in the Coptic calendar" (nothing for ISO). */
function calendarNote(calendar: CalendarSystem | undefined): string {
  return calendar === undefined || calendar === CalendarSystem.Iso ? "" : `, in the ${calendar.Id} calendar`;
}

function checkProvider(provider: IDateTimeZoneProvider): void {
  if (provider === null || provider === undefined) {
    throw new ArgumentNullError("provider");
  }
}

// #endregion

// #region Schemas

/** An Instant, as `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'` (InstantPattern.ExtendedIso). */
export const Instant: TextSchema<NodaInstant> = /* @__PURE__ */ patternSchema(
  NodaInstant, "Instant", "an Instant", () => InstantPattern.ExtendedIso.PatternText, (json) => NodaInstant.fromJSON(json),
);

/**
 * A LocalDate, as `uuuu'-'MM'-'dd` (LocalDatePattern.Iso), in the ISO calendar; `.WithCalendar(calendar)` for
 * another.
 */
export const LocalDate: CalendarSchema<TextSchema<NodaLocalDate>> = /* @__PURE__ */ calendarSchema((calendar) => patternSchema(
  NodaLocalDate, "LocalDate", "a LocalDate", () => LocalDatePattern.Iso.PatternText,
  (json) => NodaLocalDate.fromJSON(json, calendar),
  calendar,
));

/** A LocalTime, as `HH':'mm':'ss;FFFFFFFFF` (LocalTimePattern.ExtendedIso). */
export const LocalTime: TextSchema<NodaLocalTime> = /* @__PURE__ */ patternSchema(
  NodaLocalTime, "LocalTime", "a LocalTime", () => LocalTimePattern.ExtendedIso.PatternText, (json) => NodaLocalTime.fromJSON(json),
);

/**
 * A LocalDateTime, as `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF` (LocalDateTimePattern.ExtendedIso), in the ISO
 * calendar; `.WithCalendar(calendar)` for another.
 */
export const LocalDateTime: CalendarSchema<TextSchema<NodaLocalDateTime>> = /* @__PURE__ */ calendarSchema((calendar) => patternSchema(
  NodaLocalDateTime, "LocalDateTime", "a LocalDateTime", () => LocalDateTimePattern.ExtendedIso.PatternText,
  (json) => NodaLocalDateTime.fromJSON(json, calendar),
  calendar,
));

/**
 * An OffsetDateTime, as `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>` (OffsetDateTimePattern.Rfc3339), in
 * the ISO calendar; `.WithCalendar(calendar)` for another.
 */
export const OffsetDateTime: CalendarSchema<TextSchema<NodaOffsetDateTime>> = /* @__PURE__ */ calendarSchema((calendar) => patternSchema(
  NodaOffsetDateTime, "OffsetDateTime", "an OffsetDateTime", () => OffsetDateTimePattern.Rfc3339.PatternText,
  (json) => NodaOffsetDateTime.fromJSON(json, calendar),
  calendar,
));

/**
 * An OffsetDate, as `uuuu'-'MM'-'ddo<G>` (OffsetDatePattern.GeneralIso), in the ISO calendar;
 * `.WithCalendar(calendar)` for another.
 */
export const OffsetDate: CalendarSchema<TextSchema<NodaOffsetDate>> = /* @__PURE__ */ calendarSchema((calendar) => patternSchema(
  NodaOffsetDate, "OffsetDate", "an OffsetDate", () => OffsetDatePattern.GeneralIso.PatternText,
  (json) => NodaOffsetDate.fromJSON(json, calendar),
  calendar,
));

/** An OffsetTime, as `HH':'mm':'ss;FFFFFFFFFo<G>` (OffsetTimePattern.ExtendedIso). */
export const OffsetTime: TextSchema<NodaOffsetTime> = /* @__PURE__ */ patternSchema(
  NodaOffsetTime, "OffsetTime", "an OffsetTime", () => OffsetTimePattern.ExtendedIso.PatternText,
  (json) => NodaOffsetTime.fromJSON(json),
);

/**
 * An Offset, as the general pattern `g` (OffsetPattern.GeneralInvariant): `+HH:mm:ss`, `+HH:mm` or `+HH`, whichever
 * is shortest for the offset.
 */
export const Offset: TextSchema<NodaOffset> = /* @__PURE__ */ patternSchema(
  NodaOffset, "Offset", "an Offset",
  // "g" is a standard pattern: in the invariant culture, the first of these three that represents the offset exactly.
  () => `${OffsetPattern.GeneralInvariant.PatternText} (+HH:mm:ss, +HH:mm or +HH)`,
  (json) => NodaOffset.fromJSON(json),
);

/** A Duration, as `-H:mm:ss.FFFFFFFFF` (DurationPattern.JsonRoundtrip). */
export const Duration: TextSchema<NodaDuration> = /* @__PURE__ */ patternSchema(
  NodaDuration, "Duration", "a Duration", () => DurationPattern.JsonRoundtrip.PatternText, (json) => NodaDuration.fromJSON(json),
);

/**
 * A Period, in PeriodPattern.Roundtrip's format: ISO 8601 with extra `s` (milliseconds), `t` (ticks) and
 * `n` (nanoseconds) units, every unit optional and each value possibly negative.
 */
export const Period: TextSchema<NodaPeriod> = /* @__PURE__ */ textSchema(
  NodaPeriod, "a Period",
  // PeriodPattern.Roundtrip isn't built from a pattern text, so it has no PatternText to quote.
  () => stringInFormat(
    "a Period",
    "P{years}Y{months}M{weeks}W{days}DT{hours}H{minutes}M{seconds}S{milliseconds}s{ticks}t{nanoseconds}n " +
      "(PeriodPattern.Roundtrip; every unit is optional)",
  ),
  "Period", null, (json) => NodaPeriod.fromJSON(json),
);

/** A YearMonth, as `uuuu'-'MM` (YearMonthPattern.Iso), in the ISO calendar; `.WithCalendar(calendar)` for another. */
export const YearMonth: CalendarSchema<TextSchema<NodaYearMonth>> = /* @__PURE__ */ calendarSchema((calendar) => patternSchema(
  NodaYearMonth, "YearMonth", "a YearMonth", () => YearMonthPattern.Iso.PatternText,
  (json) => NodaYearMonth.fromJSON(json, calendar),
  calendar,
));

/** An AnnualDate, as `MM'-'dd` (AnnualDatePattern.Iso). */
export const AnnualDate: TextSchema<NodaAnnualDate> = /* @__PURE__ */ patternSchema(
  NodaAnnualDate, "AnnualDate", "an AnnualDate", () => AnnualDatePattern.Iso.PatternText, (json) => NodaAnnualDate.fromJSON(json),
);

/**
 * An Interval, as an object `{ start?, end? }` of {@link Instant} strings; a missing property means the interval is
 * unbounded in that direction.
 */
export const Interval: ObjectSchema<IntervalJson, NodaInterval> = /* @__PURE__ */ boundsSchema(
  NodaInterval, "an Interval", false, Instant, () => stringInFormat("an Instant", InstantPattern.ExtendedIso.PatternText),
  (json: IntervalJson) => NodaInterval.fromJSON(json),
);

/**
 * A DateInterval, as an object `{ start, end }` of {@link LocalDate} strings (both inclusive), in the ISO calendar;
 * `.WithCalendar(calendar)` for another.
 */
export const DateInterval: CalendarSchema<ObjectSchema<DateIntervalJson, NodaDateInterval>> = /* @__PURE__ */ calendarSchema((calendar) => boundsSchema(
  NodaDateInterval, "a DateInterval", true, calendar === undefined ? LocalDate : LocalDate.WithCalendar(calendar),
  () => stringInFormat("a LocalDate", LocalDatePattern.Iso.PatternText) + calendarNote(calendar),
  (json: DateIntervalJson) => NodaDateInterval.fromJSON(json, calendar),
));

// The core keeps the pattern its ZonedDateTime.fromJSON uses private (ZonedDateTime.ts), so its text is repeated here.
const zonedDateTimePatternText = "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z";

/**
 * A schema for a ZonedDateTime, as `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z` (the offset, then the zone ID),
 * resolving zone IDs with the given provider (such as `tzdb` from `noda-js/tzdb/bundled`), in the ISO calendar;
 * `.WithCalendar(calendar)` for another.
 */
export function ZonedDateTime(provider: IDateTimeZoneProvider): CalendarSchema<TextSchema<NodaZonedDateTime>> {
  checkProvider(provider);
  return calendarSchema((calendar) => patternSchema(
    NodaZonedDateTime, "ZonedDateTime", "a ZonedDateTime", () => zonedDateTimePatternText,
    (json) => NodaZonedDateTime.fromJSON(json, provider, calendar),
    calendar,
  ));
}

/**
 * A schema for a DateTimeZone, as its ID, resolved with the given provider (such as `tzdb` from
 * `noda-js/tzdb/bundled`).
 */
export function DateTimeZone(provider: IDateTimeZoneProvider): TextSchema<NodaDateTimeZone> {
  checkProvider(provider);
  return textSchema(
    NodaDateTimeZone, "a DateTimeZone", () => "a DateTimeZone ID string (one of the provider's Ids)", "DateTimeZone", null,
    (json) => NodaDateTimeZone.fromJSON(json, provider),
  );
}

// #endregion
