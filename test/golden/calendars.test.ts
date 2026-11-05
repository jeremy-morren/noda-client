/// <reference types="vite/client" />
// Golden calendar data from NodaTime (tools/NodaJs.Tools data golden): for every year of every calendar system, whether
// it's a leap year, its length, and each month's length and start. Every year and every month of each calendar must
// match: the year-level answers (public API and the calculator), the start of each year, and both directions of the
// conversion between days since the epoch and year/month/day at the first and last day of each month.
// This stands in for NodaTime's tests that compare its calendars with the BCL's day by day (BclThroughHistory and the
// like), which can't run here: those prove NodaTime matches the BCL, and this proves noda-js matches NodaTime.

import { describe, expect, it } from "vitest";
import { CalendarSystem, YearMonthDay } from "../../src/noda-js/internal.ts";
import type { CalendarGolden } from "./types.ts";

const files = import.meta.glob<CalendarGolden>("./calendars/*.generated.ts", { import: "golden", eager: true });
const goldens = Object.values(files).sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));

// Each check collects mismatches rather than asserting per value (there are millions of values); the test then shows
// the first few.
const MaxReported = 10;

function Check(mismatches: string[], what: string, actual: unknown, expected: unknown): void {
  if (actual !== expected && mismatches.length < MaxReported) {
    mismatches.push(`${what}: ${String(actual)}, expected ${String(expected)}`);
  }
}

function Describe(ymd: YearMonthDay): string {
  return `${ymd.Year}-${ymd.Month}-${ymd.Day}`;
}

it("covers every calendar system", () => {
  expect(goldens.map(g => g.id)).toEqual([...CalendarSystem.Ids].sort());
});

describe.each(goldens)("$id", golden => {
  const calendar = (): CalendarSystem => CalendarSystem.ForId(golden.id);

  it("has the same range of years and days", () => {
    expect({ MinYear: calendar().MinYear, MaxYear: calendar().MaxYear, MinDays: calendar().MinDays, MaxDays: calendar().MaxDays })
      .toEqual({ MinYear: golden.minYear, MaxYear: golden.maxYear, MinDays: golden.minDays, MaxDays: golden.maxDays });
  });

  it("agrees on every year: leap year, days, months, month lengths and the start of the year", () => {
    const cal = calendar();
    const calculator = cal.YearMonthDayCalculator;
    const mismatches: string[] = [];
    let startOfYear = golden.minDays;
    for (let year = golden.minYear; year <= golden.maxYear; year++) {
      const type = golden.yearTypes[golden.years[year - golden.minYear]!]!;
      Check(mismatches, `IsLeapYear(${year})`, cal.IsLeapYear(year), type.leap);
      Check(mismatches, `GetDaysInYear(${year})`, cal.GetDaysInYear(year), type.days);
      Check(mismatches, `GetMonthsInYear(${year})`, cal.GetMonthsInYear(year), type.monthLengths.length);
      Check(mismatches, `GetStartOfYearInDays(${year})`, calculator.GetStartOfYearInDays(year), startOfYear);
      for (let month = 1; month <= type.monthLengths.length; month++) {
        Check(mismatches, `GetDaysInMonth(${year}, ${month})`, cal.GetDaysInMonth(year, month), type.monthLengths[month - 1]);
      }
      startOfYear += type.days;
    }
    Check(mismatches, "the day after the last year", startOfYear - 1, golden.maxDays);
    expect(mismatches).toEqual([]);
  });

  it("converts the first and last day of every month to days since the epoch and back", () => {
    const cal = calendar();
    const calculator = cal.YearMonthDayCalculator;
    const mismatches: string[] = [];
    let startOfYear = golden.minDays;
    for (let year = golden.minYear; year <= golden.maxYear; year++) {
      const type = golden.yearTypes[golden.years[year - golden.minYear]!]!;
      for (let month = 1; month <= type.monthLengths.length; month++) {
        const length = type.monthLengths[month - 1]!;
        const first = startOfYear + type.monthStarts[month - 1]!;
        for (const [day, days] of [[1, first], [length, first + length - 1]] as const) {
          const ymd = YearMonthDay.NewYearMonthDay(year, month, day);
          Check(mismatches, `GetDaysSinceEpoch(${year}-${month}-${day})`, calculator.GetDaysSinceEpoch(ymd), days);
          Check(mismatches, `GetYearMonthDay(${days})`, Describe(calculator.GetYearMonthDay(days)), Describe(ymd));
          Check(mismatches, `GetDayOfYear(${year}-${month}-${day})`, calculator.GetDayOfYear(ymd), days - startOfYear + 1);
        }
      }
      startOfYear += type.days;
    }
    expect(mismatches).toEqual([]);
  });
});
