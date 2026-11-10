// Prints a Markdown table of a `dart test`/`flutter test` JSON results file (--file-reporter json:...), for
// $GITHUB_STEP_SUMMARY: one row per test.
// Usage: node scripts/ci/summarize-test-results.ts <title> <results.json>
import { existsSync } from "node:fs";
import { program, readFile, resolvePath } from "noda-scripts/ci";

program
  .description("Prints a Markdown summary of a dart test JSON results file.")
  .argument("<title>", "the summary's heading")
  .argument("<results>", "the JSON results file (repo-relative)")
  .parse();
const [title, file] = program.processedArgs as [string, string];

/** Escapes a table cell. */
function cell(value: string): string {
  return value.replace(/\|/g, "\|");
}

console.log(`### ${title}\n`);
// No file: the tests didn't run.
const text = existsSync(resolvePath(file)) ? readFile(file).trim() : "";
if (!text) {
  console.log("No test results: the tests didn't run. See the job log.");
  process.exit(0);
}
const events = text.split("\n").filter(Boolean).map((line) => JSON.parse(line) as Record<string, any>);
const names = new Map<number, string>();
const errors = new Map<number, string>();
for (const e of events) {
  if (e["type"] === "testStart") names.set(e["test"].id, e["test"].name);
  if (e["type"] === "error" && !errors.has(e["testID"])) errors.set(e["testID"], e["error"]);
}
const done = events.filter((e) => e["type"] === "testDone" && !e["hidden"]);
const skipped = done.filter((e) => e["skipped"]).length;
const passed = done.filter((e) => !e["skipped"] && e["result"] === "success").length;
console.log(`${passed} passed, ${done.length - passed - skipped} failed, ${skipped} skipped\n`);
console.log("| Result | Test | Error |\n|---|---|---|");
for (const e of done) {
  const result = e["skipped"] ? "⏭️ skipped" : e["result"] === "success" ? "✅ passed" : "❌ failed";
  const error = (errors.get(e["testID"]) ?? "").split("\n").filter((l) => /\S/.test(l)).slice(0, 2).join(" ").slice(0, 200);
  console.log(`| ${result} | ${cell(names.get(e["testID"]) ?? "")} | ${cell(error)} |`);
}
