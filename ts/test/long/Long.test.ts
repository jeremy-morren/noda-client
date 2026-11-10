// Which Long noda-js picked: BigInt-backed, or long.js in the node-longjs project.

import LongJs from "long";
import { Duration, Int64, Long, Period } from "../../src/noda-js/internal.ts";
import LongBigInt from "../../src/noda-js/Utility/LongBigInt.ts";
import { describe, expect, inject, it } from "vitest";

declare module "vitest" {
  export interface ProvidedContext {
    longImplementation: "bigint" | "long.js";
  }
}

const expected = inject("longImplementation") ?? "bigint";

describe("Long selection", () => {
  it(`picks ${expected}`, () => {
    expect(Long).toBe(expected === "bigint" ? LongBigInt : LongJs);
    expect(Int64.MaxValue).toBeInstanceOf(expected === "bigint" ? LongBigInt : LongJs);
  });

  it("exact values beyond 2^53", () => {
    const max = Duration.FromNanoseconds("9223372036854775807");
    expect(Int64.ToString(max.ToInt64NanosecondsExact())).toBe("9223372036854775807");
    expect(Int64.ToString(Int64.Divide(Int64.Parse("-9223372036854775808"), 7))).toBe("-1317624576693539401");
    expect(Period.FromNanoseconds("9007199254740993").toString()).toBe("PT9007199254740993n");
  });

  it("division and multiplication by -1 (long.js's WebAssembly division gets -a / -1 wrong when a's high bits are -2^31)", () => {
    expect(Int64.ToString(Int64.Divide(Int64.Parse("-9223372036854775807"), -1))).toBe("9223372036854775807");
    expect(Int64.ToString(Int64.Divide(Int64.Parse("-9223372036854775000"), -1))).toBe("9223372036854775000");
    expect(Int64.ToString(Int64.Multiply(Int64.Parse("9223372036854775000"), -1))).toBe("-9223372036854775000");
    expect(Int64.ToString(Int64.Multiply(-1, Int64.Parse("9223372036854775807")))).toBe("-9223372036854775807");
    expect(() => Int64.Divide(Int64.Parse("-9223372036854775808"), -1)).toThrowNodaError("OverflowException");
    expect(() => Int64.Multiply(Int64.Parse("-9223372036854775808"), -1)).toThrowNodaError("OverflowException");
  });
});
