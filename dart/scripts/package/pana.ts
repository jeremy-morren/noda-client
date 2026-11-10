// Scores noda_dart with pana (pub.dev's analysis) and fails unless it keeps every platform and runtime tag. Not on Windows
// (pana's sandbox rejects paths with ":").
// Usage: node dart/scripts/package/pana.ts
import { capture, core, fail, program, run } from "noda-scripts/ci";

program.description("Scores noda_dart with pana and checks its platform tags.").parse();

// A dart:io/dart:ffi import reachable on the web (or js_interop on native) would lose a tag.
const requiredTags = [
  "platform:android", "platform:ios", "platform:linux", "platform:macos", "platform:web", "platform:windows",
  "runtime:native-aot", "runtime:native-jit", "runtime:web", "is:wasm-ready", "sdk:dart", "sdk:flutter",
];

/** pana's report section: points and title. */
interface Section {
  /** Points granted. */
  grantedPoints: number;
  /** Points available. */
  maxPoints: number;
  /** The section's title. */
  title: string;
}

run("dart", ["pub", "global", "activate", "pana"]);
const report = JSON.parse(capture("dart", ["pub", "global", "run", "pana", "--no-warning", "--json", "."], { cwd: "dart/noda_dart" })) as {
  tags: string[];
  report: { sections: Section[] };
};

const sections = report.report.sections.map((s) => `- ${s.grantedPoints}/${s.maxPoints} ${s.title}`);
console.log([...sections, `Tags: ${report.tags.join(", ")}`].join("\n"));
if (process.env["GITHUB_STEP_SUMMARY"]) {
  await core.summary.addHeading("pana (noda_dart)", 3).addRaw([...sections, "", `Tags: ${report.tags.join(", ")}`].join("\n")).write();
}

const missing = requiredTags.filter((tag) => !report.tags.includes(tag));
if (missing.length > 0) fail(`pana no longer reports: ${missing.join(", ")}`);
