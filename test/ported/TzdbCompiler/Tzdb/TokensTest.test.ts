// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler.Test/Tzdb/TokensTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { Duration, Offset } from "../../../../src/noda-js/internal.ts";
import { ParserHelper, Tokens } from "../../../../src/noda-js/TzdbCompiler/internal.ts";
import { assertNodaEqual, assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TzdbCompiler/Tzdb/TokensTest.generated.ts";

function AssertTokensEqual(expectedTokens: readonly string[], tokens: Tokens): void {
  for (let i = 0; i < expectedTokens.length; i++) {
    expect(tokens.HasNextToken, "Not enough items in enumeration").toBe(true);
    const actual = tokens.NextToken(i.toString());
    if (actual === null || actual === undefined) {
      expect.fail(`The enumeration item at index [${i}] is null`);
    }
    expect(actual, `The enumeration item at index [${i}] is not correct`).toBe(expectedTokens[i]);
  }
  expect(tokens.HasNextToken, "Too many items in enumeration").toBe(false);
}

port(fixture, {
  Tokenize_nullArgument_Exception() {
    assertThrows("ArgumentNullException", () => Tokens.Tokenize(null!));
  },

  Tokenize(line: string, expectedTokens: string[]) {
    const actualTokens = Tokens.Tokenize(line);
    AssertTokensEqual(expectedTokens, actualTokens);
  },

  ParseOffset_ZeroHoursWithMinutesAndSeconds() {
    // Initial offset for Paris
    const text = "0:09:21";
    const offset = ParserHelper.ParseOffset(text);
    const duration = Duration.FromMinutes(9).Plus(Duration.FromSeconds(21));
    assertNodaEqual(offset, Offset.FromTicks(duration.BclCompatibleTicks));
  },

  ParseOffset_NegativeZeroHoursWithMinutesAndSeconds() {
    // Initial offset for Ouagadougou
    const text = "-0:06:04";
    const offset = ParserHelper.ParseOffset(text);
    const duration = Duration.FromMinutes(6).Plus(Duration.FromSeconds(4));
    assertNodaEqual(offset, Offset.FromTicks(-duration.BclCompatibleTicks));
  },
});
