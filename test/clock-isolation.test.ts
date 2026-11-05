// Time must be mockable: as in NodaTime, code that needs "now" takes an IClock (e.g. FakeClock from
// noda-js/testing), and SystemClock is the only thing that reads the real time.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const srcRoot = fileURLToPath(new URL("../src/noda-js/", import.meta.url));
const readsRealTime = /\bDate\.now\s*\(|\bperformance\.now\s*\(|\bperformance\.timeOrigin\b|\bnew\s+Date\s*\(\s*\)/;
const allowed = new Set(["SystemClock.ts"]);

function* sourceFiles(dir: string): Generator<string> {
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) {
      if (entry === "dist" || entry === "node_modules") {
        continue; // build output, not sources
      }
      yield* sourceFiles(path);
    } else if (entry.endsWith(".ts") && !entry.endsWith(".d.ts") && !entry.endsWith(".generated.ts")) {
      yield path;
    }
  }
}

describe("clock isolation", () => {
  it("only SystemClock reads the real time", () => {
    const offenders: string[] = [];
    for (const file of sourceFiles(srcRoot)) {
      const path = relative(srcRoot, file).replace(/\\/g, "/");
      if (allowed.has(path)) {
        continue;
      }
      readFileSync(file, "utf8").split("\n").forEach((line, i) => {
        if (readsRealTime.test(line) && !line.trimStart().startsWith("//") && !line.trimStart().startsWith("*")) {
          offenders.push(`src/${path}:${i + 1}: ${line.trim()}`);
        }
      });
    }
    expect(offenders).toEqual([]);
  });
});
