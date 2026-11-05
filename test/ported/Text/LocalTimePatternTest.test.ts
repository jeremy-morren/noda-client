// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/LocalTimePatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { LocalTime, LocalTimePattern, PatternCursor, type NodaCultureInfo } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/LocalTimePatternTest.generated.ts";
import { assertParseNull, BclFormattingSkip, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

const ExpectedCharacters = "hHms.:fFtT ";

function assertValidNodaPattern(culture: NodaCultureInfo, pattern: string): void {
  const cursor = new PatternCursor(pattern);
  while (cursor.MoveNext()) {
    if (cursor.Current === "'") {
      cursor.GetQuotedString("'");
    } else {
      // We'll never do anything "special" with non-ascii characters anyway,
      // so we don't mind if they're not quoted.
      if (cursor.Current.charCodeAt(0) < 0x80) {
        expect(ExpectedCharacters.includes(cursor.Current), `Pattern '${pattern}' contains unquoted, unexpected characters`).toBe(true);
      }
    }
  }
  // Check that the pattern parses
  LocalTimePattern.Create(pattern, culture);
}

port(
  fixture,
  {
    ...patternTestBaseBodies<LocalTime>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<LocalTime>) => LocalTimePattern.CreateWithInvariantCulture(data.pattern!).WithTemplateValue(data.template!).WithCulture(data.culture!),
    }),

    ParseNull: () => assertParseNull(LocalTimePattern.ExtendedIso),

    BclLongTimePatternIsValidNodaPattern(culture: NodaCultureInfo | null) {
      if (culture === null) {
        return;
      }
      assertValidNodaPattern(culture, culture.DateTimeFormat.LongTimePattern);
    },

    BclShortTimePatternIsValidNodaPattern(culture: NodaCultureInfo) {
      assertValidNodaPattern(culture, culture.DateTimeFormat.ShortTimePattern);
    },

    CreateWithInvariantCulture_NullPatternText() {
      assertThrows("ArgumentNullException", () => LocalTimePattern.CreateWithInvariantCulture(null!));
    },

    Create_NullFormatInfo() {
      assertThrows("ArgumentNullException", () => LocalTimePattern.Create("HH", null! as NodaCultureInfo));
    },

    TemplateValue_DefaultsToMidnight() {
      const pattern = LocalTimePattern.CreateWithInvariantCulture("HH");
      assertNodaEqual(pattern.TemplateValue, LocalTime.Midnight);
    },

    WithTemplateValue_PropertyFetch() {
      const newValue = new LocalTime(1, 23, 45);
      const pattern = LocalTimePattern.CreateWithInvariantCulture("HH").WithTemplateValue(newValue);
      assertNodaEqual(pattern.TemplateValue, newValue);
    },

    HourIso_Roundtrip(text: string) {
      const result = LocalTimePattern.HourIso.Parse(text);
      expect(result.Success).toBe(true);
      const time = result.Value;
      expect(time.Minute).toBe(0);
      expect(time.Second).toBe(0);
      expect(time.NanosecondOfSecond).toBe(0);
      const formatted = LocalTimePattern.HourIso.Format(time);
      expect(formatted).toBe(text);
    },

    HourIso_Invalid(text: string) {
      const result = LocalTimePattern.HourIso.Parse(text);
      expect(result.Success).toBe(false);
    },

    HourMinuteIso_Roundtrip(text: string) {
      const result = LocalTimePattern.HourMinuteIso.Parse(text);
      expect(result.Success).toBe(true);
      const time = result.Value;
      expect(time.Second).toBe(0);
      expect(time.NanosecondOfSecond).toBe(0);
      const formatted = LocalTimePattern.HourMinuteIso.Format(time);
      expect(formatted).toBe(text);
    },

    HourMinuteIso_Invalid(text: string) {
      const result = LocalTimePattern.HourMinuteIso.Parse(text);
      expect(result.Success).toBe(false);
    },

    VariablePrecision_Valid(canonical: string, alternatives: string[]) {
      const pattern = LocalTimePattern.VariablePrecisionIso;
      for (const text of [canonical, ...alternatives]) {
        const result = pattern.Parse(text);
        expect(result.Success).toBe(true);
        const time = result.Value;
        const formatted = pattern.Format(time);
        expect(formatted).toBe(canonical);
      }
    },

    VariablePrecision_Invalid(text: string) {
      const result = LocalTimePattern.VariablePrecisionIso.Parse(text);
      expect(result.Success).toBe(false);
    },
  },
  {
    skip: {
      BclLongTimePatternGivesSameResultsInNoda: BclFormattingSkip,
      BclShortTimePatternGivesSameResultsInNoda: BclFormattingSkip,
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
