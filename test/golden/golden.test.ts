/// <reference types="vite/client" />
// Golden vectors from NodaTime itself (tools/NodaJs.Tools data golden): formatting with every standard
// pattern (and some custom ones) in every exported culture, parsing back, and the culture-aware
// case-insensitive comparisons the parsers rely on.

import { describe, expect, it } from "vitest";
import * as noda from "../../src/noda-js/internal.ts";
import { CompareOptions, NodaCultureInfo } from "../../src/noda-js/internal.ts";
import { decode, loadTzdbProvider, needsTzdb, UnsupportedValue } from "../helpers/decode.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import type { CompareGolden, FormattingGolden } from "./types.ts";
import * as cultures from "../../src/noda-js/Cultures/index.generated.ts";

const formattingFiles = import.meta.glob<FormattingGolden>("./formatting/*.generated.ts", { import: "golden", eager: true });
const compareFiles = import.meta.glob<CompareGolden>("./compare/*.generated.ts", { import: "golden", eager: true });
// Every culture, through the noda-js/cultures entry point, by name.
const culturesByName = new Map<string, NodaCultureInfo>(Object.values(cultures).map((c) => [c.Name, c]));

function culture(name: string): NodaCultureInfo {
  if (name === "") {
    return NodaCultureInfo.InvariantCulture;
  }
  const found = culturesByName.get(name);
  if (!found) {
    throw new Error(`No culture ${name} exported from noda-js/cultures`);
  }
  return found;
}

function createPattern(type: string, patternText: string, cultureInfo: NodaCultureInfo, provider: unknown): any {
  const patternClass = (noda as any)[`${type}Pattern`];
  const invariant = type === "ZonedDateTime"
    ? patternClass.CreateWithInvariantCulture(patternText, provider)
    : patternClass.CreateWithInvariantCulture(patternText);
  return invariant.WithCulture(cultureInfo);
}

for (const golden of Object.values(formattingFiles)) {
  describe(`formatting [${golden.culture || "invariant"}]`, () => {
    for (const testCase of golden.cases) {
      it(`${testCase.type} "${testCase.pattern}" ${testCase.text ?? testCase.error}`, async ctx => {
        const provider = needsTzdb(testCase.value) || testCase.type === "ZonedDateTime" ? await loadTzdbProvider() : null;
        let value: unknown;
        try {
          value = decode(testCase.value);
        } catch (e) {
          if (e instanceof UnsupportedValue) {
            ctx.skip(e.message);
            return;
          }
          throw e;
        }
        const pattern = createPattern(testCase.type, testCase.pattern, culture(golden.culture), provider);
        if (testCase.text === undefined) {
          expect(() => pattern.Format(value)).toThrow();
          return;
        }
        expect(pattern.Format(value)).toBe(testCase.text);
        if (testCase.roundTrips) {
          const result = pattern.Parse(testCase.text);
          expect(result.Success, result.Success ? "" : String(result.Exception?.message)).toBe(true);
          assertNodaEqual(result.Value, value);
        }
      });
    }
  });
}

for (const golden of Object.values(compareFiles)) {
  describe(`CompareInfo [${golden.culture || "invariant"}]`, () => {
    const compareInfo = culture(golden.culture).CompareInfo;
    it.each(golden.cases.map(c => [...c]))("%s vs %s → %s", (text, candidate, equal) => {
      expect(compareInfo.Compare(text as string, candidate as string, CompareOptions.IgnoreCase) === 0).toBe(equal);
    });
  });
}
