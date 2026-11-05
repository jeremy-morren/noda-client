// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/Patterns/SteppedPatternBuilderTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// Tests for SteppedPatternBuilder, often using OffsetPatternParser as this is known
// to use SteppedPatternBuilder.

import { expect } from "vitest";
import {
  InvalidPatternException,
  LocalDate,
  NodaFormatInfo,
  Offset,
  OffsetPatternParser,
  ParseBucket,
  SteppedPatternBuilder,
  StringBuilder,
  TextCursor,
  TextErrorMessages,
  UnparsableValueException,
  ValueCursor,
  type CharacterHandler,
  type IPartialPattern,
  type ParseResult,
  type PatternFields,
} from "../../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/Text/Patterns/SteppedPatternBuilderTest.generated.ts";
import type { NotImplementedException } from "../../../../src/noda-js/internal.ts";

class SampleBucket extends ParseBucket<LocalDate> {
  override CalculateValue(_usedFields: PatternFields, _value: string): ParseResult<LocalDate> {
    // C#: NotImplementedException
    throw new Error("The method or operation is not implemented.");
  }
}

let simpleOffsetPattern: IPartialPattern<Offset> | undefined;
function SimpleOffsetPattern(): IPartialPattern<Offset> {
  return (simpleOffsetPattern ??= new OffsetPatternParser().ParsePattern("HH:mm", NodaFormatInfo.InvariantInfo) as unknown as IPartialPattern<Offset>);
}

port(fixture, {
  ParsePartial_ValidInMiddle() {
    const value = new ValueCursor("x17:30y");
    value.MoveNext();
    value.MoveNext();
    // Start already looking at the value to parse
    expect(value.Current).toBe("1");
    const result = SimpleOffsetPattern().ParsePartial(value);
    assertNodaEqual(result.Value, Offset.FromHoursAndMinutes(17, 30));
    // Finish just after the value
    expect(value.Current).toBe("y");
  },

  ParsePartial_ValidAtEnd() {
    const value = new ValueCursor("x17:30");
    value.MoveNext();
    value.MoveNext();
    const result = SimpleOffsetPattern().ParsePartial(value);
    assertNodaEqual(result.Value, Offset.FromHoursAndMinutes(17, 30));
    // Finish just after the value, which in this case is at the end.
    expect(value.Current).toBe(TextCursor.Nul);
  },

  ParsePartial_Invalid() {
    const value = new ValueCursor("x17:y");
    value.MoveNext();
    value.MoveNext();
    const result = SimpleOffsetPattern().ParsePartial(value);
    const exception = assertThrows(UnparsableValueException, () => result.GetValueOrThrow());
    expect(exception?.Value).toBe("x17:y");
    expect(exception?.Index).toBe(4);
  },

  FormatOnly_ParsingFails() {
    const builder = new SteppedPatternBuilder<LocalDate, SampleBucket>(NodaFormatInfo.InvariantInfo, () => new SampleBucket());
    builder.AddFormatAction((_date, sb) => sb.Append("Formatted"));
    builder.SetFormatOnly();
    const pattern = builder.Build(LocalDate.MinIsoValue);

    const value = new ValueCursor("xyz");
    let result = pattern.ParsePartial(value);
    expect(result.Success).toBe(false);
    expect(result.Exception).toBeInstanceOf(UnparsableValueException);
    expect((result.Exception as UnparsableValueException).Value).toBe("xyz");
    expect((result.Exception as UnparsableValueException).Index).toBe(-1);
    expect(result.Exception.message).toBe(TextErrorMessages.FormatOnlyPattern);
    result = pattern.Parse("xyz");
    expect(result.Success).toBe(false);
    expect(result.Exception).toBeInstanceOf(UnparsableValueException);
    expect((result.Exception as UnparsableValueException).Value).toBe("xyz");
    expect((result.Exception as UnparsableValueException).Index).toBe(-1);
    expect(result.Exception.message).toBe(TextErrorMessages.FormatOnlyPattern);
  },

  AppendFormat() {
    const builder = new StringBuilder("x");
    const offset = Offset.FromHoursAndMinutes(17, 30);
    SimpleOffsetPattern().AppendFormat(offset, builder);
    expect(builder.toString()).toBe("x17:30");
  },

  UnhandledLiteral(text: string, valid: boolean) {
    const handler: CharacterHandler<LocalDate, SampleBucket> = () => {};
    const handlers = new Map<string, CharacterHandler<LocalDate, SampleBucket>>([
      ["a", handler],
      ["B", handler],
    ]);
    const builder = new SteppedPatternBuilder<LocalDate, SampleBucket>(NodaFormatInfo.InvariantInfo, () => new SampleBucket());
    if (valid) {
      builder.ParseCustomPattern(text, handlers);
    } else {
      assertThrows(InvalidPatternException, () => builder.ParseCustomPattern(text, handlers));
    }
  },
});
