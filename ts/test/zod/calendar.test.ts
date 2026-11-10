// noda-js-zod's .WithCalendar, and the golden JSON in the ISO, Julian and Coptic calendars.

import { describe, expect, it } from "vitest";
import * as z from "zod";
import { CalendarSystem, LocalDate } from "noda-js";
import { tzdb } from "noda-js/tzdb/bundled";
import NodaZ from "../../src/noda-js-zod/index.ts";
import { decode, loadTzdbProvider, windowsProvider } from "../helpers/decode.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import type { JsonGolden } from "../golden/types.ts";

const coptic = CalendarSystem.Coptic;
const julian = CalendarSystem.Julian;
const leapDay = new LocalDate(2024, 2, 29);

describe("WithCalendar", () => {
  it("leaves the default schemas in the ISO calendar", () => {
    expect(NodaZ.LocalDate.parse("2024-02-29").Calendar).toBe(CalendarSystem.Iso);
    expect(NodaZ.YearMonth.parse("2024-02").Calendar).toBe(CalendarSystem.Iso);
    expect(NodaZ.ZonedDateTime(tzdb).parse("2024-02-29T12:00:00Z UTC").Calendar).toBe(CalendarSystem.Iso);
  });

  it("returns a new schema that reads values in the calendar, and leaves the original unchanged", () => {
    const copticDate = NodaZ.LocalDate.WithCalendar(coptic);
    expect(copticDate).not.toBe(NodaZ.LocalDate);
    const value = copticDate.parse("1740-06-21");
    expect(value.Calendar).toBe(coptic);
    expect(value.Equals(leapDay.WithCalendar(coptic))).toBe(true);
    expect(copticDate.encode(value)).toBe("1740-06-21");
    // The original still reads ISO dates.
    expect(NodaZ.LocalDate.parse("1740-06-21").Calendar).toBe(CalendarSystem.Iso);
  });

  it("chains: the last calendar wins", () => {
    expect(NodaZ.LocalDate.WithCalendar(julian).WithCalendar(coptic).parse("1740-06-21").Calendar).toBe(coptic);
  });

  it("covers every type with a calendar", () => {
    const zoned = NodaZ.ZonedDateTime(tzdb).WithCalendar(julian).parse("2024-02-16T12:00:00Z UTC");
    expect(zoned.Calendar).toBe(julian);
    expect(zoned.ToInstant().Equals(leapDay.At(zoned.TimeOfDay).InUtc().ToInstant())).toBe(true);
    expect(NodaZ.LocalDateTime.WithCalendar(julian).parse("2024-02-16T12:00:00").Calendar).toBe(julian);
    expect(NodaZ.OffsetDate.WithCalendar(julian).parse("2024-02-16+01").Calendar).toBe(julian);
    expect(NodaZ.OffsetDateTime.WithCalendar(julian).parse("2024-02-16T12:00:00+01:00").Calendar).toBe(julian);
    expect(NodaZ.YearMonth.WithCalendar(coptic).parse("1740-06").Calendar).toBe(coptic);
    const interval = NodaZ.DateInterval.WithCalendar(coptic).parse({ start: "1740-06-21", end: "1740-07-01" });
    expect(interval.Calendar).toBe(coptic);
    expect(interval.Length).toBe(11);
  });

  it("checks values against the calendar, and says which calendar in its messages", () => {
    // Coptic month 13 has 5 days (6 in a leap year); 1740 isn't a Coptic leap year.
    const result = NodaZ.LocalDate.WithCalendar(coptic).safeParse("1740-13-06");
    expect(result.success).toBe(false);
    expect(result.error!.issues[0]!.code).toBe("invalid_format");
    const wrongType = NodaZ.LocalDate.WithCalendar(coptic).safeParse(42);
    expect(wrongType.error!.issues[0]!.message).toBe(
      "Expected a LocalDate string in the format uuuu'-'MM'-'dd, in the Coptic calendar, but received number",
    );
    const missingEnd = NodaZ.DateInterval.WithCalendar(coptic).safeParse({ start: "1740-06-21" });
    expect(missingEnd.error!.issues[0]!.message).toContain("in the Coptic calendar");
  });

  it("requires a calendar", () => {
    expect(() => NodaZ.LocalDate.WithCalendar(null as unknown as CalendarSystem)).toThrowNodaError("ArgumentNullException");
  });

  it("isn't an enumerable property, so the schema looks like any other zod schema", () => {
    expect(Object.keys(NodaZ.LocalDate)).not.toContain("WithCalendar");
  });
});

const goldens = import.meta.glob<JsonGolden>("../golden/json/*.generated.ts", { import: "golden", eager: true });

describe("golden JSON from NodaTime.Serialization.SystemTextJson, as one zod object", () => {
  for (const golden of Object.values(goldens)) {
    it(`parses the ${golden.calendar} object to the values NodaTime serialized`, async () => {
      const calendar = CalendarSystem.ForId(golden.calendar);
      const tzdbProvider = await loadTzdbProvider();
      const windows = windowsProvider();
      const inCalendar = <S extends { WithCalendar(calendar: CalendarSystem): S }>(schema: S): S =>
        calendar === CalendarSystem.Iso ? schema : schema.WithCalendar(calendar);
      const schema = z.object({
        Instant: NodaZ.Instant,
        LocalDate: inCalendar(NodaZ.LocalDate),
        LocalTime: NodaZ.LocalTime,
        LocalDateTime: inCalendar(NodaZ.LocalDateTime),
        AnnualDate: NodaZ.AnnualDate,
        YearMonth: inCalendar(NodaZ.YearMonth),
        Offset: NodaZ.Offset,
        OffsetDate: inCalendar(NodaZ.OffsetDate),
        OffsetTime: NodaZ.OffsetTime,
        OffsetDateTime: inCalendar(NodaZ.OffsetDateTime),
        TzdbZonedDateTime: inCalendar(NodaZ.ZonedDateTime(tzdbProvider)),
        BclZonedDateTime: inCalendar(NodaZ.ZonedDateTime(windows)),
        TzdbZone: NodaZ.DateTimeZone(tzdbProvider),
        BclZone: NodaZ.DateTimeZone(windows),
        Duration: NodaZ.Duration,
        Period: NodaZ.Period,
        Interval: NodaZ.Interval,
        DateInterval: inCalendar(NodaZ.DateInterval),
      });
      const parsed = schema.parse(JSON.parse(golden.json)) as Record<string, unknown>;
      expect(Object.keys(parsed)).toEqual(golden.properties.map(p => p.name));
      for (const property of golden.properties) {
        assertNodaEqual(parsed[property.name], decode(property.value), property.name);
      }
    });
  }
});
