// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/PatternTestData.cs and PatternTestBase.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// PatternTestBase<T>'s test methods, over decoded Data objects; each fixture supplies CreatePattern.

import { expect } from "vitest";
import {
  FormatString,
  InvalidPatternException,
  StringBuilder,
  UnparsableValueException,
  ValueCursor,
  type NodaCultureInfo,
  type IPartialPattern,
  type IPattern,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import type { TestBody } from "../../helpers/scenarios.ts";

/** A decoded PatternTestData<T> (fields as encoded by the scenario extractor). */
export interface PatternTestData<T> {
  readonly $: string;
  readonly value: T;
  readonly template?: T;
  readonly culture?: NodaCultureInfo;
  readonly standardPattern?: IPattern<T> | null;
  readonly pattern?: string | null;
  readonly text?: string | null;
  readonly description?: string;
  readonly message?: string | null;
  readonly parameters?: readonly unknown[];
  readonly [extra: string]: unknown;
}

export interface PatternDataSupport<T> {
  /** PatternTestData.CreatePattern(), as the fixture's Data class overrides it. */
  createPattern(data: PatternTestData<T>): IPattern<T>;
  /** PatternTestData.CreatePartialPattern(), where the fixture overrides it. */
  createPartialPattern?(data: PatternTestData<T>): IPartialPattern<T>;
}

/**
 * Formats a message, giving a *useful* error message on failure. It can be a pain checking exactly what
 * the message format is when writing tests...
 */
function formatMessage(message: string, parameters: readonly unknown[]): string {
  return FormatString(message, ...parameters);
}

export function testParse<T>(support: PatternDataSupport<T>, data: PatternTestData<T>): void {
  expect(data.message ?? null).toBeNull();
  const pattern = support.createPattern(data);
  const result = pattern.Parse(data.text!);
  const actualValue = result.Value;
  assertNodaEqual(actualValue, data.value);

  if (data.standardPattern) {
    assertNodaEqual(data.standardPattern.Parse(data.text!).Value, data.value);
  }
}

export function testFormat<T>(support: PatternDataSupport<T>, data: PatternTestData<T>): void {
  expect(data.message ?? null).toBeNull();
  const pattern = support.createPattern(data);
  expect(pattern.Format(data.value)).toBe(data.text);

  if (data.standardPattern) {
    expect(data.standardPattern.Format(data.value)).toBe(data.text);
  }
}

export function testParsePartial<T>(support: PatternDataSupport<T>, data: PatternTestData<T>): void {
  const pattern = support.createPartialPattern!(data);
  expect(data.message ?? null).toBeNull();
  const cursor = new ValueCursor(`^${data.text}#`);
  // Move to the ^
  cursor.MoveNext();
  // Move to the start of the text
  cursor.MoveNext();
  const result = pattern.ParsePartial(cursor);
  const actualValue = result.Value;
  assertNodaEqual(actualValue, data.value);
  expect(cursor.Current).toBe("#");
}

export function testAppendFormat<T>(support: PatternDataSupport<T>, data: PatternTestData<T>): void {
  expect(data.message ?? null).toBeNull();
  const pattern = support.createPattern(data);
  const builder = new StringBuilder("x");
  pattern.AppendFormat(data.value, builder);
  expect(builder.toString()).toBe(`x${data.text}`);
}

export function testInvalidPattern<T>(support: PatternDataSupport<T>, data: PatternTestData<T>): void {
  const expectedMessage = formatMessage(data.message!, data.parameters ?? []);
  try {
    support.createPattern(data);
  } catch (e) {
    if (e instanceof InvalidPatternException) {
      // Expected... now let's check the message
      expect(e.message).toBe(expectedMessage);
      return;
    }
    throw e;
  }
  expect.fail("Expected InvalidPatternException");
}

export function testParseFailure<T>(support: PatternDataSupport<T>, data: PatternTestData<T>): void {
  const expectedMessage = formatMessage(data.message!, data.parameters ?? []);
  const pattern = support.createPattern(data);
  const result = pattern.Parse(data.text!);
  expect(result.Success, "Expected parsing to fail, but it succeeded").toBe(false);
  try {
    result.GetValueOrThrow();
  } catch (e) {
    if (e instanceof UnparsableValueException) {
      // Expected... now let's check the message *starts* with the right part.
      // We're not currently validating the bit that reproduces the bad value.
      expect(e.message.startsWith(expectedMessage), `Expected message to start with ${expectedMessage}; was actually ${e.message}`).toBe(true);
      expect(e.Value, "Expected exception to include the text value").toBe(data.text);
      return;
    }
    throw e;
  }
  expect.fail("Expected UnparsableValueException");
}

/** The test methods PatternTestBase<T> gives every pattern fixture (null Data is ignored, as in C#). */
export function patternTestBaseBodies<T>(support: PatternDataSupport<T>): Record<string, TestBody> {
  return {
    InvalidPatterns: (data: PatternTestData<T> | null) => data && testInvalidPattern(support, data),
    ParseFailures: (data: PatternTestData<T> | null) => data && testParseFailure(support, data),
    Parse: (data: PatternTestData<T> | null) => data && testParse(support, data),
    Format: (data: PatternTestData<T> | null) => data && testFormat(support, data),
    AppendFormat: (data: PatternTestData<T> | null) => data && testAppendFormat(support, data),
  };
}

/** Skip reason for CreateWithCurrentCulture tests. */
export const CurrentCultureSkip = "Uses CultureInfo.CurrentCulture (CreateWithCurrentCulture); noda-js has no current culture";

/** Skip reason for tests comparing with .NET's own DateTime formatting. */
export const BclFormattingSkip = "Compares with .NET's DateTime.ToString(pattern, culture), which isn't available in JS";

/** PatternTestBase.AssertRoundTrip */
export function assertRoundTrip<T>(value: T, pattern: IPattern<T>): void {
  const text = pattern.Format(value);
  const parseResult = pattern.Parse(text);
  assertNodaEqual(parseResult.Value, value);
}

/** PatternTestBase.AssertParseNull */
export function assertParseNull<T>(pattern: IPattern<T>): void {
  // Rare case where we pass a null value to a non-nullable reference type parameter,
  // but don't expect an immediate exception.
  const result = pattern.Parse(null as unknown as string);
  expect(result.Success).toBe(false);
  expect(result.Exception?.name).toBe("ArgumentNullException");
}
