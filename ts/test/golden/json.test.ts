/// <reference types="vite/client" />
// Golden JSON from NodaTime.Serialization.SystemTextJson, in every calendar: fromJSON must read each value back.

import { beforeAll, describe, expect, it } from "vitest";
import {
  CalendarSystem,
  DateInterval,
  DateTimeZone,
  LocalDate,
  LocalDateTime,
  OffsetDate,
  OffsetDateTime,
  YearMonth,
  ZonedDateTime,
  type IDateTimeZoneProvider,
} from "../../src/noda-js/internal.ts";
import * as noda from "../../src/noda-js/internal.ts";
import { decode, loadTzdbProvider, windowsProvider } from "../helpers/decode.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import type { JsonGolden, JsonGoldenProperty } from "./types.ts";

const files = import.meta.glob<JsonGolden>("./json/*.generated.ts", { import: "golden", eager: true });

/** The types whose JSON depends on the calendar, and how each reads it with a calendar. */
const withCalendar: Record<string, (json: unknown, calendar: CalendarSystem) => { readonly Calendar: CalendarSystem }> = {
  LocalDate: (json, calendar) => LocalDate.fromJSON(json as string, calendar),
  LocalDateTime: (json, calendar) => LocalDateTime.fromJSON(json as string, calendar),
  OffsetDate: (json, calendar) => OffsetDate.fromJSON(json as string, calendar),
  OffsetDateTime: (json, calendar) => OffsetDateTime.fromJSON(json as string, calendar),
  YearMonth: (json, calendar) => YearMonth.fromJSON(json as string, calendar),
  DateInterval: (json, calendar) => DateInterval.fromJSON(json, calendar),
};

it("covers every calendar system", () => {
  expect(Object.values(files).map(g => g.calendar).sort()).toEqual([...CalendarSystem.Ids].sort());
});

for (const golden of Object.values(files)) {
  describe(`JSON [${golden.calendar}]`, () => {
    const calendar = CalendarSystem.ForId(golden.calendar);
    const isIso = calendar === CalendarSystem.Iso;
    const json = JSON.parse(golden.json) as Record<string, unknown>;
    let tzdb: IDateTimeZoneProvider;
    beforeAll(async () => {
      tzdb = await loadTzdbProvider();
    });

    it("has one property per value, in order", () => {
      expect(Object.keys(json)).toEqual(golden.properties.map(p => p.name));
    });

    for (const property of golden.properties) {
      const how = property.type in withCalendar || property.type === "ZonedDateTime"
        ? (isIso ? "with no calendar (ISO)" : `with the ${golden.calendar} calendar`)
        : "";
      it(`${property.name}: ${property.type}.fromJSON ${how}`.trimEnd(), () => {
        const actual = read(property, json[property.name], isIso ? undefined : calendar);
        assertNodaEqual(actual, decode(property.value));
        if (property.type in withCalendar || property.type === "ZonedDateTime") {
          expect((actual as { Calendar: CalendarSystem }).Calendar).toBe(calendar);
        }
      });
    }

    function read(property: JsonGoldenProperty, value: unknown, calendar: CalendarSystem | undefined): unknown {
      const provider = property.name.startsWith("Bcl") ? windowsProvider() : tzdb;
      switch (property.type) {
        case "ZonedDateTime":
          return ZonedDateTime.fromJSON(value as string, provider, calendar);
        case "DateTimeZone":
          return DateTimeZone.fromJSON(value as string, provider);
      }
      if (calendar !== undefined && property.type in withCalendar) {
        return withCalendar[property.type]!(value, calendar);
      }
      return (noda as unknown as Record<string, { fromJSON(json: unknown): unknown }>)[property.type]!.fromJSON(value);
    }
  });
}
