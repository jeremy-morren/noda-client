// Runs Vitest projects and writes ts/test-results/blob/<projects>-<label>.json for merge-test-reports.ts.
// Usage: npm run test:blob -- --project node [node-longjs] [--label <label>] [--coverage]
import { platformLabel, program, runBin, safeFileName } from "noda-scripts/ci";

const { project, label, coverage } = program
  .description("Runs Vitest projects and writes a blob report.")
  .requiredOption("--project <names...>", "the vitest.config.ts projects")
  .option("--label <label>", "where it ran (default: NODA_TEST_LABEL, else <os>-<arch>)", process.env["NODA_TEST_LABEL"] || platformLabel())
  .option("--coverage", "collect the node project's coverage")
  .parse().opts<{ project: string[]; label: string; coverage?: boolean }>();
const extra = project.filter((p) => ["edge", "safari", "ios-safari", "android-chrome"].includes(p));
const blob = `test-results/blob/${safeFileName(`${project.join("+")}-${label}`)}.json`;

console.log(`Testing ${project.join(", ")} [${label}] -> ts/${blob}`);
runBin("vitest", [
  "run", ...project.flatMap((p) => ["--project", p]), "--reporter=default", "--reporter=blob", `--outputFile.blob=${blob}`,
  ...(coverage ? ["--coverage"] : []),
], { env: { VITEST_BLOB_LABEL: label, NODA_TEST_BROWSERS: extra.length > 0 ? extra.join(",") : process.env["NODA_TEST_BROWSERS"] } });
