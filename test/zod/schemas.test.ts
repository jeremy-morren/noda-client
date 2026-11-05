// noda-js-zod: every schema decodes NodaTime's JSON wire format with the core's fromJSON, encodes with toJSON, and
// reports bad input as zod issues: the core's parse message for an unparsable string, and "Expected <type> string in
// the format <pattern text>, but received <type>" for anything that isn't a string.

import { describe, expect, it } from "vitest";
import type * as z from "zod";
import {
  AnnualDate,
  AnnualDatePattern,
  DateInterval,
  Duration,
  DurationPattern,
  Instant,
  InstantPattern,
  Interval,
  LocalDate,
  LocalDatePattern,
  LocalDateTime,
  LocalDateTimePattern,
  LocalTime,
  LocalTimePattern,
  Offset,
  OffsetDate,
  OffsetDatePattern,
  OffsetDateTime,
  OffsetDateTimePattern,
  OffsetPattern,
  OffsetTime,
  OffsetTimePattern,
  Period,
  YearMonth,
  YearMonthPattern,
  ZonedDateTime,
} from "noda-js";
import { tzdb } from "noda-js/tzdb/bundled";
import NodaZ from "../../src/noda-js-zod/index.ts";

interface NodaValue {
  Equals(other: unknown): boolean;
  toJSON(): unknown;
}

interface TextCase {
  name: string;
  schema: z.ZodType<NodaValue, string>;
  /** What the wrong-type message says is expected, e.g. "an Instant string in the format ...". */
  expected: string;
  /** JSON strings, the values they decode to, and (when the JSON isn't canonical) what encode gives back. */
  valid: Array<[json: string, value: NodaValue, encoded?: string]>;
  /** Strings the core's fromJSON rejects. */
  invalid: string[];
  fromJSON: (json: string) => unknown;
}

const instantFormat = () => InstantPattern.ExtendedIso.PatternText;
const localDateFormat = () => LocalDatePattern.Iso.PatternText;
const paris = tzdb.Get("Europe/Paris");

const textCases: TextCase[] = [
  {
    name: "Instant",
    schema: NodaZ.Instant,
    expected: `an Instant string in the format ${instantFormat()}`,
    valid: [
      ["2024-01-31T12:00:00Z", Instant.FromUtc(2024, 1, 31, 12, 0)],
      ["2024-01-31T12:00:00.123456789Z", Instant.FromUtc(2024, 1, 31, 12, 0).PlusNanoseconds(123456789)],
      ["-0001-01-01T00:00:00Z", Instant.FromUtc(-1, 1, 1, 0, 0)],
    ],
    invalid: ["", "2024-13-01T00:00:00Z", "2024-01-31", "2024-01-31T12:00:00+01:00", "2024-01-31T12:00:00z"],
    fromJSON: (json) => Instant.fromJSON(json),
  },
  {
    name: "LocalDate",
    schema: NodaZ.LocalDate,
    expected: `a LocalDate string in the format ${localDateFormat()}`,
    valid: [["2024-02-29", new LocalDate(2024, 2, 29)]],
    invalid: ["2023-02-29", "2024/01/01", "2024-01-01T00:00:00", " 2024-01-01"],
    fromJSON: (json) => LocalDate.fromJSON(json),
  },
  {
    name: "LocalTime",
    schema: NodaZ.LocalTime,
    expected: `a LocalTime string in the format ${LocalTimePattern.ExtendedIso.PatternText}`,
    valid: [
      ["12:34:56", new LocalTime(12, 34, 56)],
      ["23:59:59.999", new LocalTime(23, 59, 59, 999)],
      ["00:00:00.000000001", LocalTime.Midnight.PlusNanoseconds(1)],
    ],
    invalid: ["24:00:00", "12:34", "noon"],
    fromJSON: (json) => LocalTime.fromJSON(json),
  },
  {
    name: "LocalDateTime",
    schema: NodaZ.LocalDateTime,
    expected: `a LocalDateTime string in the format ${LocalDateTimePattern.ExtendedIso.PatternText}`,
    valid: [
      ["2024-01-31T12:34:56", new LocalDateTime(2024, 1, 31, 12, 34, 56)],
      ["2024-01-31T12:34:56.5", new LocalDateTime(2024, 1, 31, 12, 34, 56, 500)],
    ],
    invalid: ["2024-01-31T12:34:56Z", "2024-01-31 12:34:56", "2024-01-31"],
    fromJSON: (json) => LocalDateTime.fromJSON(json),
  },
  {
    name: "OffsetDateTime",
    schema: NodaZ.OffsetDateTime,
    expected: `an OffsetDateTime string in the format ${OffsetDateTimePattern.Rfc3339.PatternText}`,
    valid: [
      ["2024-01-31T12:34:56+05:30", new LocalDateTime(2024, 1, 31, 12, 34, 56).WithOffset(Offset.FromHoursAndMinutes(5, 30))],
      ["2024-01-31T12:34:56Z", new LocalDateTime(2024, 1, 31, 12, 34, 56).WithOffset(Offset.Zero)],
      ["2024-01-31T12:34:56.25-08:00", new LocalDateTime(2024, 1, 31, 12, 34, 56, 250).WithOffset(Offset.FromHours(-8))],
    ],
    invalid: ["2024-01-31T12:34:56", "2024-01-31T12:34:56+05", "2024-01-31T12:34:56 Europe/Paris"],
    fromJSON: (json) => OffsetDateTime.fromJSON(json),
  },
  {
    name: "OffsetDate",
    schema: NodaZ.OffsetDate,
    expected: `an OffsetDate string in the format ${OffsetDatePattern.GeneralIso.PatternText}`,
    valid: [
      ["2024-01-31+05:30", new OffsetDate(new LocalDate(2024, 1, 31), Offset.FromHoursAndMinutes(5, 30))],
      ["2024-01-31Z", new OffsetDate(new LocalDate(2024, 1, 31), Offset.Zero)],
    ],
    invalid: ["2024-01-31", "2024-01-31+25"],
    fromJSON: (json) => OffsetDate.fromJSON(json),
  },
  {
    name: "OffsetTime",
    schema: NodaZ.OffsetTime,
    expected: `an OffsetTime string in the format ${OffsetTimePattern.ExtendedIso.PatternText}`,
    valid: [
      ["12:34:56+01", new OffsetTime(new LocalTime(12, 34, 56), Offset.FromHours(1))],
      ["12:34:56.789Z", new OffsetTime(new LocalTime(12, 34, 56, 789), Offset.Zero)],
    ],
    invalid: ["12:34:56", "12:34:56 +01"],
    fromJSON: (json) => OffsetTime.fromJSON(json),
  },
  {
    name: "Offset",
    schema: NodaZ.Offset,
    expected: `an Offset string in the format ${OffsetPattern.GeneralInvariant.PatternText} (+HH:mm:ss, +HH:mm or +HH)`,
    valid: [
      ["+05:30", Offset.FromHoursAndMinutes(5, 30)],
      ["-08", Offset.FromHours(-8)],
      ["+00", Offset.Zero],
      ["+01:02:03", Offset.FromSeconds(3723)],
      ["+05:00", Offset.FromHours(5), "+05"],
    ],
    invalid: ["Z", "+25", "05:30", "+5"],
    fromJSON: (json) => Offset.fromJSON(json),
  },
  {
    name: "Duration",
    schema: NodaZ.Duration,
    expected: `a Duration string in the format ${DurationPattern.JsonRoundtrip.PatternText}`,
    valid: [
      ["1:02:03", Duration.FromHours(1).Plus(Duration.FromMinutes(2)).Plus(Duration.FromSeconds(3))],
      ["48:00:00", Duration.FromDays(2)],
      ["-0:00:01.5", Duration.FromMilliseconds(-1500)],
      ["0:00:00", Duration.Zero],
    ],
    invalid: ["1:02:03:04", "PT1H", "1.02:03:04", "abc"],
    fromJSON: (json) => Duration.fromJSON(json),
  },
  {
    name: "Period",
    schema: NodaZ.Period,
    expected:
      "a Period string in the format P{years}Y{months}M{weeks}W{days}DT{hours}H{minutes}M{seconds}S{milliseconds}s{ticks}t{nanoseconds}n " +
      "(PeriodPattern.Roundtrip; every unit is optional)",
    valid: [
      ["P1Y2M3DT4H", Period.Add(Period.Add(Period.FromYears(1), Period.FromMonths(2)), Period.Add(Period.FromDays(3), Period.FromHours(4)))],
      ["P0D", Period.Zero],
      ["P-2W", Period.FromWeeks(-2)],
      ["PT5s", Period.FromMilliseconds(5)],
    ],
    invalid: ["P1X", "1Y", "P1M1Y", "P1H", ""],
    fromJSON: (json) => Period.fromJSON(json),
  },
  {
    name: "YearMonth",
    schema: NodaZ.YearMonth,
    expected: `a YearMonth string in the format ${YearMonthPattern.Iso.PatternText}`,
    valid: [["2024-02", new YearMonth(2024, 2)]],
    invalid: ["2024-13", "2024-02-01", "202402"],
    fromJSON: (json) => YearMonth.fromJSON(json),
  },
  {
    name: "AnnualDate",
    schema: NodaZ.AnnualDate,
    expected: `an AnnualDate string in the format ${AnnualDatePattern.Iso.PatternText}`,
    valid: [
      ["02-29", new AnnualDate(2, 29)],
      ["12-31", new AnnualDate(12, 31)],
    ],
    invalid: ["02-30", "2-29", "--02-29"],
    fromJSON: (json) => AnnualDate.fromJSON(json),
  },
  {
    name: "ZonedDateTime(tzdb)",
    schema: NodaZ.ZonedDateTime(tzdb),
    expected: "a ZonedDateTime string in the format uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z",
    valid: [
      ["2024-01-31T12:00:00+01 Europe/Paris", new LocalDateTime(2024, 1, 31, 12, 0).InZoneStrictly(paris)],
      ["2024-07-31T12:00:00.5+02 Europe/Paris", new LocalDateTime(2024, 7, 31, 12, 0, 0, 500).InZoneStrictly(paris)],
      ["2024-01-31T12:00:00Z UTC", Instant.FromUtc(2024, 1, 31, 12, 0).InUtc()],
    ],
    // An unknown zone, an offset the zone doesn't have then, no zone.
    invalid: ["2024-01-31T12:00:00+01 Nowhere/Special", "2024-01-31T12:00:00+02 Europe/Paris", "2024-01-31T12:00:00+01"],
    fromJSON: (json) => ZonedDateTime.fromJSON(json, tzdb),
  },
];

/** Wrong-typed inputs, and the type the message names. */
const wrongTypes: Array<[input: unknown, received: string]> = [
  [42, "number"],
  [null, "null"],
  [undefined, "undefined"],
  [{}, "object"],
  [[], "array"],
  [true, "boolean"],
];

/** The message the core's fromJSON throws for the JSON. */
function coreMessage(fromJSON: () => unknown): string {
  try {
    fromJSON();
  } catch (error) {
    return (error as Error).message;
  }
  throw new Error("Expected the core's fromJSON to throw");
}

/** safeParse, checking it fails with exactly one issue, which it returns. */
function singleIssue(schema: z.ZodType, input: unknown): z.core.$ZodIssue {
  let result: ReturnType<z.ZodType["safeParse"]> | undefined;
  expect(() => (result = schema.safeParse(input))).not.toThrow();
  expect(result!.success).toBe(false);
  const issues = result!.error!.issues;
  expect(issues).toHaveLength(1);
  return issues[0]!;
}

describe.each(textCases)("NodaZ.$name", ({ schema, expected, valid, invalid, fromJSON }) => {
  it.each(valid)("parses %j", (json, value) => {
    const parsed = schema.parse(json);
    expect(parsed.Equals(value)).toBe(true);
    expect(schema.safeParse(json)).toEqual({ success: true, data: parsed });
  });

  it.each(valid)("encodes the value of %j", (json, value, encoded = json) => {
    expect(schema.encode(value)).toBe(encoded);
    expect(schema.parse(schema.encode(value)).Equals(value)).toBe(true);
  });

  it.each(invalid)("reports the core's parse message for %j", (json) => {
    const issue = singleIssue(schema, json);
    expect(issue.message).toBe(coreMessage(() => fromJSON(json)));
    expect(issue.code).toBe("invalid_format");
    expect(issue.path).toEqual([]);
    expect(issue.message).not.toMatch(/e\.g\./);
  });

  it.each(wrongTypes)("reports the expected format for %j", (input, received) => {
    const issue = singleIssue(schema, input);
    expect(issue.message).toBe(`Expected ${expected}, but received ${received}`);
    expect(issue).toMatchObject({ code: "invalid_type", expected: "string", path: [] });
  });

  it("throws a ZodError from parse", () => {
    expect(() => schema.parse(42)).toThrow(`Expected ${expected}, but received number`);
  });
});

describe("invalid_format issues", () => {
  it("name the type and its pattern", () => {
    const issue = singleIssue(NodaZ.Instant, "2024-13-01T00:00:00Z");
    expect(issue).toMatchObject({ code: "invalid_format", format: "Instant", pattern: InstantPattern.ExtendedIso.PatternText });
  });

  it("have no pattern for Period (PeriodPattern.Roundtrip has no pattern text)", () => {
    const issue = singleIssue(NodaZ.Period, "P1X");
    expect(issue).toMatchObject({ code: "invalid_format", format: "Period" });
    expect(issue).not.toHaveProperty("pattern");
  });
});

describe("NodaZ.DateTimeZone(tzdb)", () => {
  const schema = NodaZ.DateTimeZone(tzdb);

  it.each(["Europe/London", "UTC", "America/Argentina/Buenos_Aires"])("parses %j", (id) => {
    expect(schema.parse(id)).toBe(tzdb.Get(id));
    expect(schema.encode(tzdb.Get(id))).toBe(id);
  });

  it.each(["Nowhere/Special", "", "europe/london"])("reports the provider's message for %j", (id) => {
    const issue = singleIssue(schema, id);
    expect(issue.message).toBe(coreMessage(() => tzdb.Get(id)));
    expect(issue).toMatchObject({ code: "invalid_format", format: "DateTimeZone", path: [] });
  });

  it.each(wrongTypes)("reports the expected format for %j", (input, received) => {
    const issue = singleIssue(schema, input);
    expect(issue.message).toBe(`Expected a DateTimeZone ID string (one of the provider's Ids), but received ${received}`);
  });
});

interface BoundsCase {
  name: string;
  schema: z.ZodType<NodaValue, unknown>;
  expected: string;
  boundExpected: string;
  valid: Array<[json: object, value: NodaValue, encoded?: object]>;
  /** Objects whose bound at `path` the core rejects, with the bound's text. */
  invalidBound: Array<[json: object, path: string, text: string]>;
  boundFromJSON: (json: string) => unknown;
  /** A valid end, to test the start with. */
  validEnd: string;
}

const instant1 = Instant.FromUtc(2024, 1, 1, 0, 0);
const instant2 = Instant.FromUtc(2024, 12, 31, 23, 59).PlusNanoseconds(1);

const boundsCases: BoundsCase[] = [
  {
    name: "Interval",
    schema: NodaZ.Interval,
    expected: `an Interval object with optional start and end properties, each an Instant string in the format ${instantFormat()}`,
    boundExpected: `an Instant string in the format ${instantFormat()}`,
    valid: [
      [{ start: "2024-01-01T00:00:00Z", end: "2024-12-31T23:59:00.000000001Z" }, new Interval(instant1, instant2)],
      [{ start: "2024-01-01T00:00:00Z" }, new Interval(instant1, null)],
      [{ end: "2024-01-01T00:00:00Z" }, new Interval(null, instant1)],
      [{}, new Interval(null, null)],
      // Property names are case-insensitive (NodaTime writes Start/End without a naming policy); others are ignored.
      [{ Start: "2024-01-01T00:00:00Z", END: "2024-01-01T00:00:00Z", other: 1 }, new Interval(instant1, instant1), { start: "2024-01-01T00:00:00Z", end: "2024-01-01T00:00:00Z" }],
    ],
    invalidBound: [
      [{ start: "2024-01-01", end: "2024-01-02T00:00:00Z" }, "start", "2024-01-01"],
      [{ Start: "2024-01-01T00:00:00Z", End: "tomorrow" }, "End", "tomorrow"],
    ],
    boundFromJSON: (json) => Instant.fromJSON(json),
    validEnd: "2024-01-01T00:00:00Z",
  },
  {
    name: "DateInterval",
    schema: NodaZ.DateInterval,
    expected: `a DateInterval object with start and end properties, each a LocalDate string in the format ${localDateFormat()}`,
    boundExpected: `a LocalDate string in the format ${localDateFormat()}`,
    valid: [
      [{ start: "2024-01-01", end: "2024-12-31" }, new DateInterval(new LocalDate(2024, 1, 1), new LocalDate(2024, 12, 31))],
      [{ start: "2024-01-01", end: "2024-01-01" }, new DateInterval(new LocalDate(2024, 1, 1), new LocalDate(2024, 1, 1))],
      [{ Start: "2024-01-01", End: "2024-01-02" }, new DateInterval(new LocalDate(2024, 1, 1), new LocalDate(2024, 1, 2)), { start: "2024-01-01", end: "2024-01-02" }],
    ],
    invalidBound: [
      [{ start: "2024-02-30", end: "2024-03-01" }, "start", "2024-02-30"],
      [{ start: "2024-01-01", End: "2024-01-01T00:00:00" }, "End", "2024-01-01T00:00:00"],
    ],
    boundFromJSON: (json) => LocalDate.fromJSON(json),
    validEnd: "2024-01-01",
  },
];

const wrongObjectTypes: Array<[input: unknown, received: string]> = [
  [42, "number"],
  [null, "null"],
  [undefined, "undefined"],
  ["2024-01-01", "string"],
  [[], "array"],
  [false, "boolean"],
];

describe.each(boundsCases)("NodaZ.$name", ({ schema, expected, boundExpected, valid, validEnd, invalidBound, boundFromJSON }) => {
  it.each(valid)("parses %j", (json, value) => {
    expect(schema.parse(json).Equals(value)).toBe(true);
  });

  it.each(valid)("encodes the value of %j", (json, value, encoded = json) => {
    expect(schema.encode(value)).toEqual(encoded);
    expect(schema.parse(schema.encode(value)).Equals(value)).toBe(true);
  });

  it.each(wrongObjectTypes)("reports the expected format for %j", (input, received) => {
    const issue = singleIssue(schema, input);
    expect(issue.message).toBe(`Expected ${expected}, but received ${received}`);
    expect(issue).toMatchObject({ code: "invalid_type", expected: "object", path: [] });
  });

  it.each(invalidBound)("reports the core's parse message for %j at its property", (json, path, text) => {
    const issue = singleIssue(schema, json);
    expect(issue.message).toBe(coreMessage(() => boundFromJSON(text)));
    expect(issue).toMatchObject({ code: "invalid_format", path: [path] });
  });

  it.each(wrongTypes.filter(([input]) => input !== undefined))("reports the expected format of a bound that is %j", (input, received) => {
    const issue = singleIssue(schema, { start: input, end: validEnd });
    expect(issue.message).toBe(`Expected ${boundExpected}, but received ${received}`);
    expect(issue).toMatchObject({ code: "invalid_type", expected: "string", path: ["start"] });
  });

  it("reports every bad bound", () => {
    const result = schema.safeParse({ start: 1, end: "x" });
    expect(result.success).toBe(false);
    expect(result.error!.issues.map((issue) => issue.path)).toEqual([["start"], ["end"]]);
  });
});

describe("NodaZ.DateInterval", () => {
  it.each([
    [{ start: "2024-01-01" }, ["end"]],
    [{ end: "2024-01-01" }, ["start"]],
    [{}, ["start", "end"]],
  ])("reports missing properties of %j", (json, missing) => {
    const result = NodaZ.DateInterval.safeParse(json);
    expect(result.success).toBe(false);
    expect(result.error!.issues).toEqual(
      missing.map((key) => expect.objectContaining({
        code: "invalid_type",
        path: [key],
        message: `Expected a LocalDate string in the format ${localDateFormat()}, but received undefined`,
      })),
    );
  });

  it("reports the core's message for an end before the start", () => {
    const json = { start: "2024-02-01", end: "2024-01-01" };
    const issue = singleIssue(NodaZ.DateInterval, json);
    expect(issue.message).toBe(coreMessage(() => DateInterval.fromJSON(json)));
    expect(issue).toMatchObject({ code: "custom", path: [] });
  });
});
