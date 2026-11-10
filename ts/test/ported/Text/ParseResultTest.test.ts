// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/ParseResultTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { ParseResult, UnparsableValueException, ValueCursor } from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/ParseResultTest.generated.ts";

const FailureResult: ParseResult<number> = ParseResult.ForInvalidValue<number>(new ValueCursor("text"), "text");

port(fixture, {
  Value_Success() {
    const result = ParseResult.ForValue<number>(5);
    expect(result.Value).toBe(5);
  },

  Value_Failure() {
    const exception = assertThrows(UnparsableValueException, () => FailureResult.Value);
    expect(exception?.Value).toBe("text");
    expect(exception?.Index).toBe(-1);
  },

  Exception_Success() {
    const result = ParseResult.ForValue<number>(5);
    assertThrows("InvalidOperationException", () => result.Exception);
  },

  Exception_Failure() {
    expect(FailureResult.Exception).toBeInstanceOf(UnparsableValueException);
    expect((FailureResult.Exception as UnparsableValueException).Value).toBe("text");
    expect((FailureResult.Exception as UnparsableValueException).Index).toBe(-1);
  },

  GetValueOrThrow_Success() {
    const result = ParseResult.ForValue<number>(5);
    expect(result.GetValueOrThrow()).toBe(5);
  },

  GetValueOrThrow_Failure() {
    const exception = assertThrows(UnparsableValueException, () => FailureResult.GetValueOrThrow());
    expect(exception?.Value).toBe("text");
    expect(exception?.Index).toBe(-1);
  },

  TryGetValue_Success() {
    const result = ParseResult.ForValue<number>(5);
    const [success, actual] = result.TryGetValue(-1);
    expect(success).toBe(true);
    expect(actual).toBe(5);
  },

  TryGetValue_Failure() {
    const [success, actual] = FailureResult.TryGetValue(-1);
    expect(success).toBe(false);
    expect(actual).toBe(-1);
  },

  Convert_ForFailureResult() {
    const converted: ParseResult<string> = FailureResult.Convert(x => `xx${x}xx`);
    const exception = assertThrows(UnparsableValueException, () => converted.GetValueOrThrow());
    expect(exception?.Value).toBe("text");
    expect(exception?.Index).toBe(-1);
  },

  Convert_ForSuccessResult() {
    const original = ParseResult.ForValue<number>(10);
    const converted: ParseResult<string> = original.Convert(x => `xx${x}xx`);
    expect(converted.Value).toBe("xx10xx");
  },

  ConvertError_ForFailureResult() {
    const converted: ParseResult<string> = FailureResult.ConvertError<string>();
    const exception = assertThrows(UnparsableValueException, () => converted.GetValueOrThrow());
    expect(exception?.Value).toBe("text");
    expect(exception?.Index).toBe(-1);
  },

  ConvertError_ForSuccessResult() {
    const original = ParseResult.ForValue<number>(10);
    assertThrows("InvalidOperationException", () => original.ConvertError<string>());
  },

  ForException() {
    const e = new Error();
    const result = ParseResult.ForException<number>(() => e);
    expect(result.Success).toBe(false);
    expect(result.Exception).toBe(e);
  },
});
