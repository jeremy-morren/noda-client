// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/LocalDateTimePatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { CalendarSystem, InvalidPatternException, LocalDateTime, LocalDateTimePattern, type NodaCultureInfo } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/LocalDateTimePatternTest.generated.ts";
import {
  assertParseNull,
  BclFormattingSkip,
  CurrentCultureSkip,
  patternTestBaseBodies,
  type PatternTestData,
} from "./PatternTestSupport.ts";

const SampleLocalDateTime = new LocalDateTime(1976, 6, 19, 21, 13, 34).PlusNanoseconds(123456789);
const SampleLocalDateTimeToTicks = new LocalDateTime(1976, 6, 19, 21, 13, 34).PlusNanoseconds(123456700);
const SampleLocalDateTimeToMillis = new LocalDateTime(1976, 6, 19, 21, 13, 34, 123);
const SampleLocalDateTimeToSeconds = new LocalDateTime(1976, 6, 19, 21, 13, 34);
const SampleLocalDateTimeToMinutes = new LocalDateTime(1976, 6, 19, 21, 13);

// Helper method to make it slightly easier for tests to skip "bad" cultures.
function createPatternOrNull(patternText: string, culture: NodaCultureInfo, _templateValue: LocalDateTime): LocalDateTimePattern | null {
  try {
    return LocalDateTimePattern.Create(patternText, culture);
  } catch (e) {
    if (e instanceof InvalidPatternException) {
      // The Malta long date/time pattern in Mono 3.0 is invalid (not just wrong; invalid due to the wrong number of quotes).
      // Skip it :(
      // See https://bugzilla.xamarin.com/show_bug.cgi?id=11363
      return null;
    }
    throw e;
  }
}

port(
  fixture,
  {
    ...patternTestBaseBodies<LocalDateTime>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<LocalDateTime>) => LocalDateTimePattern.CreateWithInvariantCulture(data.pattern!).WithTemplateValue(data.template!).WithCulture(data.culture!),
    }),

    WithCalendar() {
      const pattern = LocalDateTimePattern.GeneralIso.WithCalendar(CalendarSystem.Coptic);
      const value = pattern.Parse("0284-08-29T12:34:56").Value;
      assertNodaEqual(value, new LocalDateTime(284, 8, 29, 12, 34, 56, CalendarSystem.Coptic));
    },

    ParseNull: () => assertParseNull(LocalDateTimePattern.ExtendedIso),

    WithTwoDigitYearMax(twoDigitYearMax: number, text: string, expectedYear: number) {
      const pattern = LocalDateTimePattern.CreateWithInvariantCulture("yy-MM-dd'T'HH:mm:ss").WithTwoDigitYearMax(twoDigitYearMax);
      const value = pattern.Parse(text).Value;
      expect(value.Year).toBe(expectedYear);
    },

    WithTwoDigitYearMax_Invalid(twoDigitYearMax: number) {
      assertThrows("ArgumentOutOfRangeException", () => LocalDateTimePattern.ExtendedIso.WithTwoDigitYearMax(twoDigitYearMax));
    },

    ParseFormattedStandardPattern(culture: NodaCultureInfo, patternText: string) {
      let pattern = createPatternOrNull(patternText, culture, new LocalDateTime(2000, 1, 1, 0, 0));
      if (pattern === null) {
        return;
      }

      // If the pattern really can't distinguish between AM and PM (e.g. it's 12 hour with an
      // abbreviated AM/PM designator) then let's let it go.
      if (pattern.Format(SampleLocalDateTime) === pattern.Format(SampleLocalDateTime.PlusHours(-12))) {
        return;
      }

      // If the culture doesn't have either AM or PM designators, we'll end up using the template value
      // AM/PM, so let's make sure that's right. (This happens on Mono for a few cultures.)
      if (culture.DateTimeFormat.AMDesignator === "" && culture.DateTimeFormat.PMDesignator === "") {
        pattern = pattern.WithTemplateValue(new LocalDateTime(2000, 1, 1, 12, 0));
      }

      const formatted = pattern.Format(SampleLocalDateTime);
      const parseResult = pattern.Parse(formatted);
      expect(parseResult.Success).toBe(true);
      const parsed = parseResult.Value;
      const candidates = [SampleLocalDateTime, SampleLocalDateTimeToTicks, SampleLocalDateTimeToMillis, SampleLocalDateTimeToSeconds, SampleLocalDateTimeToMinutes];
      expect(candidates.some(c => c.Equals(parsed)), `${parsed} should be one of ${candidates.join(", ")}`).toBe(true);
    },

    DateHourIso_Roundtrip(text: string) {
      const result = LocalDateTimePattern.DateHourIso.Parse(text);
      expect(result.Success).toBe(true);
      const time = result.Value;
      expect(time.Minute).toBe(0);
      expect(time.Second).toBe(0);
      expect(time.NanosecondOfSecond).toBe(0);
      const formatted = LocalDateTimePattern.DateHourIso.Format(time);
      expect(formatted).toBe(text);
    },

    DateHourIso_2400() {
      const result = LocalDateTimePattern.DateHourIso.Parse("1992-01-25T24");
      expect(result.Success).toBe(true);
      assertNodaEqual(result.Value, new LocalDateTime(1992, 1, 26, 0, 0));
    },

    DateHourIso_Invalid(text: string) {
      const result = LocalDateTimePattern.DateHourIso.Parse(text);
      expect(result.Success).toBe(false);
    },

    DateHourMinuteIso_Roundtrip(text: string) {
      const result = LocalDateTimePattern.DateHourMinuteIso.Parse(text);
      expect(result.Success).toBe(true);
      const time = result.Value;
      expect(time.Second).toBe(0);
      expect(time.NanosecondOfSecond).toBe(0);
      const formatted = LocalDateTimePattern.DateHourMinuteIso.Format(time);
      expect(formatted).toBe(text);
    },

    DateHourMinuteIso_2400() {
      const result = LocalDateTimePattern.DateHourMinuteIso.Parse("1992-01-25T24:00");
      expect(result.Success).toBe(true);
      assertNodaEqual(result.Value, new LocalDateTime(1992, 1, 26, 0, 0));
    },

    DateHourMinuteIso_Invalid(text: string) {
      const result = LocalDateTimePattern.DateHourMinuteIso.Parse(text);
      expect(result.Success).toBe(false);
    },

    VariablePrecision_Valid(canonical: string, alternatives: string[]) {
      // Just use the same prefix for all values; it's only the time part that can vary in precision.
      const prefix = "1992-01-25T";
      const fullCanonical = prefix + canonical;

      const pattern = LocalDateTimePattern.VariablePrecisionIso;
      for (const text of [canonical, ...alternatives]) {
        const result = pattern.Parse(prefix + text);
        expect(result.Success).toBe(true);
        const time = result.Value;
        const formatted = pattern.Format(time);
        expect(formatted).toBe(fullCanonical);
      }
    },

    VarablePrecision_2400(text: string) {
      const result = LocalDateTimePattern.VariablePrecisionIso.Parse(text);
      expect(result.Success).toBe(true);
      assertNodaEqual(result.Value, new LocalDateTime(1992, 1, 26, 0, 0));
    },

    VariablePrecision_Invalid(text: string) {
      const result = LocalDateTimePattern.VariablePrecisionIso.Parse(text);
      expect(result.Success).toBe(false);
    },
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
      BclStandardPatternComparison: BclFormattingSkip,
    },
  },
);
