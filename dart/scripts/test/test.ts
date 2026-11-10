// Runs noda_dart's tests on one platform and compiler, writing dart/noda_dart/test-results/<project>@<label>.json
// (tool/test_report.dart merges them) and, with --coverage, coverage/<project>@<label>.lcov.info.
// Usage: node dart/scripts/test/test.ts [--platform vm] [--compiler dart2js] [--variant <name>] [--exclude <regex>] [--tags <tag>...] [--coverage] [-- <dart test args>]
import { mkdirSync } from "node:fs";
import { fail, Option, platformLabel, program, readFile, remove, resolvePath, run, safeFileName, writeFile } from "noda-scripts/ci";

program
  .description("Runs noda_dart's tests on one platform and compiler.")
  .addOption(new Option("--platform <platform>", "dart test's platform").choices(["vm", "chrome", "firefox", "safari", "edge", "node"]).default("vm"))
  .addOption(new Option("--compiler <compiler>", "dart test's compiler").choices(["kernel", "source", "exe", "dart2js", "dart2wasm"]))
  .option("--variant <name>", "added to the label (e.g. the configured time zone)")
  .option("--label <label>", "where it ran (default: NODA_TEST_LABEL, else <os>-<arch>)", process.env["NODA_TEST_LABEL"] || platformLabel())
  .option("--exclude <regex>", "skip tests whose full names match (known failures outside noda_dart)")
  .option("--tags <tag...>", "only tests with these tags")
  .option("--name <regex>", "only tests whose names match")
  .option("--coverage", "write lcov coverage (package-relative paths)")
  .argument("[dartArgs...]", "more dart test arguments")
  .allowUnknownOption()
  .parse();
const o = program.opts<{ platform: string; compiler?: string; variant?: string; label: string; exclude?: string; tags?: string[]; name?: string; coverage?: boolean }>();
const packageDir = "dart/noda_dart";
const label = o.variant ? `${o.label} ${o.variant}` : o.label;
const project = o.compiler ? `${o.platform}-${o.compiler}` : o.platform;
const file = safeFileName(`${project}@${label}`);
const results = `test-results/${file}.json`;

const args = ["test", "--platform", o.platform, `--file-reporter=json:${results}`, "--reporter=expanded"];
if (o.compiler) args.push("--compiler", o.compiler);
if (o.coverage) args.push("--coverage=coverage/raw");
for (const tag of o.tags ?? []) args.push("--tags", tag);
if (o.name) args.push("--name", o.name);
if (o.exclude) args.push("--name", `^(?!(?:${o.exclude})$)`);
args.push(...program.processedArgs[0] as string[]);

console.log(`Testing noda_dart on ${project} [${label}] -> ${results}`);
mkdirSync(resolvePath(`${packageDir}/test-results`), { recursive: true });
remove(`${packageDir}/coverage/raw`);
// A failure still formats the coverage; the status is checked last.
const status = run("dart", args, { cwd: packageDir, check: false });
if (o.coverage) {
  const lcov = `coverage/${file}.lcov.info`;
  run("dart", ["run", "coverage:format_coverage", "--lcov", "--check-ignore", "--report-on=lib", "--base-directory=.",
    "--in=coverage/raw", `--out=${lcov}`], { cwd: packageDir });
  // Forward slashes on every OS, so reports from every machine merge.
  writeFile(`${packageDir}/${lcov}`, readFile(`${packageDir}/${lcov}`).replace(/^SF:(.*)$/gm, (_, p: string) => `SF:${p.replaceAll("\\", "/")}`));
}
if (status !== 0) fail(`dart test failed on ${project} [${label}].`);
