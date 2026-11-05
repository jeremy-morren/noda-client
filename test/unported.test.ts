// Lists every NodaTime.Test fixture that has no ported test file yet (test/ported/<namespace path>/<Class>.test.ts),
// one `todo` per test method, so new upstream tests show up as soon as the scenarios are regenerated.

import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, it } from "vitest";
import { scenarioFixtures } from "./scenarios/index.generated.ts";

const portedRoot = fileURLToPath(new URL("./ported/", import.meta.url));

/** "NodaTime.Test.Text.PeriodPatternTest+Roundtrip" → "Text/PeriodPatternTest" */
function portedPath(fixtureName: string): string {
  const name = fixtureName.replace(/^NodaTime\.Test\./, "").replace(/\(.*\)$/, "").split("+")[0]!;
  return name.replace(/\./g, "/") + ".test.ts";
}

const unported = Object.entries(scenarioFixtures).filter(([name]) => !existsSync(portedRoot + portedPath(name)));

for (const [name, load] of unported) {
  const fixture = await load();
  if (fixture.excluded !== undefined) {
    // Out of scope (tools/scenario-exclusions.txt): reported as skipped, not as work to do.
    describe(`[excluded] ${name}`, () => {
      it.skip(fixture.excluded!, () => {});
    });
    continue;
  }
  describe(`[unported] ${name}`, () => {
    for (const test of fixture.tests) {
      it.todo(`${test.method} [${test.source}] (${test.cases.length} cases)`);
    }
  });
}
