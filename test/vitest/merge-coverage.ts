// Merges the node project's coverage from each CI test job into one coverage report (scripts/merge-test-reports.ps1).
//
// Each job's `npm run test:blob -- -Project node -Coverage` writes coverage/coverage-final.json (Istanbul's format, the
// v8 provider's "json" reporter), keyed by absolute paths in that machine's checkout. This moves each file onto the same
// file in this checkout (the first tail of its path that starts at a "src" segment and exists here: coverage only
// includes src/), merges the coverage maps, and writes what CI publishes: coverage/coverage-final.json,
// coverage/coverage-summary.json and a text summary. (Vitest's own `--merge-reports --coverage` did this through the
// custom coverage provider, but loading the provider failed in CI.)
//
// Usage: node test/vitest/merge-coverage.ts <coverage-final.json>...

import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import libCoverage from "istanbul-lib-coverage";
import type { CoverageMapData, FileCoverageData } from "istanbul-lib-coverage";
import libReport from "istanbul-lib-report";
import reports from "istanbul-reports";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

/** The file in this checkout that a path from another machine's checkout names (unchanged if there's none). */
function rebase(filepath: string): string {
  const segments = filepath.split(/[\\/]/);
  for (let i = segments.indexOf("src"); i >= 0; i = segments.indexOf("src", i + 1)) {
    const candidate = path.join(root, ...segments.slice(i));
    if (existsSync(candidate)) {
      return candidate;
    }
  }
  return filepath;
}

const inputs = process.argv.slice(2);
if (inputs.length === 0) {
  throw new Error("Usage: node test/vitest/merge-coverage.ts <coverage-final.json>...");
}

const coverageMap = libCoverage.createCoverageMap({});
for (const input of inputs) {
  const data = JSON.parse(readFileSync(input, "utf8")) as Record<string, FileCoverageData>;
  const rebased: CoverageMapData = {};
  let moved = 0;
  for (const fileCoverage of Object.values(data)) {
    const filepath = rebase(fileCoverage.path);
    moved += filepath === fileCoverage.path ? 0 : 1;
    rebased[filepath] = { ...fileCoverage, path: filepath };
  }
  coverageMap.merge(rebased);
  console.log(`${input}: ${Object.keys(data).length} files (${moved} moved onto this checkout)`);
}

const context = libReport.createContext({ dir: path.join(root, "coverage"), coverageMap, defaultSummarizer: "nested" });
for (const name of ["json", "json-summary", "text-summary"] as const) {
  reports.create(name).execute(context);
}
