// Merges the CI test jobs' blob reports into ts/test-results/junit.xml and their node coverage into ts/coverage/;
// fails at the end if any merged test failed.
// Usage: npm run test:merge [-- --blobs <dir> --coverage <dir> --max-old-space-mb 12288]
import { fail, glob, program, resolvePath, runBin, runScript } from "noda-scripts/ci";

const options = program
  .description("Merges the CI test jobs' blob reports and coverage.")
  .option("--blobs <dir>", "the repo-relative blob reports directory", "ts/test-results/blob")
  .option("--coverage <dir>", "the repo-relative directory searched for each node job's coverage-final.json", "ts/test-results/coverage")
  .option("--max-old-space-mb <mb>", "Node's heap for the merge (it holds every blob)", "12288")
  .parse().opts<{ blobs: string; coverage: string; maxOldSpaceMb: string }>();
const env = {
  // Every extra browser project, so each blob finds its project; none is started.
  NODA_TEST_BROWSERS: "edge,safari,ios-safari,android-chrome",
  NODE_OPTIONS: `${process.env["NODE_OPTIONS"] ?? ""} --max-old-space-size=${options.maxOldSpaceMb}`.trim(),
};

const testsFailed = runBin("vitest", [
  `--merge-reports=${resolvePath(options.blobs)}`, "--reporter=default", "--reporter=./test/vitest/junit-reporter.ts",
  "--outputFile.junit=test-results/junit.xml",
], { env, check: false }) !== 0;

const coverage = glob(options.coverage, "**/coverage-final.json").map((f) => resolvePath(`${options.coverage}/${f}`));
if (coverage.length === 0) fail(`No coverage-final.json under ${options.coverage}.`);
console.log(`Merging the coverage of ${coverage.length} node jobs`);
runScript("ts/test/vitest/merge-coverage.ts", coverage, { cwd: "ts", env });
if (testsFailed) fail("Some merged tests failed (or a test run had errors): see the merged report above.");
