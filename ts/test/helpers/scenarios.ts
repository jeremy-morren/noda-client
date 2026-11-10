// Runs a ported test body over every generated case of its NodaTime test method (see test/README.md).
// Methods without a body are todo; a returned value is compared with ExpectedResult; overloads are keyed
// "Method(int, LocalDate)".

import { describe, expect, it } from "vitest";
import type { ScenarioCase, ScenarioFixture, ScenarioTest } from "../scenarios/types.ts";
import { decode, decodeExpected, loadTzdbProvider, needsTzdb, UnsupportedValue } from "./decode.ts";
import { assertNodaEqual } from "./assertions.ts";

export type TestBody = (...args: any[]) => unknown;

export interface PortOptions {
  /** Methods (or "Method(int, LocalDate)" overloads) to skip, with the reason. */
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
    // Catch typos.
    it("has no bodies for unknown test methods", () => {
      const unknown = Object.keys(bodies).filter(k => !used.has(k));
      expect(unknown, `Bodies with no matching test in ${fixture.name}`).toEqual([]);
    });
  });
}

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
