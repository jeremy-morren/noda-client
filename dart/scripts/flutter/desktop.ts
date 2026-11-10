// Runs the Flutter app's system time zone checks on the desktop (Linux: under xvfb-run), in a zone set on the machine
// (--source system: changes the machine's zone, for CI) or named by TZ (the app's only). Writes
// test-results/flutter-<device>@<device>-<source>-<arch>.json and coverage-out/flutter-<device>-<source>.lcov.info,
// with paths relative to dart/noda_dart as in the other coverage.
// Usage: node dart/scripts/flutter/desktop.ts --device windows --source TZ --zone Asia/Kolkata --expected "India Standard Time"
import { fail, Option, platformLabel, program, readFile, run, runScript, writeFile } from "noda-scripts/ci";
import { app, testArgs } from "./app.ts";

const o = program
  .description("Runs the Flutter app's system time zone checks on the desktop.")
  .addOption(new Option("--device <device>", "the desktop device").choices(["windows", "linux", "macos"]).makeOptionMandatory())
  .addOption(new Option("--source <source>", "set the machine's zone, or TZ").choices(["system", "TZ"]).makeOptionMandatory())
  .requiredOption("--zone <id>", "the zone (system on Windows: a Windows ID; else an IANA ID)")
  .requiredOption("--expected <id>", "the system source's expected zone ID")
  .option("--platform-clock-skip <reason>", "skip the comparison with DateTime's offsets (default: Windows with TZ, which DateTime ignores)")
  .parse().opts<{ device: string; source: string; zone: string; expected: string; platformClockSkip?: string }>();
const skip = o.platformClockSkip ?? (o.device === "windows" && o.source === "TZ" ? "DateTime ignores TZ on Windows" : "");
const label = `${o.device}-${o.source}-${platformLabel().split("-")[1]}`.toLowerCase();

if (o.source === "system") {
  runScript("scripts/time-zones/set-system-time-zone.ts", [o.zone]);
}
const args = ["test", "integration_test", "-d", o.device, "--coverage", "--coverage-package", "noda_dart",
  ...testArgs(o.device, label, o.expected)];
if (skip) args.push(`--dart-define=NODA_PLATFORM_CLOCK_SKIP=${skip}`);
const env = o.source === "TZ" ? { TZ: o.zone } : {};
const status = o.device === "linux"
  ? run("xvfb-run", ["-a", "flutter", ...args], { cwd: app, env, check: false })
  : run("flutter", args, { cwd: app, env, check: false });

// A failure still writes the coverage; the status is checked last.
const lcov = readFile(`${app}/coverage/lcov.info`).replace(/^SF:(.*)$/gm, (_, file: string) =>
  `SF:${file.replace(/^.*[\\/]noda_dart[\\/](?=lib[\\/])/, "").replaceAll("\\", "/")}`);
writeFile(`${app}/coverage-out/flutter-${o.device}-${o.source}.lcov.info`, lcov);
if (status !== 0) fail(`The Flutter system time zone checks failed (${label}).`);
