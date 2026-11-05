// The test harness for NodaTime test scenarios (test/scenarios/**/*.generated.ts).
//
// A ported test file supplies the *body* of each NodaTime test method; the harness runs it over every
// case extracted from NodaTime.Test:
//
//   import { fixture } from "../scenarios/LocalDateTest.generated.ts";
//   port(fixture, {
//     PlusDays(start: LocalDate, days: number, expected: LocalDate) { expect(start.PlusDays(days)).toEqualNoda(expected); },
//     DayOfWeek(year: number): IsoDayOfWeek { return new LocalDate(year, 1, 1).DayOfWeek; },  // [TestCase(..., ExpectedResult = ...)]
//   });
//
// - Methods without a body are reported as `todo`, with the C# source location, so new NodaTime tests
//   show up automatically when the scenarios are regenerated.
// - Cases whose arguments can't be represented in noda-js (BCL types, for example)
//   are skipped.
// - For NUnit cases with an ExpectedResult, the body's return value is compared with it.
// - Overloaded methods can be given bodies keyed "Method(int, LocalDate)" (C# parameter types).

import { describe, expect, it } from "vitest";
import type { ScenarioCase, ScenarioFixture, ScenarioTest } from "../scenarios/types.ts";
import { decode, decodeExpected, loadTzdbProvider, needsTzdb, UnsupportedValue } from "./decode.ts";
import { assertNodaEqual } from "./assertions.ts";

export type TestBody = (...args: any[]) => unknown;

export interface PortOptions {
  /**
   * Methods to skip, with the reason (e.g. they test .NET-only behaviour). Keyed by method name, or by
   * "Method(int, LocalDate)" (C# parameter types) to skip one overload.
   */
  readonly skip?: Readonly<Record<string, string>>;
}

export function port(fixture: ScenarioFixture, bodies: Readonly<Record<string, TestBody>>, options: PortOptions = {}): void {
  const used = new Set<string>();
  describe(fixture.name, () => {
    for (const test of fixture.tests) {
      const key = bodyKey(test, bodies);
      const body = key === undefined ? undefined : bodies[key];
      if (key !== undefined) {
        used.add(key);
      }
      const label = `${test.method} [${test.source}]`;
      const skipReason = options.skip?.[overloadKeyOf(test)] ?? options.skip?.[test.method] ?? fixture.excluded ?? test.excluded ?? test.ignored ?? test.notRunnable ?? test.skipped ?? (test.explicit ? "explicit" : undefined);
      if (skipReason !== undefined) {
        it.skip(`${label} — ${skipReason}`, () => {});
        continue;
      }
      if (body === undefined) {
        it.todo(label);
        continue;
      }
      if (test.cases.length === 1 && test.cases[0]!.args.length === 0 && test.parameters === undefined) {
        it(test.method, ctx => runCase(test, test.cases[0]!, body, ctx));
        continue;
      }
      describe(test.method, () => {
        test.cases.forEach((testCase, index) => {
          it(`#${index} ${caseLabel(testCase)}`, ctx => runCase(test, testCase, body, ctx));
        });
      });
    }
    // Catch typos: every supplied body must match a NodaTime test method.
    it("has no bodies for unknown test methods", () => {
      const unknown = Object.keys(bodies).filter(k => !used.has(k));
      expect(unknown, `Bodies with no matching test in ${fixture.name}`).toEqual([]);
    });
  });
}

/** "Method(int, LocalDate)": the key for one overload of a test method (C# parameter types). */
function overloadKeyOf(test: ScenarioTest): string {
  const types = (test.parameters ?? []).map(p => p.substring(0, p.lastIndexOf(" "))).join(", ");
  return `${test.method}(${types})`;
}

function bodyKey(test: ScenarioTest, bodies: Readonly<Record<string, TestBody>>): string | undefined {
  const overloadKey = overloadKeyOf(test);
  if (overloadKey in bodies) {
    return overloadKey;
  }
  return test.method in bodies ? test.method : undefined;
}

async function runCase(test: ScenarioTest, testCase: ScenarioCase, body: TestBody, ctx: { skip: (note?: string) => void }): Promise<void> {
  const skipReason = testCase.ignored ?? testCase.notRunnable ?? testCase.encodingError ?? (testCase.explicit ? "explicit" : undefined);
  if (skipReason !== undefined) {
    ctx.skip(skipReason);
    return;
  }
  let args: unknown[];
  let expected: unknown;
  try {
    if (needsTzdb(testCase.args) || needsTzdb(testCase.expected)) {
      await loadTzdbProvider();
    }
    args = testCase.args.map(decode);
    expected = testCase.expected === undefined ? undefined : decodeExpected(testCase.expected);
  } catch (e) {
    if (e instanceof UnsupportedValue) {
      ctx.skip(e.message);
      return;
    }
    throw e;
  }
  let actual: unknown;
  try {
    actual = await body(...args);
  } catch (e) {
    // A body may throw UnsupportedValue for a case noda-js can't run (e.g. an unported calendar given by ordinal or ID).
    if (e instanceof UnsupportedValue) {
      ctx.skip(e.message);
      return;
    }
    throw e;
  }
  if (testCase.expected !== undefined) {
    assertNodaEqual(actual, expected, `${test.method} ExpectedResult`);
  }
}

function caseLabel(testCase: ScenarioCase): string {
  const text = testCase.description ?? JSON.stringify(testCase.args, (_, v) => (typeof v === "bigint" ? `${v}n` : v));
  return text.length > 120 ? text.substring(0, 117) + "..." : text;
}
