// noda-js-zod in use: the default and named exports, schemas inside z.object (issue paths), optional fields,
// encode errors, and the schemas that take a time zone provider.

import { describe, expect, expectTypeOf, it } from "vitest";
import * as z from "zod";
import {
  ArgumentNullError, DateTimeZone, Instant, InstantPattern, Interval, LocalDate, NodaConstants, Period, ZonedDateTime,
} from "noda-js";
import { tzdb } from "noda-js/tzdb/bundled";
import NodaZ, { NodaZ as NamedNodaZ } from "../../src/noda-js-zod/index.ts";

const instantExpected = `an Instant string in the format ${InstantPattern.ExtendedIso.PatternText}`;

describe("exports", () => {
  it("default and named NodaZ are the same namespace", () => {
    expect(NamedNodaZ).toBe(NodaZ);
  });

  it("has a schema for every type with toJSON/fromJSON", () => {
    expect(Object.keys(NodaZ).sort()).toEqual([
      "AnnualDate", "DateInterval", "DateTimeZone", "Duration", "Instant", "Interval", "LocalDate", "LocalDateTime",
      "LocalTime", "Offset", "OffsetDate", "OffsetDateTime", "OffsetTime", "Period", "YearMonth", "ZonedDateTime",
    ]);
  });

  it("types parse's output and encode's input as the noda-js type", () => {
    expectTypeOf(NodaZ.Instant.parse).returns.toEqualTypeOf<Instant>();
    expectTypeOf<z.input<typeof NodaZ.Instant>>().toEqualTypeOf<string>();
    expectTypeOf<z.output<typeof NodaZ.Instant>>().toEqualTypeOf<Instant>();
    expectTypeOf(NodaZ.ZonedDateTime(tzdb).parse).returns.toEqualTypeOf<ZonedDateTime>();
    expectTypeOf(NodaZ.Interval.encode).returns.toEqualTypeOf<{ start?: string; end?: string }>();
  });
});

describe("inside z.object", () => {
  const Booking = z.object({
    id: z.number(),
    at: NodaZ.Instant,
    nights: z.array(NodaZ.LocalDate),
    stay: NodaZ.DateInterval,
    length: NodaZ.Period.optional(),
    zone: NodaZ.DateTimeZone(tzdb),
  });

  const json = {
    id: 1,
    at: "2024-01-31T12:00:00Z",
    nights: ["2024-02-01", "2024-02-02"],
    stay: { start: "2024-02-01", end: "2024-02-03" },
    zone: "Europe/Paris",
  };

  it("decodes each field", () => {
    const booking = Booking.parse(json);
    expect(booking.at.Equals(Instant.FromUtc(2024, 1, 31, 12, 0))).toBe(true);
    expect(booking.nights[1]!.Equals(new LocalDate(2024, 2, 2))).toBe(true);
    expect(booking.stay.Length).toBe(3);
    expect(booking.length).toBeUndefined();
    expect(booking.zone).toBe(tzdb.Get("Europe/Paris"));
    expectTypeOf(booking.length).toEqualTypeOf<Period | undefined>();
  });

  it("encodes back to the JSON", () => {
    expect(Booking.encode(Booking.parse(json))).toEqual(json);
    const withLength = { ...json, length: "P2D" };
    expect(Booking.encode(Booking.parse(withLength))).toEqual(withLength);
  });

  it("reports each bad field at its path", () => {
    const result = Booking.safeParse({
      id: 1,
      at: 1706702400000,
      nights: ["2024-02-01", "2024-02-30"],
      stay: { start: "2024-02-01" },
      length: null,
      zone: "Mars/Olympus_Mons",
    });
    expect(result.success).toBe(false);
    expect(result.error!.issues.map(({ path, message }) => ({ path, message }))).toEqual([
      { path: ["at"], message: `Expected ${instantExpected}, but received number` },
      { path: ["nights", 1], message: "The day 30 is out of range in month 2 of year 2024. Value being parsed: '2024-02-30'." },
      { path: ["stay", "end"], message: `Expected a LocalDate string in the format uuuu'-'MM'-'dd, but received undefined` },
      { path: ["length"], message: expect.stringMatching(/^Expected a Period string in the format P\{years\}Y.*, but received null$/) },
      { path: ["zone"], message: expect.stringMatching(/^Time zone Mars\/Olympus_Mons is unknown to source TZDB/) },
    ]);
  });

  it("reports a missing field", () => {
    const { at: _, ...missing } = json;
    const result = Booking.safeParse(missing);
    expect(result.error!.issues).toEqual([
      expect.objectContaining({ path: ["at"], code: "invalid_type", message: `Expected ${instantExpected}, but received undefined` }),
    ]);
  });

  it("formats with z.prettifyError", () => {
    const result = z.object({ when: NodaZ.Instant }).safeParse({ when: "yesterday" });
    expect(z.prettifyError(result.error!)).toBe(
      "✖ The value string does not match the required number from the format string \"uuuu\". Value being parsed: '^yesterday'. (^ indicates error position.)\n  → at when",
    );
  });
});

describe("safeParse never throws", () => {
  const inputs: unknown[] = [
    42, NaN, -0, Infinity, 10n, null, undefined, true, "", " ", "\u0000", "x".repeat(10000), {}, [], [1, 2], { start: {} },
    Symbol("s"), () => "2024-01-01T00:00:00Z", new Date(0), NodaConstants.UnixEpoch, Object.create(null), { toString: () => "x" },
  ];
  const schemas: Array<[string, z.ZodType]> = [
    ...(Object.entries(NodaZ) as Array<[string, unknown]>)
      .filter((entry): entry is [string, z.ZodType] => typeof entry[1] !== "function"),
    ["ZonedDateTime(tzdb)", NodaZ.ZonedDateTime(tzdb)],
    ["DateTimeZone(tzdb)", NodaZ.DateTimeZone(tzdb)],
  ];

  it.each(schemas)("NodaZ.%s", (name, schema) => {
    for (const input of inputs) {
      let result: ReturnType<z.ZodType["safeParse"]> | undefined;
      expect(() => (result = schema.safeParse(input))).not.toThrow();
      // Like the core's Interval.fromJSON, NodaZ.Interval reads an object without start or end properties as an
      // interval that is unbounded both ways.
      const unboundedInterval = name === "Interval" && typeof input === "object" && input !== null && !Array.isArray(input)
        && !Object.keys(input).some((key) => /^(start|end)$/i.test(key));
      expect(result!.success).toBe(unboundedInterval);
      for (const issue of result!.error?.issues ?? []) {
        expect(issue.message.length).toBeGreaterThan(0);
        expect(issue.message).not.toMatch(/e\.g\./);
      }
    }
  });
});

describe("encode", () => {
  it("rejects a value of the wrong type with a zod error", () => {
    // @ts-expect-error -- encode takes an Instant.
    expect(() => NodaZ.Instant.encode("2024-01-31T12:00:00Z")).toThrow("Expected an Instant value, but received string");
    // @ts-expect-error -- encode takes an Instant.
    const result = NodaZ.Instant.safeEncode(LocalDate.MinIsoValue);
    expect(result.error!.issues).toEqual([expect.objectContaining({ code: "custom", message: "Expected an Instant value, but received object" })]);
  });

  it("writes NodaTime's JSON", () => {
    expect(NodaZ.Interval.encode(new Interval(NodaConstants.UnixEpoch, null))).toEqual({ start: "1970-01-01T00:00:00Z" });
    expect(NodaZ.ZonedDateTime(tzdb).encode(NodaConstants.UnixEpoch.InZone(tzdb.Get("Asia/Kolkata")))).toBe("1970-01-01T05:30:00+05:30 Asia/Kolkata");
    expect(NodaZ.DateTimeZone(tzdb).encode(DateTimeZone.Utc)).toBe("UTC");
  });
});

describe("provider schemas", () => {
  it.each([null, undefined])("throw for a %s provider", (provider) => {
    // @ts-expect-error -- a provider is required.
    expect(() => NodaZ.ZonedDateTime(provider)).toThrow(ArgumentNullError);
    // @ts-expect-error -- a provider is required.
    expect(() => NodaZ.DateTimeZone(provider)).toThrow(ArgumentNullError);
  });

  it("resolve zones with the given provider", () => {
    const zone = tzdb.Get("Europe/London");
    const provider = {
      VersionId: "test",
      Ids: ["Test/Zone"],
      GetSystemDefault: () => zone,
      GetZoneOrNull: (id: string) => (id === "Test/Zone" ? zone : null),
      Get: (id: string) => {
        if (id !== "Test/Zone") {
          throw new Error(`No zone ${id}`);
        }
        return zone;
      },
    };
    expect(NodaZ.DateTimeZone(provider).parse("Test/Zone")).toBe(zone);
    expect(NodaZ.DateTimeZone(provider).safeParse("Europe/London").error!.issues[0]!.message).toBe("No zone Europe/London");
  });
});
