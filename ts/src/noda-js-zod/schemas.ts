// noda-js-zod: new code. Zod codecs between NodaTime's JSON formats and noda-js values (fromJSON / toJSON).
// Every schema is a /* @__PURE__ */ call and reads pattern texts lazily, so unused schemas tree-shake away.

import * as z from "zod";
import {
  AnnualDate as NodaAnnualDate,
  AnnualDatePattern,
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
  NodaError,
  type ArgumentNullException,
  type IDateTimeZoneProvider,
} from "noda-js";

/** noda-js's error for a null argument (an ArgumentNullException NodaError). */
function NewArgumentNullException(paramName: string): ArgumentNullException {
  return Object.assign(new NodaError("ArgumentNullException", "Value cannot be null."), { ParamName: paramName });
}

// #region Types

/** A schema for a value carried as a JSON string: `.parse(string)` gives a `T`, `.encode(T)` gives the string. */
export type TextSchema<T> = z.ZodCodec<z.ZodString, z.ZodCustom<T, T>>;

/** A schema for a value carried as a JSON object `J`: `.parse(object)` gives a `T`, `.encode(T)` gives the object. */
export type ObjectSchema<J, T> = z.ZodCodec<z.ZodCustom<J, J>, z.ZodCustom<T, T>>;

/** A schema for a type with a calendar: it reads ISO values; `.WithCalendar(calendar)` returns one for another calendar. */
export type CalendarSchema<S> = S & {
  /** A new schema that reads values in the given calendar system. */
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

// A noda-js class, for instanceof (z.instanceof needs a public constructor, which most don't have).
type NodaClass<T> = Function & { prototype: T };

/** What a wrong input was, for error messages, with zod's names (`null`, `array`, `number`, ...). */
function ReceivedType(input: unknown): string {
  if (input === null) {
    return "null";
  }
  if (Array.isArray(input)) {
    return "array";
  }
  return typeof input;
}

/** E.g. `an Instant string in the format <pattern text>`. */
function StringInFormat(description: string, format: string): string {
  return `${description} string in the format ${format}`;
}

/** E.g. `Expected an Instant string in the format <pattern text>, but received number`. */
function ExpectedMessage(expected: string, input: unknown): string {
  return `Expected ${expected}, but received ${ReceivedType(input)}`;
}

function ErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** The output side of a codec: an instance of the given noda-js class. */
function InstanceOf<T>(type: NodaClass<T>, description: string): z.ZodCustom<T, T> {
  return z.custom<T>((value) => value instanceof type, {
    error: (issue) => ExpectedMessage(`${description} value`, issue.input),
  });
}

/**
 * A codec between a JSON string and a noda-js value.
 * @param type The noda-js class.
 * @param description E.g. "an Instant".
 * @param expected E.g. "an Instant string in the format ..." (called lazily).
 * @param issueFormat The `invalid_format` issue's `format`: the type's name.
 * @param pattern The issue's `pattern` (called lazily).
 * @param fromJSON The core's parser; its error message becomes the issue's.
 */
function CreateTextSchema<T extends { toJSON(): string }>(
  type: NodaClass<T>,
  description: string,
  expected: () => string,
  issueFormat: string,
  pattern: (() => string) | null,
  fromJSON: (json: string) => T,
): TextSchema<T> {
  return z.codec(
    z.string({ error: (issue) => ExpectedMessage(expected(), issue.input) }),
    InstanceOf(type, description),
    {
      decode: (json, payload) => {
        try {
          return fromJSON(json);
        } catch (error) {
          const message = ErrorMessage(error);
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

/** A {@link CreateTextSchema} whose expected format is a pattern's text (and calendar: {@link CalendarNote}). */
function CreatePatternSchema<T extends { toJSON(): string }>(
  type: NodaClass<T>,
  name: string,
  description: string,
  patternText: () => string,
  fromJSON: (json: string) => T,
  calendar?: CalendarSystem,
): TextSchema<T> {
  return CreateTextSchema(
    type, description, () => StringInFormat(description, patternText()) + CalendarNote(calendar), name, patternText, fromJSON,
  );
}

/**
 * A codec between a `{ start, end }` object (names matched ignoring case, as fromJSON) and an interval type.
 * @param boundsRequired Whether both bounds are required (DateInterval) or optional (Interval).
 * @param bound The schema of each bound.
 * @param boundExpected What each bound should be, for error messages.
 */
function CreateBoundsSchema<J extends IntervalJson, T extends { toJSON(): J }>(
  type: NodaClass<T>,
  description: string,
  boundsRequired: boolean,
  bound: z.ZodType,
  boundExpected: () => string,
  fromJSON: (json: J) => T,
): ObjectSchema<J, T> {
  // The input side accepts anything: decode checks it, so that each issue can have the right path.
  return z.codec(z.custom<J>(), InstanceOf(type, description), {
    decode: (json, payload) => {
      const input: unknown = json;
      if (typeof input !== "object" || input === null || Array.isArray(input)) {
        const bounds = boundsRequired ? "start and end properties" : "optional start and end properties";
        const message = ExpectedMessage(`${description} object with ${bounds}, each ${boundExpected()}`, input);
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
            const message = ExpectedMessage(boundExpected(), undefined);
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
        payload.issues.push({ code: "custom", input, message: ErrorMessage(error) });
        return z.NEVER;
      }
    },
    encode: (value) => value.toJSON(),
  });
}

/** A {@link CalendarSchema} built by `create(calendar)` (undefined: ISO). */
function CreateCalendarSchema<S extends z.ZodType>(
  create: (calendar: CalendarSystem | undefined) => S,
  calendar?: CalendarSystem,
): CalendarSchema<S> {
  const schema = create(calendar) as CalendarSchema<S>;
  // Not enumerable, so the schema object looks the same as zod's own (e.g. when logged).
  Object.defineProperty(schema, "WithCalendar", {
    value: (next: CalendarSystem): CalendarSchema<S> => {
      if (next === null || next === undefined) {
        throw NewArgumentNullException("calendar");
      }
      return CreateCalendarSchema(create, next);
    },
  });
  return schema;
}

/** What an expected value adds for a non-ISO calendar: ", in the Coptic calendar" (nothing for ISO). */
function CalendarNote(calendar: CalendarSystem | undefined): string {
  return calendar === undefined || calendar === CalendarSystem.Iso ? "" : `, in the ${calendar.Id} calendar`;
}

function CheckProvider(provider: IDateTimeZoneProvider): void {
  if (provider === null || provider === undefined) {
    throw NewArgumentNullException("provider");
  }
}

// #endregion

// #region Schemas

/** An Instant, as `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'` (InstantPattern.ExtendedIso). */
export const Instant: TextSchema<NodaInstant> = /* @__PURE__ */ CreatePatternSchema(
  NodaInstant, "Instant", "an Instant", () => InstantPattern.ExtendedIso.PatternText, (json) => NodaInstant.fromJSON(json),
);

/** A LocalDate, as `uuuu'-'MM'-'dd` (LocalDatePattern.Iso). */
export const LocalDate: CalendarSchema<TextSchema<NodaLocalDate>> = /* @__PURE__ */ CreateCalendarSchema((calendar) => CreatePatternSchema(
  NodaLocalDate, "LocalDate", "a LocalDate", () => LocalDatePattern.Iso.PatternText,
  (json) => NodaLocalDate.fromJSON(json, calendar),
  calendar,
));

/** A LocalTime, as `HH':'mm':'ss;FFFFFFFFF` (LocalTimePattern.ExtendedIso). */
export const LocalTime: TextSchema<NodaLocalTime> = /* @__PURE__ */ CreatePatternSchema(
  NodaLocalTime, "LocalTime", "a LocalTime", () => LocalTimePattern.ExtendedIso.PatternText, (json) => NodaLocalTime.fromJSON(json),
);

/** A LocalDateTime, as `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF` (LocalDateTimePattern.ExtendedIso). */
export const LocalDateTime: CalendarSchema<TextSchema<NodaLocalDateTime>> = /* @__PURE__ */ CreateCalendarSchema((calendar) => CreatePatternSchema(
  NodaLocalDateTime, "LocalDateTime", "a LocalDateTime", () => LocalDateTimePattern.ExtendedIso.PatternText,
  (json) => NodaLocalDateTime.fromJSON(json, calendar),
  calendar,
));

/** An OffsetDateTime, as `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>` (OffsetDateTimePattern.Rfc3339). */
export const OffsetDateTime: CalendarSchema<TextSchema<NodaOffsetDateTime>> = /* @__PURE__ */ CreateCalendarSchema((calendar) => CreatePatternSchema(
  NodaOffsetDateTime, "OffsetDateTime", "an OffsetDateTime", () => OffsetDateTimePattern.Rfc3339.PatternText,
  (json) => NodaOffsetDateTime.fromJSON(json, calendar),
  calendar,
));

/** An OffsetDate, as `uuuu'-'MM'-'ddo<G>` (OffsetDatePattern.GeneralIso). */
export const OffsetDate: CalendarSchema<TextSchema<NodaOffsetDate>> = /* @__PURE__ */ CreateCalendarSchema((calendar) => CreatePatternSchema(
  NodaOffsetDate, "OffsetDate", "an OffsetDate", () => OffsetDatePattern.GeneralIso.PatternText,
  (json) => NodaOffsetDate.fromJSON(json, calendar),
  calendar,
));

/** An OffsetTime, as `HH':'mm':'ss;FFFFFFFFFo<G>` (OffsetTimePattern.ExtendedIso). */
export const OffsetTime: TextSchema<NodaOffsetTime> = /* @__PURE__ */ CreatePatternSchema(
  NodaOffsetTime, "OffsetTime", "an OffsetTime", () => OffsetTimePattern.ExtendedIso.PatternText,
  (json) => NodaOffsetTime.fromJSON(json),
);

/** An Offset, as `g` (OffsetPattern.GeneralInvariant): the shortest of `+HH:mm:ss`, `+HH:mm` and `+HH`. */
export const Offset: TextSchema<NodaOffset> = /* @__PURE__ */ CreatePatternSchema(
  NodaOffset, "Offset", "an Offset",
  // "g" is a standard pattern: in the invariant culture, the first of these three that represents the offset exactly.
  () => `${OffsetPattern.GeneralInvariant.PatternText} (+HH:mm:ss, +HH:mm or +HH)`,
  (json) => NodaOffset.fromJSON(json),
);

/** A Duration, as `-H:mm:ss.FFFFFFFFF` (DurationPattern.JsonRoundtrip). */
export const Duration: TextSchema<NodaDuration> = /* @__PURE__ */ CreatePatternSchema(
  NodaDuration, "Duration", "a Duration", () => DurationPattern.JsonRoundtrip.PatternText, (json) => NodaDuration.fromJSON(json),
);

/** A Period, as PeriodPattern.Roundtrip (ISO 8601 plus `s`, `t` and `n` units, each possibly negative). */
export const Period: TextSchema<NodaPeriod> = /* @__PURE__ */ CreateTextSchema(
  NodaPeriod, "a Period",
  // PeriodPattern.Roundtrip isn't built from a pattern text, so it has no PatternText to quote.
  () => StringInFormat(
    "a Period",
    "P{years}Y{months}M{weeks}W{days}DT{hours}H{minutes}M{seconds}S{milliseconds}s{ticks}t{nanoseconds}n " +
      "(PeriodPattern.Roundtrip; every unit is optional)",
  ),
  "Period", null, (json) => NodaPeriod.fromJSON(json),
);

/** A YearMonth, as `uuuu'-'MM` (YearMonthPattern.Iso). */
export const YearMonth: CalendarSchema<TextSchema<NodaYearMonth>> = /* @__PURE__ */ CreateCalendarSchema((calendar) => CreatePatternSchema(
  NodaYearMonth, "YearMonth", "a YearMonth", () => YearMonthPattern.Iso.PatternText,
  (json) => NodaYearMonth.fromJSON(json, calendar),
  calendar,
));

/** An AnnualDate, as `MM'-'dd` (AnnualDatePattern.Iso). */
export const AnnualDate: TextSchema<NodaAnnualDate> = /* @__PURE__ */ CreatePatternSchema(
  NodaAnnualDate, "AnnualDate", "an AnnualDate", () => AnnualDatePattern.Iso.PatternText, (json) => NodaAnnualDate.fromJSON(json),
);

/** An Interval, as `{ start?, end? }` of {@link Instant} strings (missing: unbounded). */
export const Interval: ObjectSchema<IntervalJson, NodaInterval> = /* @__PURE__ */ CreateBoundsSchema(
  NodaInterval, "an Interval", false, Instant, () => StringInFormat("an Instant", InstantPattern.ExtendedIso.PatternText),
  (json: IntervalJson) => NodaInterval.fromJSON(json),
);

/** A DateInterval, as `{ start, end }` of {@link LocalDate} strings (both inclusive). */
export const DateInterval: CalendarSchema<ObjectSchema<DateIntervalJson, NodaDateInterval>> = /* @__PURE__ */ CreateCalendarSchema((calendar) => CreateBoundsSchema(
  NodaDateInterval, "a DateInterval", true, calendar === undefined ? LocalDate : LocalDate.WithCalendar(calendar),
  () => StringInFormat("a LocalDate", LocalDatePattern.Iso.PatternText) + CalendarNote(calendar),
  (json: DateIntervalJson) => NodaDateInterval.fromJSON(json, calendar),
));

// The core keeps the pattern its ZonedDateTime.fromJSON uses private (ZonedDateTime.ts), so its text is repeated here.
const zonedDateTimePatternText = "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z";

/** A ZonedDateTime, as `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z`, with zone IDs from the given provider. */
export function ZonedDateTime(provider: IDateTimeZoneProvider): CalendarSchema<TextSchema<NodaZonedDateTime>> {
  CheckProvider(provider);
  return CreateCalendarSchema((calendar) => CreatePatternSchema(
    NodaZonedDateTime, "ZonedDateTime", "a ZonedDateTime", () => zonedDateTimePatternText,
    (json) => NodaZonedDateTime.fromJSON(json, provider, calendar),
    calendar,
  ));
}

/** A DateTimeZone, as its ID, resolved with the given provider (such as `tzdb`). */
export function DateTimeZone(provider: IDateTimeZoneProvider): TextSchema<NodaDateTimeZone> {
  CheckProvider(provider);
  return CreateTextSchema(
    NodaDateTimeZone, "a DateTimeZone", () => "a DateTimeZone ID string (one of the provider's Ids)", "DateTimeZone", null,
    (json) => NodaDateTimeZone.fromJSON(json, provider),
  );
}

// #endregion
